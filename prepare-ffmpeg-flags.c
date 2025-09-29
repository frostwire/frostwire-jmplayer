#include <ctype.h>
#include <errno.h>
#include <stdbool.h>
#include <stdarg.h>
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/wait.h>

typedef struct {
    char *data;
    size_t length;
    size_t capacity;
} StringBuffer;

static void fatal(const char *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    vfprintf(stderr, fmt, args);
    va_end(args);
    fputc('\n', stderr);
    exit(EXIT_FAILURE);
}

static void sb_init(StringBuffer *sb) {
    sb->capacity = 128;
    sb->length = 0;
    sb->data = (char *)malloc(sb->capacity);
    if (!sb->data) {
        fatal("Out of memory");
    }
    sb->data[0] = '\0';
}

static void sb_ensure_capacity(StringBuffer *sb, size_t additional) {
    size_t required = sb->length + additional + 1;
    if (required <= sb->capacity) {
        return;
    }
    while (sb->capacity < required) {
        sb->capacity *= 2;
    }
    char *new_data = (char *)realloc(sb->data, sb->capacity);
    if (!new_data) {
        fatal("Out of memory");
    }
    sb->data = new_data;
}

static void sb_append_len(StringBuffer *sb, const char *str, size_t len) {
    sb_ensure_capacity(sb, len);
    memcpy(sb->data + sb->length, str, len);
    sb->length += len;
    sb->data[sb->length] = '\0';
}

static void sb_append(StringBuffer *sb, const char *str) {
    sb_append_len(sb, str, strlen(str));
}

static void sb_append_format(StringBuffer *sb, const char *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    va_list args_copy;
    va_copy(args_copy, args);
    int needed = vsnprintf(NULL, 0, fmt, args_copy);
    va_end(args_copy);
    if (needed < 0) {
        va_end(args);
        fatal("Failed to format string");
    }
    sb_ensure_capacity(sb, (size_t)needed);
    vsnprintf(sb->data + sb->length, sb->capacity - sb->length, fmt, args);
    sb->length += (size_t)needed;
    sb->data[sb->length] = '\0';
    va_end(args);
}

static char *sb_release(StringBuffer *sb) {
    char *data = sb->data;
    sb->data = NULL;
    sb->length = 0;
    sb->capacity = 0;
    return data;
}

static void sb_trim_trailing_whitespace(StringBuffer *sb) {
    while (sb->length > 0 && isspace((unsigned char)sb->data[sb->length - 1])) {
        sb->length--;
    }
    sb->data[sb->length] = '\0';
}

static void ensure_directory_exists(const char *path) {
    struct stat st;
    if (stat(path, &st) != 0) {
        fatal("Required directory '%s' is not available: %s", path, strerror(errno));
    }
    if (!S_ISDIR(st.st_mode)) {
        fatal("Required path '%s' is not a directory", path);
    }
}

static char *read_file(const char *path) {
    FILE *file = fopen(path, "rb");
    if (!file) {
        fatal("Failed to open '%s': %s", path, strerror(errno));
    }

    if (fseek(file, 0, SEEK_END) != 0) {
        fclose(file);
        fatal("Failed to seek '%s': %s", path, strerror(errno));
    }
    long size = ftell(file);
    if (size < 0) {
        fclose(file);
        fatal("Failed to determine size of '%s': %s", path, strerror(errno));
    }
    if (fseek(file, 0, SEEK_SET) != 0) {
        fclose(file);
        fatal("Failed to rewind '%s': %s", path, strerror(errno));
    }

    char *buffer = (char *)malloc((size_t)size + 1);
    if (!buffer) {
        fclose(file);
        fatal("Out of memory");
    }

    size_t read = fread(buffer, 1, (size_t)size, file);
    if (read != (size_t)size) {
        free(buffer);
        fclose(file);
        fatal("Failed to read '%s'", path);
    }
    buffer[read] = '\0';

    fclose(file);
    return buffer;
}

static char *run_command_capture(const char *command) {
    FILE *pipe = popen(command, "r");
    if (!pipe) {
        fatal("Failed to run command '%s': %s", command, strerror(errno));
    }

    StringBuffer sb;
    sb_init(&sb);

    char chunk[4096];
    size_t read_bytes;
    while ((read_bytes = fread(chunk, 1, sizeof(chunk), pipe)) > 0) {
        sb_append_len(&sb, chunk, read_bytes);
    }

    if (ferror(pipe)) {
        int saved_errno = errno;
        pclose(pipe);
        fatal("Error reading output of '%s': %s", command, strerror(saved_errno));
    }

    int status = pclose(pipe);
    if (status == -1) {
        fatal("Failed to close command '%s': %s", command, strerror(errno));
    }
    if (WIFEXITED(status)) {
        if (WEXITSTATUS(status) != 0) {
            fatal("Command '%s' exited with status %d", command, WEXITSTATUS(status));
        }
    } else {
        fatal("Command '%s' did not terminate normally", command);
    }

    return sb_release(&sb);
}

