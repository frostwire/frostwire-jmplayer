/*
 * TLS/DTLS/SSL Protocol
 * Copyright (c) 2011 Martin Storsjo
 * Copyright (c) 2025 Jack Lau
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

#include "avformat.h"
#include "internal.h"
#include "network.h"
#include "os_support.h"
#include "url.h"
#include "tls.h"
#include "libavutil/avstring.h"
#include "libavutil/getenv_utf8.h"
#include "libavutil/mem.h"
#include "libavutil/parseutils.h"

int ff_tls_open_underlying(TLSShared *c, URLContext *parent, const char *uri, AVDictionary **options)
{
    int port;
    const char *p;
    char buf[200], opts[50] = "";
    struct addrinfo hints = { 0 }, *ai = NULL;
    const char *proxy_path;
    char *env_http_proxy, *env_no_proxy;
    int use_proxy;
    int ret;

    p = strchr(uri, '?');
    if (p) {
        ret = ff_parse_opts_from_query_string(c, p, 1);
        if (ret < 0)
            return ret;
    }

    if (c->listen && !c->is_dtls)
        snprintf(opts, sizeof(opts), "?listen=1");

    av_url_split(NULL, 0, NULL, 0, c->underlying_host, sizeof(c->underlying_host), &port, NULL, 0, uri);

    if (!p) {
        p = opts;
    } else {
        if (av_find_info_tag(opts, sizeof(opts), "listen", p))
            c->listen = 1;
    }

    ff_url_join(buf, sizeof(buf), c->is_dtls ? "udp" : "tcp", NULL, (c->is_dtls && c->listen) ? "" : c->underlying_host, port, "%s", p);

    hints.ai_flags = AI_NUMERICHOST;
    if (!getaddrinfo(c->underlying_host, NULL, &hints, &ai)) {
        c->numerichost = 1;
        freeaddrinfo(ai);
    }

    if (!c->host && !(c->host = av_strdup(c->underlying_host)))
        return AVERROR(ENOMEM);

    env_http_proxy = getenv_utf8("http_proxy");
    proxy_path = c->http_proxy ? c->http_proxy : env_http_proxy;

    env_no_proxy = getenv_utf8("no_proxy");
    use_proxy = !ff_http_match_no_proxy(env_no_proxy, c->underlying_host) &&
                proxy_path && av_strstart(proxy_path, "http://", NULL);
    freeenv_utf8(env_no_proxy);

    if (!c->is_dtls && use_proxy) {
        char proxy_host[200], proxy_auth[200], dest[200];
        int proxy_port;
        av_url_split(NULL, 0, proxy_auth, sizeof(proxy_auth),
                     proxy_host, sizeof(proxy_host), &proxy_port, NULL, 0,
                     proxy_path);
        ff_url_join(dest, sizeof(dest), NULL, NULL, c->underlying_host, port, NULL);
        ff_url_join(buf, sizeof(buf), "httpproxy", proxy_auth, proxy_host,
                    proxy_port, "/%s", dest);
    }

    freeenv_utf8(env_http_proxy);
    if (c->is_dtls) {
        if (c->listen) {
            av_dict_set_int(options, "localport", port, 0);
            av_dict_set(options, "localaddr", c->underlying_host, 0);
        } else {
            av_dict_set_int(options, "localport", 0, 0);
            av_dict_set_int(options, "connect", 1, 0);
        }
        av_dict_set_int(options, "fifo_size", 0, 0);
        /* Set the max packet size to the buffer size. */
        av_dict_set_int(options, "pkt_size", c->mtu, 0);
    }
    ret = ffurl_open_whitelist(c->is_dtls ? &c->udp : &c->tcp, buf, AVIO_FLAG_READ_WRITE,
                               &parent->interrupt_callback, options,
                               parent->protocol_whitelist, parent->protocol_blacklist, parent);
    return ret;
}

/**
 * Read all data from the given URL url and store it in the given buffer bp.
 */
int ff_url_read_all(const char *url, AVBPrint *bp)
{
    int ret = 0;
    AVDictionary *opts = NULL;
    URLContext *uc = NULL;
    char buf[MAX_URL_SIZE];

    ret = ffurl_open_whitelist(&uc, url, AVIO_FLAG_READ, NULL, &opts, NULL, NULL, NULL);
    if (ret < 0) {
        av_log(NULL, AV_LOG_ERROR, "TLS: Failed to open url %s\n", url);
        goto end;
    }

    while (1) {
        ret = ffurl_read(uc, buf, sizeof(buf));
        if (ret == AVERROR_EOF) {
            /* Reset the error because we read all response as answer util EOF. */
            ret = 0;
            break;
        }
        if (ret <= 0) {
            av_log(NULL, AV_LOG_ERROR, "TLS: Failed to read from url=%s, key is %s\n", url, bp->str);
            goto end;
        }

        av_bprintf(bp, "%.*s", ret, buf);
        if (!av_bprint_is_complete(bp)) {
            av_log(NULL, AV_LOG_ERROR, "TLS: Exceed max size %.*s, %s\n", ret, buf, bp->str);
            ret = AVERROR(EIO);
            goto end;
        }
    }

end:
    ffurl_closep(&uc);
    av_dict_free(&opts);
    return ret;
}
