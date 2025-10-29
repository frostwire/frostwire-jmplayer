/*
 * Copyright (c) 2013-2015 Paul B Mahol
 *
 * This file is part of FFmpeg.
 *
 * FFmpeg is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * FFmpeg is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with FFmpeg; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 */

/**
 * @file
 * fade audio filter
 */

#include "config_components.h"

#include "libavutil/avassert.h"
#include "libavutil/avstring.h"
#include "libavutil/opt.h"
#include "audio.h"
#include "avfilter.h"
#include "filters.h"

typedef struct AudioFadeContext {
    const AVClass *class;
    int nb_inputs;
    int type;
    int curve, curve2;
    int64_t nb_samples;
    int64_t start_sample;
    int64_t duration;
    int64_t start_time;
    double silence;
    double unity;
    int overlap;
    int64_t pts;
    int xfade_idx;

    void (*fade_samples)(uint8_t **dst, uint8_t * const *src,
                         int nb_samples, int channels, int direction,
                         int64_t start, int64_t range, int curve,
                         double silence, double unity);
    void (*scale_samples)(uint8_t **dst, uint8_t * const *src,
                          int nb_samples, int channels, double unity);
    void (*crossfade_samples)(uint8_t **dst, uint8_t * const *cf0,
                              uint8_t * const *cf1,
                              int nb_samples, int channels,
                              int curve0, int curve1);
} AudioFadeContext;

enum CurveType { NONE = -1, TRI, QSIN, ESIN, HSIN, LOG, IPAR, QUA, CUB, SQU, CBR, PAR, EXP, IQSIN, IHSIN, DESE, DESI, LOSI, SINC, ISINC, QUAT, QUATR, QSIN2, HSIN2, NB_CURVES };

#define OFFSET(x) offsetof(AudioFadeContext, x)
#define FLAGS AV_OPT_FLAG_AUDIO_PARAM|AV_OPT_FLAG_FILTERING_PARAM
#define TFLAGS AV_OPT_FLAG_AUDIO_PARAM|AV_OPT_FLAG_FILTERING_PARAM|AV_OPT_FLAG_RUNTIME_PARAM

    static const enum AVSampleFormat sample_fmts[] = {
        AV_SAMPLE_FMT_S16, AV_SAMPLE_FMT_S16P,
        AV_SAMPLE_FMT_S32, AV_SAMPLE_FMT_S32P,
        AV_SAMPLE_FMT_FLT, AV_SAMPLE_FMT_FLTP,
        AV_SAMPLE_FMT_DBL, AV_SAMPLE_FMT_DBLP,
        AV_SAMPLE_FMT_NONE
    };

static double fade_gain(int curve, int64_t index, int64_t range, double silence, double unity)
{
#define CUBE(a) ((a)*(a)*(a))
    double gain;

    gain = av_clipd(1.0 * index / range, 0, 1.0);

    switch (curve) {
    case QSIN:
        gain = sin(gain * M_PI / 2.0);
        break;
    case IQSIN:
        /* 0.6... = 2 / M_PI */
        gain = 0.6366197723675814 * asin(gain);
        break;
    case ESIN:
        gain = 1.0 - cos(M_PI / 4.0 * (CUBE(2.0*gain - 1) + 1));
        break;
    case HSIN:
        gain = (1.0 - cos(gain * M_PI)) / 2.0;
        break;
    case IHSIN:
        /* 0.3... = 1 / M_PI */
        gain = 0.3183098861837907 * acos(1 - 2 * gain);
        break;
    case EXP:
        /* -11.5... = 5*ln(0.1) */
        gain = exp(-11.512925464970227 * (1 - gain));
        break;
    case LOG:
        gain = av_clipd(1 + 0.2 * log10(gain), 0, 1.0);
        break;
    case PAR:
        gain = 1 - sqrt(1 - gain);
        break;
    case IPAR:
        gain = (1 - (1 - gain) * (1 - gain));
        break;
    case QUA:
        gain *= gain;
        break;
    case CUB:
        gain = CUBE(gain);
        break;
    case SQU:
        gain = sqrt(gain);
        break;
    case CBR:
        gain = cbrt(gain);
        break;
    case DESE:
        gain = gain <= 0.5 ? cbrt(2 * gain) / 2: 1 - cbrt(2 * (1 - gain)) / 2;
        break;
    case DESI:
        gain = gain <= 0.5 ? CUBE(2 * gain) / 2: 1 - CUBE(2 * (1 - gain)) / 2;
        break;
    case LOSI: {
                   const double a = 1. / (1. - 0.787) - 1;
                   double A = 1. / (1.0 + exp(0 -((gain-0.5) * a * 2.0)));
                   double B = 1. / (1.0 + exp(a));
                   double C = 1. / (1.0 + exp(0-a));
                   gain = (A - B) / (C - B);
               }
        break;
    case SINC:
        gain = gain >= 1.0 ? 1.0 : sin(M_PI * (1.0 - gain)) / (M_PI * (1.0 - gain));
        break;
    case ISINC:
        gain = gain <= 0.0 ? 0.0 : 1.0 - sin(M_PI * gain) / (M_PI * gain);
        break;
    case QUAT:
        gain = gain * gain * gain * gain;
        break;
    case QUATR:
        gain = pow(gain, 0.25);
        break;
    case QSIN2:
        gain = sin(gain * M_PI / 2.0) * sin(gain * M_PI / 2.0);
        break;
    case HSIN2:
        gain = pow((1.0 - cos(gain * M_PI)) / 2.0, 2.0);
        break;
    case NONE:
        gain = 1.0;
        break;
    }

    return silence + (unity - silence) * gain;
}