static char **tokenize_whitespace(const char *text, size_t *out_count) {
    size_t capacity = 16;
    size_t count = 0;
    char **tokens = (char **)malloc(capacity * sizeof(char *));
    if (!tokens) {
        fatal("Out of memory");
    }

    size_t length = strlen(text);
    size_t i = 0;
    while (i < length) {
        while (i < length && isspace((unsigned char)text[i])) {
            i++;
        }
        if (i >= length) {
            break;
        }
        size_t start = i;
        while (i < length && !isspace((unsigned char)text[i])) {
            i++;
        }
        size_t token_length = i - start;
        char *token = (char *)malloc(token_length + 1);
        if (!token) {
            fatal("Out of memory");
        }
        memcpy(token, text + start, token_length);
        token[token_length] = '\0';

        if (count == capacity) {
            capacity *= 2;
            char **new_tokens = (char **)realloc(tokens, capacity * sizeof(char *));
            if (!new_tokens) {
                fatal("Out of memory");
            }
            tokens = new_tokens;
        }
        tokens[count++] = token;
    }

    *out_count = count;
    return tokens;
}

static void free_tokens(char **tokens, size_t count) {
    if (!tokens) {
        return;
    }
    for (size_t i = 0; i < count; ++i) {
        free(tokens[i]);
    }
    free(tokens);
}

static char **load_enabled_decoders(size_t *count) {
    char *contents = read_file("enabled-decoders.txt");
    char **tokens = tokenize_whitespace(contents, count);
    free(contents);
    return tokens;
}

static bool decoder_enabled(const char *decoder, char **enabled, size_t count) {
    for (size_t i = 0; i < count; ++i) {
        if (strcmp(decoder, enabled[i]) == 0) {
            return true;
        }
    }
    return false;
}

static char **load_available_codecs(bool encoders, size_t *count) {
    ensure_directory_exists("mplayer-trunk");
    ensure_directory_exists("mplayer-trunk/ffmpeg");

    const char *subject = encoders ? "encoders" : "decoders";
    size_t command_length = (size_t)snprintf(NULL, 0, "cd %s && sh configure --list-%s", "mplayer-trunk/ffmpeg", subject);
    char *command = (char *)malloc(command_length + 1);
    if (!command) {
        fatal("Out of memory");
    }
    snprintf(command, command_length + 1, "cd %s && sh configure --list-%s", "mplayer-trunk/ffmpeg", subject);

    char *output = run_command_capture(command);
    free(command);

    char **tokens = tokenize_whitespace(output, count);
    free(output);
    return tokens;
}

static char *prepare_enabled_decoders_flags(char **enabled_decoders, size_t enabled_count) {
    StringBuffer sb;
    sb_init(&sb);

    for (size_t i = 0; i < enabled_count; ++i) {
        if (enabled_decoders[i][0] == '\0') {
            continue;
        }
        sb_append_format(&sb, "--enable-decoder=%s ", enabled_decoders[i]);
    }

    sb_trim_trailing_whitespace(&sb);
    return sb_release(&sb);
}

static char *prepare_disabled_codecs_flags(bool encoders, char **enabled_decoders, size_t enabled_count) {
    size_t available_count = 0;
    char **available_codecs = load_available_codecs(encoders, &available_count);

    const char *subject = encoders ? "encoder" : "decoder";

    StringBuffer sb;
    sb_init(&sb);

    for (size_t i = 0; i < available_count; ++i) {
        const char *codec = available_codecs[i];
        if (!encoders && decoder_enabled(codec, enabled_decoders, enabled_count)) {
            continue;
        }
        sb_append_format(&sb, "--disable-%s=%s ", subject, codec);
    }

    sb_trim_trailing_whitespace(&sb);
    char *result = sb_release(&sb);
    free_tokens(available_codecs, available_count);
    return result;
}

int main(void) {
    size_t enabled_count = 0;
    char **enabled_decoders = load_enabled_decoders(&enabled_count);

    char *disabled_decoders_flags = prepare_disabled_codecs_flags(false, enabled_decoders, enabled_count);
    char *enabled_decoders_flags = prepare_enabled_decoders_flags(enabled_decoders, enabled_count);
    char *disabled_encoders_flags = prepare_disabled_codecs_flags(true, enabled_decoders, enabled_count);

    printf("DISABLED_DECODERS_FLAGS=\"%s\"\n", disabled_decoders_flags);
    printf("ENABLED_DECODERS_FLAGS=\"%s\"\n", enabled_decoders_flags);
    printf("DISABLED_ENCODERS_FLAGS=\"%s\"\n", disabled_encoders_flags);

    free(disabled_decoders_flags);
    free(enabled_decoders_flags);
    free(disabled_encoders_flags);
    free_tokens(enabled_decoders, enabled_count);

    return EXIT_SUCCESS;
}