#define FADE_PLANAR(name, type)                                             \
static void fade_samples_## name ##p(uint8_t **dst, uint8_t * const *src,   \
                                     int nb_samples, int channels, int dir, \
                                     int64_t start, int64_t range,int curve,\
                                     double silence, double unity)          \
{                                                                           \
    int i, c;                                                               \
                                                                            \
    for (i = 0; i < nb_samples; i++) {                                      \
        double gain = fade_gain(curve, start + i * dir,range,silence,unity);\
        for (c = 0; c < channels; c++) {                                    \
            type *d = (type *)dst[c];                                       \
            const type *s = (type *)src[c];                                 \
                                                                            \
            d[i] = s[i] * gain;                                             \
        }                                                                   \
    }                                                                       \
}

#define FADE(name, type)                                                    \
static void fade_samples_## name (uint8_t **dst, uint8_t * const *src,      \
                                  int nb_samples, int channels, int dir,    \
                                  int64_t start, int64_t range, int curve,  \
                                  double silence, double unity)             \
{                                                                           \
    type *d = (type *)dst[0];                                               \
    const type *s = (type *)src[0];                                         \
    int i, c, k = 0;                                                        \
                                                                            \
    for (i = 0; i < nb_samples; i++) {                                      \
        double gain = fade_gain(curve, start + i * dir,range,silence,unity);\
        for (c = 0; c < channels; c++, k++)                                 \
            d[k] = s[k] * gain;                                             \
    }                                                                       \
}

FADE_PLANAR(dbl, double)
FADE_PLANAR(flt, float)
FADE_PLANAR(s16, int16_t)
FADE_PLANAR(s32, int32_t)

FADE(dbl, double)
FADE(flt, float)
FADE(s16, int16_t)
FADE(s32, int32_t)

#define SCALE_PLANAR(name, type)                                            \
static void scale_samples_## name ##p(uint8_t **dst, uint8_t * const *src,  \
                                     int nb_samples, int channels,          \
                                     double gain)                           \
{                                                                           \
    int i, c;                                                               \
                                                                            \
    for (i = 0; i < nb_samples; i++) {                                      \
        for (c = 0; c < channels; c++) {                                    \
            type *d = (type *)dst[c];                                       \
            const type *s = (type *)src[c];                                 \
                                                                            \
            d[i] = s[i] * gain;                                             \
        }                                                                   \
    }                                                                       \
}

#define SCALE(name, type)                                                   \
static void scale_samples_## name (uint8_t **dst, uint8_t * const *src,     \
                                  int nb_samples, int channels, double gain)\
{                                                                           \
    type *d = (type *)dst[0];                                               \
    const type *s = (type *)src[0];                                         \
    int i, c, k = 0;                                                        \
                                                                            \
    for (i = 0; i < nb_samples; i++) {                                      \
        for (c = 0; c < channels; c++, k++)                                 \
            d[k] = s[k] * gain;                                             \
    }                                                                       \
}

SCALE_PLANAR(dbl, double)
SCALE_PLANAR(flt, float)
SCALE_PLANAR(s16, int16_t)
SCALE_PLANAR(s32, int32_t)

SCALE(dbl, double)
SCALE(flt, float)
SCALE(s16, int16_t)
SCALE(s32, int32_t)

static int config_output(AVFilterLink *outlink)
{
    AVFilterContext *ctx = outlink->src;
    AudioFadeContext *s  = ctx->priv;

    switch (outlink->format) {
    case AV_SAMPLE_FMT_DBL:  s->fade_samples = fade_samples_dbl;
                             s->scale_samples = scale_samples_dbl;
                             break;
    case AV_SAMPLE_FMT_DBLP: s->fade_samples = fade_samples_dblp;
                             s->scale_samples = scale_samples_dblp;
                             break;
    case AV_SAMPLE_FMT_FLT:  s->fade_samples = fade_samples_flt;
                             s->scale_samples = scale_samples_flt;
                             break;
    case AV_SAMPLE_FMT_FLTP: s->fade_samples = fade_samples_fltp;
                             s->scale_samples = scale_samples_fltp;
                             break;
    case AV_SAMPLE_FMT_S16:  s->fade_samples = fade_samples_s16;
                             s->scale_samples = scale_samples_s16;
                             break;
    case AV_SAMPLE_FMT_S16P: s->fade_samples = fade_samples_s16p;
                             s->scale_samples = scale_samples_s16p;
                             break;
    case AV_SAMPLE_FMT_S32:  s->fade_samples = fade_samples_s32;
                             s->scale_samples = scale_samples_s32;
                             break;
    case AV_SAMPLE_FMT_S32P: s->fade_samples = fade_samples_s32p;
                             s->scale_samples = scale_samples_s32p;
                             break;
    }

    if (s->duration)
        s->nb_samples = av_rescale(s->duration, outlink->sample_rate, AV_TIME_BASE);
    s->duration = 0;
    if (s->start_time)
        s->start_sample = av_rescale(s->start_time, outlink->sample_rate, AV_TIME_BASE);
    s->start_time = 0;

    return 0;
}

#if CONFIG_AFADE_FILTER

static const AVOption afade_options[] = {
    { "type",         "set the fade direction",                      OFFSET(type),         AV_OPT_TYPE_INT,    {.i64 = 0    }, 0, 1, TFLAGS, .unit = "type" },
    { "t",            "set the fade direction",                      OFFSET(type),         AV_OPT_TYPE_INT,    {.i64 = 0    }, 0, 1, TFLAGS, .unit = "type" },
    { "in",           "fade-in",                                     0,                    AV_OPT_TYPE_CONST,  {.i64 = 0    }, 0, 0, TFLAGS, .unit = "type" },
    { "out",          "fade-out",                                    0,                    AV_OPT_TYPE_CONST,  {.i64 = 1    }, 0, 0, TFLAGS, .unit = "type" },
    { "start_sample", "set number of first sample to start fading",  OFFSET(start_sample), AV_OPT_TYPE_INT64,  {.i64 = 0    }, 0, INT64_MAX, TFLAGS },
    { "ss",           "set number of first sample to start fading",  OFFSET(start_sample), AV_OPT_TYPE_INT64,  {.i64 = 0    }, 0, INT64_MAX, TFLAGS },
    { "nb_samples",   "set number of samples for fade duration",     OFFSET(nb_samples),   AV_OPT_TYPE_INT64,  {.i64 = 44100}, 1, INT64_MAX, TFLAGS },
    { "ns",           "set number of samples for fade duration",     OFFSET(nb_samples),   AV_OPT_TYPE_INT64,  {.i64 = 44100}, 1, INT64_MAX, TFLAGS },
    { "start_time",   "set time to start fading",                    OFFSET(start_time),   AV_OPT_TYPE_DURATION, {.i64 = 0 },  0, INT64_MAX, TFLAGS },
    { "st",           "set time to start fading",                    OFFSET(start_time),   AV_OPT_TYPE_DURATION, {.i64 = 0 },  0, INT64_MAX, TFLAGS },
    { "duration",     "set fade duration",                           OFFSET(duration),     AV_OPT_TYPE_DURATION, {.i64 = 0 },  0, INT64_MAX, TFLAGS },
    { "d",            "set fade duration",                           OFFSET(duration),     AV_OPT_TYPE_DURATION, {.i64 = 0 },  0, INT64_MAX, TFLAGS },
    { "curve",        "set fade curve type",                         OFFSET(curve),        AV_OPT_TYPE_INT,    {.i64 = TRI  }, NONE, NB_CURVES - 1, TFLAGS, .unit = "curve" },
    { "c",            "set fade curve type",                         OFFSET(curve),        AV_OPT_TYPE_INT,    {.i64 = TRI  }, NONE, NB_CURVES - 1, TFLAGS, .unit = "curve" },
    { "nofade",       "no fade; keep audio as-is",                   0,                    AV_OPT_TYPE_CONST,  {.i64 = NONE }, 0, 0, TFLAGS, .unit = "curve" },
    { "tri",          "linear slope",                                0,                    AV_OPT_TYPE_CONST,  {.i64 = TRI  }, 0, 0, TFLAGS, .unit = "curve" },
    { "qsin",         "quarter of sine wave",                        0,                    AV_OPT_TYPE_CONST,  {.i64 = QSIN }, 0, 0, TFLAGS, .unit = "curve" },
    { "esin",         "exponential sine wave",                       0,                    AV_OPT_TYPE_CONST,  {.i64 = ESIN }, 0, 0, TFLAGS, .unit = "curve" },
    { "hsin",         "half of sine wave",                           0,                    AV_OPT_TYPE_CONST,  {.i64 = HSIN }, 0, 0, TFLAGS, .unit = "curve" },
    { "log",          "logarithmic",                                 0,                    AV_OPT_TYPE_CONST,  {.i64 = LOG  }, 0, 0, TFLAGS, .unit = "curve" },
    { "ipar",         "inverted parabola",                           0,                    AV_OPT_TYPE_CONST,  {.i64 = IPAR }, 0, 0, TFLAGS, .unit = "curve" },
    { "qua",          "quadratic",                                   0,                    AV_OPT_TYPE_CONST,  {.i64 = QUA  }, 0, 0, TFLAGS, .unit = "curve" },
    { "cub",          "cubic",                                       0,                    AV_OPT_TYPE_CONST,  {.i64 = CUB  }, 0, 0, TFLAGS, .unit = "curve" },
    { "squ",          "square root",                                 0,                    AV_OPT_TYPE_CONST,  {.i64 = SQU  }, 0, 0, TFLAGS, .unit = "curve" },
    { "cbr",          "cubic root",                                  0,                    AV_OPT_TYPE_CONST,  {.i64 = CBR  }, 0, 0, TFLAGS, .unit = "curve" },
    { "par",          "parabola",                                    0,                    AV_OPT_TYPE_CONST,  {.i64 = PAR  }, 0, 0, TFLAGS, .unit = "curve" },
    { "exp",          "exponential",                                 0,                    AV_OPT_TYPE_CONST,  {.i64 = EXP  }, 0, 0, TFLAGS, .unit = "curve" },
    { "iqsin",        "inverted quarter of sine wave",               0,                    AV_OPT_TYPE_CONST,  {.i64 = IQSIN}, 0, 0, TFLAGS, .unit = "curve" },
    { "ihsin",        "inverted half of sine wave",                  0,                    AV_OPT_TYPE_CONST,  {.i64 = IHSIN}, 0, 0, TFLAGS, .unit = "curve" },
    { "dese",         "double-exponential seat",                     0,                    AV_OPT_TYPE_CONST,  {.i64 = DESE }, 0, 0, TFLAGS, .unit = "curve" },
    { "desi",         "double-exponential sigmoid",                  0,                    AV_OPT_TYPE_CONST,  {.i64 = DESI }, 0, 0, TFLAGS, .unit = "curve" },
    { "losi",         "logistic sigmoid",                            0,                    AV_OPT_TYPE_CONST,  {.i64 = LOSI }, 0, 0, TFLAGS, .unit = "curve" },
    { "sinc",         "sine cardinal function",                      0,                    AV_OPT_TYPE_CONST,  {.i64 = SINC }, 0, 0, TFLAGS, .unit = "curve" },
    { "isinc",        "inverted sine cardinal function",             0,                    AV_OPT_TYPE_CONST,  {.i64 = ISINC}, 0, 0, TFLAGS, .unit = "curve" },
    { "quat",         "quartic",                                     0,                    AV_OPT_TYPE_CONST,  {.i64 = QUAT }, 0, 0, TFLAGS, .unit = "curve" },
    { "quatr",        "quartic root",                                0,                    AV_OPT_TYPE_CONST,  {.i64 = QUATR}, 0, 0, TFLAGS, .unit = "curve" },
    { "qsin2",        "squared quarter of sine wave",                0,                    AV_OPT_TYPE_CONST,  {.i64 = QSIN2}, 0, 0, TFLAGS, .unit = "curve" },
    { "hsin2",        "squared half of sine wave",                   0,                    AV_OPT_TYPE_CONST,  {.i64 = HSIN2}, 0, 0, TFLAGS, .unit = "curve" },
    { "silence",      "set the silence gain",                        OFFSET(silence),      AV_OPT_TYPE_DOUBLE, {.dbl = 0 },    0, 1, TFLAGS },
    { "unity",        "set the unity gain",                          OFFSET(unity),        AV_OPT_TYPE_DOUBLE, {.dbl = 1 },    0, 1, TFLAGS },
    { NULL }
};

AVFILTER_DEFINE_CLASS(afade);

static av_cold int init(AVFilterContext *ctx)
{
    AudioFadeContext *s = ctx->priv;

    if (INT64_MAX - s->nb_samples < s->start_sample)
        return AVERROR(EINVAL);

    return 0;
}

static int filter_frame(AVFilterLink *inlink, AVFrame *buf)
{
    AudioFadeContext *s     = inlink->dst->priv;
    AVFilterLink *outlink   = inlink->dst->outputs[0];
    int nb_samples          = buf->nb_samples;
    AVFrame *out_buf;
    int64_t cur_sample = av_rescale_q(buf->pts, inlink->time_base, (AVRational){1, inlink->sample_rate});

    if (s->unity == 1.0 &&
        ((!s->type && (s->start_sample + s->nb_samples < cur_sample)) ||
         ( s->type && (cur_sample + nb_samples < s->start_sample))))
        return ff_filter_frame(outlink, buf);

    if (av_frame_is_writable(buf)) {
        out_buf = buf;
    } else {
        out_buf = ff_get_audio_buffer(outlink, nb_samples);
        if (!out_buf)
            return AVERROR(ENOMEM);
        av_frame_copy_props(out_buf, buf);
    }

    if ((!s->type && (cur_sample + nb_samples < s->start_sample)) ||
        ( s->type && (s->start_sample + s->nb_samples < cur_sample))) {
        if (s->silence == 0.) {
            av_samples_set_silence(out_buf->extended_data, 0, nb_samples,
                                   out_buf->ch_layout.nb_channels, out_buf->format);
        } else {
            s->scale_samples(out_buf->extended_data, buf->extended_data,
                             nb_samples, buf->ch_layout.nb_channels,
                             s->silence);
        }
    } else if (( s->type && (cur_sample + nb_samples < s->start_sample)) ||
               (!s->type && (s->start_sample + s->nb_samples < cur_sample))) {
        s->scale_samples(out_buf->extended_data, buf->extended_data,
                         nb_samples, buf->ch_layout.nb_channels,
                         s->unity);
    } else {
        int64_t start;

        if (!s->type)
            start = cur_sample - s->start_sample;
        else
            start = s->start_sample + s->nb_samples - cur_sample;

        s->fade_samples(out_buf->extended_data, buf->extended_data,
                        nb_samples, buf->ch_layout.nb_channels,
                        s->type ? -1 : 1, start,
                        s->nb_samples, s->curve, s->silence, s->unity);
    }

    if (buf != out_buf)
        av_frame_free(&buf);

    return ff_filter_frame(outlink, out_buf);
}

static int process_command(AVFilterContext *ctx, const char *cmd, const char *args,
                           char *res, int res_len, int flags)
{
    int ret;

    ret = ff_filter_process_command(ctx, cmd, args, res, res_len, flags);
    if (ret < 0)
        return ret;

    return config_output(ctx->outputs[0]);
}

static const AVFilterPad avfilter_af_afade_inputs[] = {
    {
        .name         = "default",
        .type         = AVMEDIA_TYPE_AUDIO,
        .filter_frame = filter_frame,
    },
};

static const AVFilterPad avfilter_af_afade_outputs[] = {
    {
        .name         = "default",
        .type         = AVMEDIA_TYPE_AUDIO,
        .config_props = config_output,
    },
};

const FFFilter ff_af_afade = {
    .p.name        = "afade",
    .p.description = NULL_IF_CONFIG_SMALL("Fade in/out input audio."),
    .p.priv_class  = &afade_class,
    .p.flags       = AVFILTER_FLAG_SUPPORT_TIMELINE_GENERIC,
    .priv_size     = sizeof(AudioFadeContext),
    .init          = init,
    FILTER_INPUTS(avfilter_af_afade_inputs),
    FILTER_OUTPUTS(avfilter_af_afade_outputs),
    FILTER_SAMPLEFMTS_ARRAY(sample_fmts),
    .process_command = process_command,
};

#endif /* CONFIG_AFADE_FILTER */

#if CONFIG_ACROSSFADE_FILTER

static const AVOption acrossfade_options[] = {
    { "inputs",       "set number of input files to cross fade",       OFFSET(nb_inputs),    AV_OPT_TYPE_INT,    {.i64 = 2},     1, INT32_MAX, FLAGS },
    { "n",            "set number of input files to cross fade",       OFFSET(nb_inputs),    AV_OPT_TYPE_INT,    {.i64 = 2},     1, INT32_MAX, FLAGS },
    { "nb_samples",   "set number of samples for cross fade duration", OFFSET(nb_samples),   AV_OPT_TYPE_INT64,  {.i64 = 44100}, 1, INT32_MAX/10, FLAGS },
    { "ns",           "set number of samples for cross fade duration", OFFSET(nb_samples),   AV_OPT_TYPE_INT64,  {.i64 = 44100}, 1, INT32_MAX/10, FLAGS },
    { "duration",     "set cross fade duration",                       OFFSET(duration),     AV_OPT_TYPE_DURATION, {.i64 = 0 },  0, 60000000, FLAGS },
    { "d",            "set cross fade duration",                       OFFSET(duration),     AV_OPT_TYPE_DURATION, {.i64 = 0 },  0, 60000000, FLAGS },
    { "overlap",      "overlap 1st stream end with 2nd stream start",  OFFSET(overlap),      AV_OPT_TYPE_BOOL,   {.i64 = 1    }, 0,  1, FLAGS },
    { "o",            "overlap 1st stream end with 2nd stream start",  OFFSET(overlap),      AV_OPT_TYPE_BOOL,   {.i64 = 1    }, 0,  1, FLAGS },
    { "curve1",       "set fade curve type for 1st stream",            OFFSET(curve),        AV_OPT_TYPE_INT,    {.i64 = TRI  }, NONE, NB_CURVES - 1, FLAGS, .unit = "curve" },
    { "c1",           "set fade curve type for 1st stream",            OFFSET(curve),        AV_OPT_TYPE_INT,    {.i64 = TRI  }, NONE, NB_CURVES - 1, FLAGS, .unit = "curve" },
    {     "nofade",   "no fade; keep audio as-is",                     0,                    AV_OPT_TYPE_CONST,  {.i64 = NONE }, 0, 0, FLAGS, .unit = "curve" },
    {     "tri",      "linear slope",                                  0,                    AV_OPT_TYPE_CONST,  {.i64 = TRI  }, 0, 0, FLAGS, .unit = "curve" },
    {     "qsin",     "quarter of sine wave",                          0,                    AV_OPT_TYPE_CONST,  {.i64 = QSIN }, 0, 0, FLAGS, .unit = "curve" },
    {     "esin",     "exponential sine wave",                         0,                    AV_OPT_TYPE_CONST,  {.i64 = ESIN }, 0, 0, FLAGS, .unit = "curve" },
    {     "hsin",     "half of sine wave",                             0,                    AV_OPT_TYPE_CONST,  {.i64 = HSIN }, 0, 0, FLAGS, .unit = "curve" },
    {     "log",      "logarithmic",                                   0,                    AV_OPT_TYPE_CONST,  {.i64 = LOG  }, 0, 0, FLAGS, .unit = "curve" },
    {     "ipar",     "inverted parabola",                             0,                    AV_OPT_TYPE_CONST,  {.i64 = IPAR }, 0, 0, FLAGS, .unit = "curve" },
    {     "qua",      "quadratic",                                     0,                    AV_OPT_TYPE_CONST,  {.i64 = QUA  }, 0, 0, FLAGS, .unit = "curve" },
    {     "cub",      "cubic",                                         0,                    AV_OPT_TYPE_CONST,  {.i64 = CUB  }, 0, 0, FLAGS, .unit = "curve" },
    {     "squ",      "square root",                                   0,                    AV_OPT_TYPE_CONST,  {.i64 = SQU  }, 0, 0, FLAGS, .unit = "curve" },
    {     "cbr",      "cubic root",                                    0,                    AV_OPT_TYPE_CONST,  {.i64 = CBR  }, 0, 0, FLAGS, .unit = "curve" },
    {     "par",      "parabola",                                      0,                    AV_OPT_TYPE_CONST,  {.i64 = PAR  }, 0, 0, FLAGS, .unit = "curve" },
    {     "exp",      "exponential",                                   0,                    AV_OPT_TYPE_CONST,  {.i64 = EXP  }, 0, 0, FLAGS, .unit = "curve" },
    {     "iqsin",    "inverted quarter of sine wave",                 0,                    AV_OPT_TYPE_CONST,  {.i64 = IQSIN}, 0, 0, FLAGS, .unit = "curve" },
    {     "ihsin",    "inverted half of sine wave",                    0,                    AV_OPT_TYPE_CONST,  {.i64 = IHSIN}, 0, 0, FLAGS, .unit = "curve" },
    {     "dese",     "double-exponential seat",                       0,                    AV_OPT_TYPE_CONST,  {.i64 = DESE }, 0, 0, FLAGS, .unit = "curve" },
    {     "desi",     "double-exponential sigmoid",                    0,                    AV_OPT_TYPE_CONST,  {.i64 = DESI }, 0, 0, FLAGS, .unit = "curve" },
    {     "losi",     "logistic sigmoid",                              0,                    AV_OPT_TYPE_CONST,  {.i64 = LOSI }, 0, 0, FLAGS, .unit = "curve" },
    {     "sinc",     "sine cardinal function",                        0,                    AV_OPT_TYPE_CONST,  {.i64 = SINC }, 0, 0, FLAGS, .unit = "curve" },
    {     "isinc",    "inverted sine cardinal function",               0,                    AV_OPT_TYPE_CONST,  {.i64 = ISINC}, 0, 0, FLAGS, .unit = "curve" },
    {     "quat",     "quartic",                                       0,                    AV_OPT_TYPE_CONST,  {.i64 = QUAT }, 0, 0, FLAGS, .unit = "curve" },
    {     "quatr",    "quartic root",                                  0,                    AV_OPT_TYPE_CONST,  {.i64 = QUATR}, 0, 0, FLAGS, .unit = "curve" },
    {     "qsin2",    "squared quarter of sine wave",                  0,                    AV_OPT_TYPE_CONST,  {.i64 = QSIN2}, 0, 0, FLAGS, .unit = "curve" },
    {     "hsin2",    "squared half of sine wave",                     0,                    AV_OPT_TYPE_CONST,  {.i64 = HSIN2}, 0, 0, FLAGS, .unit = "curve" },
    { "curve2",       "set fade curve type for 2nd stream",            OFFSET(curve2),       AV_OPT_TYPE_INT,    {.i64 = TRI  }, NONE, NB_CURVES - 1, FLAGS, .unit = "curve" },
    { "c2",           "set fade curve type for 2nd stream",            OFFSET(curve2),       AV_OPT_TYPE_INT,    {.i64 = TRI  }, NONE, NB_CURVES - 1, FLAGS, .unit = "curve" },
    { NULL }
};

AVFILTER_DEFINE_CLASS(acrossfade);

#define CROSSFADE_PLANAR(name, type)                                           \
static void crossfade_samples_## name ##p(uint8_t **dst, uint8_t * const *cf0, \
                                          uint8_t * const *cf1,                \
                                          int nb_samples, int channels,        \
                                          int curve0, int curve1)              \
{                                                                              \
    int i, c;                                                                  \
                                                                               \
    for (i = 0; i < nb_samples; i++) {                                         \
        double gain0 = fade_gain(curve0, nb_samples - 1 - i, nb_samples,0.,1.);\
        double gain1 = fade_gain(curve1, i, nb_samples, 0., 1.);               \
        for (c = 0; c < channels; c++) {                                       \
            type *d = (type *)dst[c];                                          \
            const type *s0 = (type *)cf0[c];                                   \
            const type *s1 = (type *)cf1[c];                                   \
                                                                               \
            d[i] = s0[i] * gain0 + s1[i] * gain1;                              \
        }                                                                      \
    }                                                                          \
}

#define CROSSFADE(name, type)                                               \
static void crossfade_samples_## name (uint8_t **dst, uint8_t * const *cf0, \
                                       uint8_t * const *cf1,                \
                                       int nb_samples, int channels,        \
                                       int curve0, int curve1)              \
{                                                                           \
    type *d = (type *)dst[0];                                               \
    const type *s0 = (type *)cf0[0];                                        \
    const type *s1 = (type *)cf1[0];                                        \
    int i, c, k = 0;                                                        \
                                                                            \
    for (i = 0; i < nb_samples; i++) {                                      \
        double gain0 = fade_gain(curve0, nb_samples - 1-i,nb_samples,0.,1.);\
        double gain1 = fade_gain(curve1, i, nb_samples, 0., 1.);            \
        for (c = 0; c < channels; c++, k++)                                 \
            d[k] = s0[k] * gain0 + s1[k] * gain1;                           \
    }                                                                       \
}

CROSSFADE_PLANAR(dbl, double)
CROSSFADE_PLANAR(flt, float)
CROSSFADE_PLANAR(s16, int16_t)
CROSSFADE_PLANAR(s32, int32_t)

CROSSFADE(dbl, double)
CROSSFADE(flt, float)
CROSSFADE(s16, int16_t)
CROSSFADE(s32, int32_t)

static int pass_frame(AVFilterLink *inlink, AVFilterLink *outlink, int64_t *pts)
{
    AVFrame *in;
    int ret = ff_inlink_consume_frame(inlink, &in);
    if (ret < 0)
        return ret;
    av_assert1(ret);
    in->pts = *pts;
    *pts += av_rescale_q(in->nb_samples,
            (AVRational){ 1, outlink->sample_rate }, outlink->time_base);
    return ff_filter_frame(outlink, in);
}

static int pass_samples(AVFilterLink *inlink, AVFilterLink *outlink, unsigned nb_samples, int64_t *pts)
{
    AVFrame *in;
    int ret = ff_inlink_consume_samples(inlink, nb_samples, nb_samples, &in);
    if (ret < 0)
        return ret;
    av_assert1(ret);
    in->pts = *pts;
    *pts += av_rescale_q(in->nb_samples,
            (AVRational){ 1, outlink->sample_rate }, outlink->time_base);
    return ff_filter_frame(outlink, in);
}

static int pass_crossfade(AVFilterContext *ctx, const int idx0, const int idx1)
{
    AudioFadeContext *s = ctx->priv;
    AVFilterLink *outlink = ctx->outputs[0];
    AVFrame *out, *cf[2] = { NULL };
    int ret;

    AVFilterLink *in0 = ctx->inputs[idx0];
    AVFilterLink *in1 = ctx->inputs[idx1];
    int queued_samples0 = ff_inlink_queued_samples(in0);
    int queued_samples1 = ff_inlink_queued_samples(in1);

    /* Limit to the relevant region */
    av_assert1(queued_samples0 <= s->nb_samples);
    if (ff_outlink_get_status(in1) && idx1 < s->nb_inputs - 1)
        queued_samples1 /= 2; /* reserve second half for next fade-out */
    queued_samples1 = FFMIN(queued_samples1, s->nb_samples);

    if (s->overlap) {
        int nb_samples = FFMIN(queued_samples0, queued_samples1);
        if (nb_samples < s->nb_samples) {
            av_log(ctx, AV_LOG_WARNING, "Input %d duration (%d samples) "
                   "is shorter than crossfade duration (%"PRId64" samples), "
                   "crossfade will be shorter by %"PRId64" samples.\n",
                   queued_samples0 <= queued_samples1 ? idx0 : idx1,
                   nb_samples, s->nb_samples, s->nb_samples - nb_samples);

            if (queued_samples0 > nb_samples) {
                ret = pass_samples(in0, outlink, queued_samples0 - nb_samples, &s->pts);
                if (ret < 0)
                    return ret;
            }

            if (!nb_samples)
                return 0; /* either input was completely empty */
        }

        av_assert1(nb_samples > 0);
        out = ff_get_audio_buffer(outlink, nb_samples);
        if (!out)
            return AVERROR(ENOMEM);

        ret = ff_inlink_consume_samples(in0, nb_samples, nb_samples, &cf[0]);
        if (ret < 0) {
            av_frame_free(&out);
            return ret;
        }

        ret = ff_inlink_consume_samples(in1, nb_samples, nb_samples, &cf[1]);
        if (ret < 0) {
            av_frame_free(&cf[0]);
            av_frame_free(&out);
            return ret;
        }

        s->crossfade_samples(out->extended_data, cf[0]->extended_data,
                             cf[1]->extended_data, nb_samples,
                             out->ch_layout.nb_channels, s->curve, s->curve2);
        out->pts = s->pts;
        s->pts += av_rescale_q(nb_samples,
            (AVRational){ 1, outlink->sample_rate }, outlink->time_base);
        av_frame_free(&cf[0]);
        av_frame_free(&cf[1]);
        return ff_filter_frame(outlink, out);
    } else {
        if (queued_samples0 < s->nb_samples) {
            av_log(ctx, AV_LOG_WARNING, "Input %d duration (%d samples) "
                   "is shorter than crossfade duration (%"PRId64" samples), "
                   "fade-out will be shorter by %"PRId64" samples.\n",
                    idx0, queued_samples0, s->nb_samples,
                    s->nb_samples - queued_samples0);
            if (!queued_samples0)
                goto fade_in;
        }

        out = ff_get_audio_buffer(outlink, queued_samples0);
        if (!out)
            return AVERROR(ENOMEM);

        ret = ff_inlink_consume_samples(in0, queued_samples0, queued_samples0, &cf[0]);
        if (ret < 0) {
            av_frame_free(&out);
            return ret;
        }

        s->fade_samples(out->extended_data, cf[0]->extended_data, cf[0]->nb_samples,
                        outlink->ch_layout.nb_channels, -1, cf[0]->nb_samples - 1, cf[0]->nb_samples, s->curve, 0., 1.);
        out->pts = s->pts;
        s->pts += av_rescale_q(cf[0]->nb_samples,
            (AVRational){ 1, outlink->sample_rate }, outlink->time_base);
        av_frame_free(&cf[0]);
        ret = ff_filter_frame(outlink, out);
        if (ret < 0)
            return ret;

    fade_in:
        if (queued_samples1 < s->nb_samples) {
            av_log(ctx, AV_LOG_WARNING, "Input %d duration (%d samples) "
                   "is shorter than crossfade duration (%"PRId64" samples), "
                   "fade-in will be shorter by %"PRId64" samples.\n",
                    idx1, ff_inlink_queued_samples(in1), s->nb_samples,
                    s->nb_samples - queued_samples1);
            if (!queued_samples1)
                return 0;
        }

        out = ff_get_audio_buffer(outlink, queued_samples1);
        if (!out)
            return AVERROR(ENOMEM);

        ret = ff_inlink_consume_samples(in1, queued_samples1, queued_samples1, &cf[1]);
        if (ret < 0) {
            av_frame_free(&out);
            return ret;
        }

        s->fade_samples(out->extended_data, cf[1]->extended_data, cf[1]->nb_samples,
                        outlink->ch_layout.nb_channels, 1, 0, cf[1]->nb_samples, s->curve2, 0., 1.);
        out->pts = s->pts;
        s->pts += av_rescale_q(cf[1]->nb_samples,
            (AVRational){ 1, outlink->sample_rate }, outlink->time_base);
        av_frame_free(&cf[1]);
        return ff_filter_frame(outlink, out);
    }
}

static int activate(AVFilterContext *ctx)
{
    AudioFadeContext *s   = ctx->priv;
    const int idx0        = s->xfade_idx;
    const int idx1        = s->xfade_idx + 1;
    AVFilterLink *outlink = ctx->outputs[0];
    AVFilterLink *in0     = ctx->inputs[idx0];

    FF_FILTER_FORWARD_STATUS_BACK_ALL(outlink, ctx);

    if (idx0 == s->nb_inputs - 1) {
        /* Last active input, read until EOF */
        if (ff_inlink_queued_frames(in0))
            return pass_frame(in0, outlink, &s->pts);
        FF_FILTER_FORWARD_STATUS(in0, outlink);
        FF_FILTER_FORWARD_WANTED(outlink, in0);
        return FFERROR_NOT_READY;
    }

    AVFilterLink *in1 = ctx->inputs[idx1];
    int queued_samples0 = ff_inlink_queued_samples(in0);
    if (queued_samples0 > s->nb_samples) {
        AVFrame *frame = ff_inlink_peek_frame(in0, 0);
        if (queued_samples0 - s->nb_samples >= frame->nb_samples)
            return pass_frame(in0, outlink, &s->pts);
    }

    /* Continue reading until EOF */
    if (ff_outlink_get_status(in0)) {
        if (queued_samples0 > s->nb_samples)
            return pass_samples(in0, outlink, queued_samples0 - s->nb_samples, &s->pts);
    } else {
        FF_FILTER_FORWARD_WANTED(outlink, in0);
        return FFERROR_NOT_READY;
    }

    /* At this point, in0 has reached EOF with no more samples remaining
     * except those that we want to crossfade */
    av_assert0(queued_samples0 <= s->nb_samples);
    int queued_samples1 = ff_inlink_queued_samples(in1);

    /* If this clip is sandwiched between two other clips, buffer at least
     * twice the total crossfade duration to ensure that we won't reach EOF
     * during the second fade (in which case we would shorten the fade) */
    int needed_samples = s->nb_samples;
    if (idx1 < s->nb_inputs - 1)
        needed_samples *= 2;

    if (queued_samples1 >= needed_samples || ff_outlink_get_status(in1)) {
        /* The first filter may EOF before delivering any samples, in which
         * case it's possible for pass_crossfade() to be a no-op. Just ensure
         * the activate() function runs again after incrementing the index to
         * ensure we correctly move on to the next input in that case. */
        s->xfade_idx++;
        ff_filter_set_ready(ctx, 10);
        return pass_crossfade(ctx, idx0, idx1);
    } else {
        FF_FILTER_FORWARD_WANTED(outlink, in1);
        return FFERROR_NOT_READY;
    }
}

static av_cold int acrossfade_init(AVFilterContext *ctx)
{
    AudioFadeContext *s = ctx->priv;
    int ret;

    for (int i = 0; i < s->nb_inputs; i++) {
        AVFilterPad pad = {
            .name = av_asprintf("crossfade%d", i),
            .type = AVMEDIA_TYPE_AUDIO,
        };
        if (!pad.name)
            return AVERROR(ENOMEM);

        ret = ff_append_inpad_free_name(ctx, &pad);
        if (ret < 0)
            return ret;
    }

    return 0;
}

static int acrossfade_config_output(AVFilterLink *outlink)
{
    AVFilterContext *ctx = outlink->src;
    AudioFadeContext *s  = ctx->priv;

    outlink->time_base   = ctx->inputs[0]->time_base;

    switch (outlink->format) {
    case AV_SAMPLE_FMT_DBL:  s->crossfade_samples = crossfade_samples_dbl;  break;
    case AV_SAMPLE_FMT_DBLP: s->crossfade_samples = crossfade_samples_dblp; break;
    case AV_SAMPLE_FMT_FLT:  s->crossfade_samples = crossfade_samples_flt;  break;
    case AV_SAMPLE_FMT_FLTP: s->crossfade_samples = crossfade_samples_fltp; break;
    case AV_SAMPLE_FMT_S16:  s->crossfade_samples = crossfade_samples_s16;  break;
    case AV_SAMPLE_FMT_S16P: s->crossfade_samples = crossfade_samples_s16p; break;
    case AV_SAMPLE_FMT_S32:  s->crossfade_samples = crossfade_samples_s32;  break;
    case AV_SAMPLE_FMT_S32P: s->crossfade_samples = crossfade_samples_s32p; break;
    }

    config_output(outlink);

    return 0;
}

static const AVFilterPad avfilter_af_acrossfade_outputs[] = {
    {
        .name          = "default",
        .type          = AVMEDIA_TYPE_AUDIO,
        .config_props  = acrossfade_config_output,
    },
};

const FFFilter ff_af_acrossfade = {
    .p.name        = "acrossfade",
    .p.description = NULL_IF_CONFIG_SMALL("Cross fade two input audio streams."),
    .p.priv_class  = &acrossfade_class,
    .p.flags       = AVFILTER_FLAG_DYNAMIC_INPUTS,
    .priv_size     = sizeof(AudioFadeContext),
    .init          = acrossfade_init,
    .activate      = activate,
    FILTER_OUTPUTS(avfilter_af_acrossfade_outputs),
    FILTER_SAMPLEFMTS_ARRAY(sample_fmts),
};

#endif /* CONFIG_ACROSSFADE_FILTER */
