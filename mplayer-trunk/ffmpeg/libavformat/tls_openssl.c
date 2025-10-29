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

#include "libavutil/mem.h"
#include "network.h"
#include "os_support.h"
#include "libavutil/random_seed.h"
#include "url.h"
#include "tls.h"
#include "libavutil/opt.h"

#include <openssl/bio.h>
#include <openssl/ssl.h>
#include <openssl/err.h>
#include <openssl/x509v3.h>

/**
 * Convert an EVP_PKEY to a PEM string.
 */
static int pkey_to_pem_string(EVP_PKEY *pkey, char *out, size_t out_sz)
{
    BIO *mem = NULL;
    size_t read_bytes = 0;

    if (!pkey || !out || !out_sz)
        goto done;

    if (!(mem = BIO_new(BIO_s_mem())))
        goto done;

    if (!PEM_write_bio_PrivateKey(mem, pkey, NULL, NULL, 0, NULL, NULL))
        goto done;

    if (!BIO_read_ex(mem, out, out_sz - 1, &read_bytes))
        goto done;

done:
    BIO_free(mem);
    if (out && out_sz)
        out[read_bytes] = '\0';
    return read_bytes;
}

/**
 * Convert an X509 certificate to a PEM string.
 */
static int cert_to_pem_string(X509 *cert, char *out, size_t out_sz)
{
    BIO *mem = NULL;
    size_t read_bytes = 0;

    if (!cert || !out || !out_sz)
        goto done;

    if (!(mem = BIO_new(BIO_s_mem())))
        goto done;

    if (!PEM_write_bio_X509(mem, cert))
        goto done;

    if (!BIO_read_ex(mem, out, out_sz - 1, &read_bytes))
        goto done;

done:
    BIO_free(mem);
    if (out && out_sz)
        out[read_bytes] = '\0';
    return read_bytes;
}


/**
 * Generate a SHA-256 fingerprint of an X.509 certificate.
 */
static int x509_fingerprint(X509 *cert, char **fingerprint)
{
    unsigned char md[EVP_MAX_MD_SIZE];
    int n = 0;
    AVBPrint buf;

    if (X509_digest(cert, EVP_sha256(), md, &n) != 1) {
        av_log(NULL, AV_LOG_ERROR, "TLS: Failed to generate fingerprint, %s\n",
               ERR_error_string(ERR_get_error(), NULL));
        return AVERROR(ENOMEM);
    }

    av_bprint_init(&buf, n*3, n*3);

    for (int i = 0; i < n - 1; i++)
        av_bprintf(&buf, "%02X:", md[i]);
    av_bprintf(&buf, "%02X", md[n - 1]);

    return av_bprint_finalize(&buf, fingerprint);
}

int ff_ssl_read_key_cert(char *key_url, char *cert_url, char *key_buf, size_t key_sz, char *cert_buf, size_t cert_sz, char **fingerprint)
{
    int ret = 0;
    BIO *key_b = NULL, *cert_b = NULL;
    AVBPrint key_bp, cert_bp;
    EVP_PKEY *pkey = NULL;
    X509 *cert = NULL;

    /* To prevent a crash during cleanup, always initialize it. */
    av_bprint_init(&key_bp, 1, MAX_CERTIFICATE_SIZE);
    av_bprint_init(&cert_bp, 1, MAX_CERTIFICATE_SIZE);

    /* Read key file. */
    ret = ff_url_read_all(key_url, &key_bp);
    if (ret < 0) {
        av_log(NULL, AV_LOG_ERROR, "TLS: Failed to open key file %s\n", key_url);
        goto end;
    }

    if (!(key_b = BIO_new(BIO_s_mem()))) {
        ret = AVERROR(ENOMEM);
        goto end;
    }

    BIO_write(key_b, key_bp.str, key_bp.len);
    pkey = PEM_read_bio_PrivateKey(key_b, NULL, NULL, NULL);
    if (!pkey) {
        av_log(NULL, AV_LOG_ERROR, "TLS: Failed to read private key from %s\n", key_url);
        ret = AVERROR(EIO);
        goto end;
    }

    /* Read certificate. */
    ret = ff_url_read_all(cert_url, &cert_bp);
    if (ret < 0) {
        av_log(NULL, AV_LOG_ERROR, "TLS: Failed to open cert file %s\n", cert_url);
        goto end;
    }

    if (!(cert_b = BIO_new(BIO_s_mem()))) {
        ret = AVERROR(ENOMEM);
        goto end;
    }

    BIO_write(cert_b, cert_bp.str, cert_bp.len);
    cert = PEM_read_bio_X509(cert_b, NULL, NULL, NULL);
    if (!cert) {
        av_log(NULL, AV_LOG_ERROR, "TLS: Failed to read certificate from %s\n", cert_url);
        ret = AVERROR(EIO);
        goto end;
    }

    pkey_to_pem_string(pkey, key_buf, key_sz);
    cert_to_pem_string(cert, cert_buf, cert_sz);

    ret = x509_fingerprint(cert, fingerprint);
    if (ret < 0)
        av_log(NULL, AV_LOG_ERROR, "TLS: Failed to generate fingerprint from %s\n", cert_url);

end:
    BIO_free(key_b);
    av_bprint_finalize(&key_bp, NULL);
    BIO_free(cert_b);
    av_bprint_finalize(&cert_bp, NULL);
    EVP_PKEY_free(pkey);
    X509_free(cert);
    return ret;
}

static int openssl_gen_private_key(EVP_PKEY **pkey)
{
    int ret = 0;

    /**
     * Note that secp256r1 in openssl is called NID_X9_62_prime256v1 or prime256v1 in string,
     * not NID_secp256k1 or secp256k1 in string.
     *
     * TODO: Should choose the curves in ClientHello.supported_groups, for example:
     *      Supported Group: x25519 (0x001d)
     *      Supported Group: secp256r1 (0x0017)
     *      Supported Group: secp384r1 (0x0018)
     */
#if OPENSSL_VERSION_NUMBER < 0x30000000L /* OpenSSL 3.0 */
    EC_GROUP *ecgroup = NULL;
    EC_KEY *eckey = NULL;
    int curve = NID_X9_62_prime256v1;
#else
    const char *curve = SN_X9_62_prime256v1;
#endif

#if OPENSSL_VERSION_NUMBER < 0x30000000L /* OpenSSL 3.0 */
    *pkey = EVP_PKEY_new();
    if (!*pkey)
        return AVERROR(ENOMEM);

    eckey = EC_KEY_new();
    if (!eckey) {
        EVP_PKEY_free(*pkey);
        *pkey = NULL;
        return AVERROR(ENOMEM);
    }

    ecgroup = EC_GROUP_new_by_curve_name(curve);
    if (!ecgroup) {
        av_log(NULL, AV_LOG_ERROR, "TLS: Create EC group by curve=%d failed, %s", curve, ERR_error_string(ERR_get_error(), NULL));
        goto einval_end;
    }

    if (EC_KEY_set_group(eckey, ecgroup) != 1) {
        av_log(NULL, AV_LOG_ERROR, "TLS: Generate private key, EC_KEY_set_group failed, %s\n", ERR_error_string(ERR_get_error(), NULL));
        goto einval_end;
    }

    if (EC_KEY_generate_key(eckey) != 1) {
        av_log(NULL, AV_LOG_ERROR, "TLS: Generate private key, EC_KEY_generate_key failed, %s\n", ERR_error_string(ERR_get_error(), NULL));
        goto einval_end;
    }

    if (EVP_PKEY_set1_EC_KEY(*pkey, eckey) != 1) {
        av_log(NULL, AV_LOG_ERROR, "TLS: Generate private key, EVP_PKEY_set1_EC_KEY failed, %s\n", ERR_error_string(ERR_get_error(), NULL));
        goto einval_end;
    }
#else
    *pkey = EVP_EC_gen(curve);
    if (!*pkey) {
        av_log(NULL, AV_LOG_ERROR, "TLS: Generate private key, EVP_EC_gen curve=%s failed, %s\n", curve, ERR_error_string(ERR_get_error(), NULL));
        goto einval_end;
    }
#endif
    goto end;

einval_end:
    ret = AVERROR(EINVAL);
    EVP_PKEY_free(*pkey);
    *pkey = NULL;
end:
#if OPENSSL_VERSION_NUMBER < 0x30000000L /* OpenSSL 3.0 */
    EC_GROUP_free(ecgroup);
    EC_KEY_free(eckey);
#endif
    return ret;
}

static int openssl_gen_certificate(EVP_PKEY *pkey, X509 **cert, char **fingerprint)
{
    int ret = 0, expire_day;
    uint64_t serial;
    const char *aor = "lavf";
    X509_NAME* subject = NULL;

    *cert= X509_new();
    if (!*cert) {
        goto enomem_end;
    }

    // TODO: Support non-self-signed certificate, for example, load from a file.
    subject = X509_NAME_new();
    if (!subject) {
        goto enomem_end;
    }

    serial = av_get_random_seed();
    if (ASN1_INTEGER_set_uint64(X509_get_serialNumber(*cert), serial) != 1) {
        av_log(NULL, AV_LOG_ERROR, "TLS: Failed to set serial, %s\n", ERR_error_string(ERR_get_error(), NULL));
        goto einval_end;
    }

    if (X509_NAME_add_entry_by_txt(subject, "CN", MBSTRING_ASC, aor, strlen(aor), -1, 0) != 1) {
        av_log(NULL, AV_LOG_ERROR, "TLS: Failed to set CN, %s\n", ERR_error_string(ERR_get_error(), NULL));
        goto einval_end;
    }

    if (X509_set_issuer_name(*cert, subject) != 1) {
        av_log(NULL, AV_LOG_ERROR, "TLS: Failed to set issuer, %s\n", ERR_error_string(ERR_get_error(), NULL));
        goto einval_end;
    }
    if (X509_set_subject_name(*cert, subject) != 1) {
        av_log(NULL, AV_LOG_ERROR, "TLS: Failed to set subject name, %s\n", ERR_error_string(ERR_get_error(), NULL));
        goto einval_end;
    }

    expire_day = 365;
    if (!X509_gmtime_adj(X509_get_notBefore(*cert), 0)) {
        av_log(NULL, AV_LOG_ERROR, "TLS: Failed to set notBefore, %s\n", ERR_error_string(ERR_get_error(), NULL));
        goto einval_end;
    }
    if (!X509_gmtime_adj(X509_get_notAfter(*cert), 60*60*24*expire_day)) {
        av_log(NULL, AV_LOG_ERROR, "TLS: Failed to set notAfter, %s\n", ERR_error_string(ERR_get_error(), NULL));
        goto einval_end;
    }

    if (X509_set_version(*cert, 2) != 1) {
        av_log(NULL, AV_LOG_ERROR, "TLS: Failed to set version, %s\n", ERR_error_string(ERR_get_error(), NULL));
        goto einval_end;
    }

    if (X509_set_pubkey(*cert, pkey) != 1) {
        av_log(NULL, AV_LOG_ERROR, "TLS: Failed to set public key, %s\n", ERR_error_string(ERR_get_error(), NULL));
        goto einval_end;
    }

    if (!X509_sign(*cert, pkey, EVP_sha1())) {
        av_log(NULL, AV_LOG_ERROR, "TLS: Failed to sign certificate, %s\n", ERR_error_string(ERR_get_error(), NULL));
        goto einval_end;
    }

    ret = x509_fingerprint(*cert, fingerprint);
    if (ret < 0)
        goto end;

    goto end;
enomem_end:
    ret = AVERROR(ENOMEM);
    goto end;
einval_end:
    ret = AVERROR(EINVAL);
end:
    if (ret) {
        X509_free(*cert);
        *cert = NULL;
    }
    X509_NAME_free(subject);
    return ret;
}

int ff_ssl_gen_key_cert(char *key_buf, size_t key_sz, char *cert_buf, size_t cert_sz, char **fingerprint)
{
    int ret = 0;
    EVP_PKEY *pkey = NULL;
    X509 *cert = NULL;

    ret = openssl_gen_private_key(&pkey);
    if (ret < 0) goto error;

    ret = openssl_gen_certificate(pkey, &cert, fingerprint);
    if (ret < 0) goto error;

    pkey_to_pem_string(pkey, key_buf, key_sz);
    cert_to_pem_string(cert, cert_buf, cert_sz);

error:
    X509_free(cert);
    EVP_PKEY_free(pkey);
    return ret;
}


/**
 * Deserialize a PEM-encoded private or public key from a NUL-terminated C string.
 *
 * @param pem_str   The PEM text, e.g.
 *                  "-----BEGIN PRIVATE KEY-----\n…\n-----END PRIVATE KEY-----\n"
 * @param is_priv   If non-zero, parse as a PRIVATE key; otherwise, parse as a PUBLIC key.
 * @return          EVP_PKEY* on success (must EVP_PKEY_free()), or NULL on error.
 */
static EVP_PKEY *pkey_from_pem_string(const char *pem_str, int is_priv)
{
    BIO *mem = BIO_new_mem_buf(pem_str, -1);
    if (!mem) {
        av_log(NULL, AV_LOG_ERROR, "BIO_new_mem_buf failed\n");
        return NULL;
    }

    EVP_PKEY *pkey = NULL;
    if (is_priv) {
        pkey = PEM_read_bio_PrivateKey(mem, NULL, NULL, NULL);
    } else {
        pkey = PEM_read_bio_PUBKEY(mem, NULL, NULL, NULL);
    }

    if (!pkey)
        av_log(NULL, AV_LOG_ERROR, "Failed to parse %s key from string\n",
              is_priv ? "private" : "public");

    BIO_free(mem);
    return pkey;
}

/**
 * Deserialize a PEM-encoded certificate from a NUL-terminated C string.
 *
 * @param pem_str   The PEM text, e.g.
 *                  "-----BEGIN CERTIFICATE-----\n…\n-----END CERTIFICATE-----\n"
 * @return          X509* on success (must X509_free()), or NULL on error.
 */
static X509 *cert_from_pem_string(const char *pem_str)
{
    BIO *mem = BIO_new_mem_buf(pem_str, -1);
    if (!mem) {
        av_log(NULL, AV_LOG_ERROR, "BIO_new_mem_buf failed\n");
        return NULL;
    }

    X509 *cert = PEM_read_bio_X509(mem, NULL, NULL, NULL);
    if (!cert) {
        av_log(NULL, AV_LOG_ERROR, "Failed to parse certificate from string\n");
        return NULL;
    }

    BIO_free(mem);
    return cert;
}


typedef struct TLSContext {
    TLSShared tls_shared;
    SSL_CTX *ctx;
    SSL *ssl;
    BIO_METHOD* url_bio_method;
    int io_err;
    char error_message[256];
    struct sockaddr_storage dest_addr;
    socklen_t dest_addr_len;
} TLSContext;

/**
 * Retrieves the error message for the latest OpenSSL error.
 *
 * This function retrieves the error code from the thread's error queue, converts it
 * to a human-readable string, and stores it in the TLSContext's error_message field.
 * The error queue is then cleared using ERR_clear_error().
 */
static const char* openssl_get_error(TLSContext *c)
{
    int r2 = ERR_get_error();
    if (r2) {
        ERR_error_string_n(r2, c->error_message, sizeof(c->error_message));
    } else
        c->error_message[0] = '\0';

    ERR_clear_error();
    return c->error_message;
}

int ff_tls_set_external_socket(URLContext *h, URLContext *sock)
{
    TLSContext *c = h->priv_data;
    TLSShared *s = &c->tls_shared;

    if (s->is_dtls)
        c->tls_shared.udp = sock;
    else
        c->tls_shared.tcp = sock;

    return 0;
}

int ff_dtls_export_materials(URLContext *h, char *dtls_srtp_materials, size_t materials_sz)
{
    int ret = 0;
    const char* dst = "EXTRACTOR-dtls_srtp";
    TLSContext *c = h->priv_data;

    ret = SSL_export_keying_material(c->ssl, dtls_srtp_materials, materials_sz,
        dst, strlen(dst), NULL, 0, 0);
    if (!ret) {
        av_log(c, AV_LOG_ERROR, "Failed to export SRTP material, %s\n", openssl_get_error(c));
        return -1;
    }
    return 0;
}

static int print_ssl_error(URLContext *h, int ret)
{
    TLSContext *c = h->priv_data;
    int printed = 0, e, averr = AVERROR(EIO);
    if (h->flags & AVIO_FLAG_NONBLOCK) {
        int err = SSL_get_error(c->ssl, ret);
        if (err == SSL_ERROR_WANT_READ || err == SSL_ERROR_WANT_WRITE)
            return AVERROR(EAGAIN);
    }
    while ((e = ERR_get_error()) != 0) {
        av_log(h, AV_LOG_ERROR, "%s\n", ERR_error_string(e, NULL));
        printed = 1;
    }
    if (c->io_err) {
        av_log(h, AV_LOG_ERROR, "IO error: %s\n", av_err2str(c->io_err));
        printed = 1;
        averr = c->io_err;
        c->io_err = 0;
    }
    if (!printed)
        av_log(h, AV_LOG_ERROR, "Unknown error\n");
    return averr;
}

static int tls_close(URLContext *h)
{
    TLSContext *c = h->priv_data;
    if (c->ssl) {
        SSL_shutdown(c->ssl);
        SSL_free(c->ssl);
    }
    if (c->ctx)
        SSL_CTX_free(c->ctx);
    if (!c->tls_shared.external_sock)
        ffurl_closep(c->tls_shared.is_dtls ? &c->tls_shared.udp : &c->tls_shared.tcp);
    if (c->url_bio_method)
        BIO_meth_free(c->url_bio_method);
    return 0;
}

static int url_bio_create(BIO *b)
{
    BIO_set_init(b, 1);
    BIO_set_data(b, NULL);
    BIO_set_flags(b, 0);
    return 1;
}

static int url_bio_destroy(BIO *b)
{
    return 1;
}

static int url_bio_bread(BIO *b, char *buf, int len)
{
    TLSContext *c = BIO_get_data(b);
    TLSShared *s = &c->tls_shared;
    int ret = ffurl_read(c->tls_shared.is_dtls ? c->tls_shared.udp : c->tls_shared.tcp, buf, len);
    if (ret >= 0) {
        if (s->is_dtls && s->listen && !c->dest_addr_len) {
            int err_ret;

            ff_udp_get_last_recv_addr(s->udp, &c->dest_addr, &c->dest_addr_len);
            err_ret = ff_udp_set_remote_addr(s->udp, (struct sockaddr *)&c->dest_addr, c->dest_addr_len, 1);
            if (err_ret < 0) {
                av_log(c, AV_LOG_ERROR, "Failed connecting udp context\n");
                return err_ret;
            }
            av_log(c, AV_LOG_TRACE, "Set UDP remote addr on UDP socket, now 'connected'\n");
        }

        return ret;
    }
    BIO_clear_retry_flags(b);
    if (ret == AVERROR_EXIT)
        return 0;
    if (ret == AVERROR(EAGAIN))
        BIO_set_retry_read(b);
    else
        c->io_err = ret;
    return -1;
}

static int url_bio_bwrite(BIO *b, const char *buf, int len)
{
    TLSContext *c = BIO_get_data(b);
    int ret = ffurl_write(c->tls_shared.is_dtls ? c->tls_shared.udp : c->tls_shared.tcp, buf, len);
    if (ret >= 0)
        return ret;
    BIO_clear_retry_flags(b);
    if (ret == AVERROR_EXIT)
        return 0;
    if (ret == AVERROR(EAGAIN))
        BIO_set_retry_write(b);
    else
        c->io_err = ret;
    return -1;
}

static long url_bio_ctrl(BIO *b, int cmd, long num, void *ptr)
{
    if (cmd == BIO_CTRL_FLUSH) {
        BIO_clear_retry_flags(b);
        return 1;
    }
    return 0;
}

static int url_bio_bputs(BIO *b, const char *str)
{
    return url_bio_bwrite(b, str, strlen(str));
}

static av_cold void init_bio_method(URLContext *h)
{
    TLSContext *c = h->priv_data;
    BIO *bio;
    c->url_bio_method = BIO_meth_new(BIO_TYPE_SOURCE_SINK, "urlprotocol bio");
    BIO_meth_set_write(c->url_bio_method, url_bio_bwrite);
    BIO_meth_set_read(c->url_bio_method, url_bio_bread);
    BIO_meth_set_puts(c->url_bio_method, url_bio_bputs);
    BIO_meth_set_ctrl(c->url_bio_method, url_bio_ctrl);
    BIO_meth_set_create(c->url_bio_method, url_bio_create);
    BIO_meth_set_destroy(c->url_bio_method, url_bio_destroy);
    bio = BIO_new(c->url_bio_method);
    BIO_set_data(bio, c);

    SSL_set_bio(c->ssl, bio, bio);
}

static void openssl_info_callback(const SSL *ssl, int where, int ret) {
    const char *method = "undefined";
    TLSContext *c = (TLSContext*)SSL_get_ex_data(ssl, 0);

    if (where & SSL_ST_CONNECT) {
        method = "SSL_connect";
    } else if (where & SSL_ST_ACCEPT)
        method = "SSL_accept";

    if (where & SSL_CB_LOOP) {
        av_log(c, AV_LOG_DEBUG, "Info method=%s state=%s(%s), where=%d, ret=%d\n",
               method, SSL_state_string(ssl), SSL_state_string_long(ssl), where, ret);
    } else if (where & SSL_CB_ALERT) {
        method = (where & SSL_CB_READ) ? "read":"write";
        av_log(c, AV_LOG_DEBUG, "Alert method=%s state=%s(%s), where=%d, ret=%d\n",
               method, SSL_state_string(ssl), SSL_state_string_long(ssl), where, ret);
    }
}

static int dtls_handshake(URLContext *h)
{
    int ret = 1, r0, r1;
    TLSContext *c = h->priv_data;

    c->tls_shared.udp->flags &= ~AVIO_FLAG_NONBLOCK;

    r0 = SSL_do_handshake(c->ssl);
    if (r0 <= 0) {
        r1 = SSL_get_error(c->ssl, r0);

        if (r1 != SSL_ERROR_WANT_READ && r1 != SSL_ERROR_WANT_WRITE && r1 != SSL_ERROR_ZERO_RETURN) {
            av_log(c, AV_LOG_ERROR, "Handshake failed, r0=%d, r1=%d\n", r0, r1);
            ret = print_ssl_error(h, r0);
            goto end;
        }
    } else {
        av_log(c, AV_LOG_TRACE, "Handshake success, r0=%d\n", r0);
    }

    /* Check whether the handshake is completed. */
    if (SSL_is_init_finished(c->ssl) != TLS_ST_OK)
        goto end;

    ret = 0;
end:
    return ret;
}

static av_cold int openssl_init_ca_key_cert(URLContext *h)
{
    int ret;
    TLSContext *c = h->priv_data;
    TLSShared *s = &c->tls_shared;
    EVP_PKEY *pkey = NULL;
    X509 *cert = NULL;
    /* setup ca, private key, certificate */
    if (s->ca_file) {
        if (!SSL_CTX_load_verify_locations(c->ctx, s->ca_file, NULL))
            av_log(h, AV_LOG_ERROR, "SSL_CTX_load_verify_locations %s\n", openssl_get_error(c));
    } else {
        if (!SSL_CTX_set_default_verify_paths(c->ctx)) {
            // Only log the failure but do not error out, as this is not fatal
            av_log(h, AV_LOG_WARNING, "Failure setting default verify locations: %s\n",
                openssl_get_error(c));
        }
    }

    if (s->cert_file) {
        ret = SSL_CTX_use_certificate_chain_file(c->ctx, s->cert_file);
        if (ret <= 0) {
            av_log(h, AV_LOG_ERROR, "Unable to load cert file %s: %s\n",
               s->cert_file, openssl_get_error(c));
            ret = AVERROR(EIO);
            goto fail;
        }
    } else if (s->cert_buf) {
        cert = cert_from_pem_string(s->cert_buf);
        if (SSL_CTX_use_certificate(c->ctx, cert) != 1) {
            av_log(c, AV_LOG_ERROR, "SSL: Init SSL_CTX_use_certificate failed, %s\n", openssl_get_error(c));
            ret = AVERROR(EINVAL);
            goto fail;
        }
    }

    if (s->key_file) {
        ret = SSL_CTX_use_PrivateKey_file(c->ctx, s->key_file, SSL_FILETYPE_PEM);
        if (ret <= 0) {
            av_log(h, AV_LOG_ERROR, "Unable to load key file %s: %s\n",
                s->key_file, openssl_get_error(c));
            ret = AVERROR(EIO);
            goto fail;
        }
    } else if (s->key_buf) {
        pkey = pkey_from_pem_string(s->key_buf, 1);
        if (SSL_CTX_use_PrivateKey(c->ctx, pkey) != 1) {
            av_log(c, AV_LOG_ERROR, "Init SSL_CTX_use_PrivateKey failed, %s\n", openssl_get_error(c));
            ret = AVERROR(EINVAL);
            goto fail;
        }
    }

    if (s->listen && !s->cert_file && !s->cert_buf && !s->key_file && !s->key_buf) {
        av_log(h, AV_LOG_VERBOSE, "No server certificate provided, using self-signed\n");

        ret = openssl_gen_private_key(&pkey);
        if (ret < 0)
            goto fail;

        ret = openssl_gen_certificate(pkey, &cert, NULL);
        if (ret < 0)
            goto fail;

        if (SSL_CTX_use_certificate(c->ctx, cert) != 1) {
            av_log(c, AV_LOG_ERROR, "SSL_CTX_use_certificate failed for self-signed cert, %s\n", openssl_get_error(c));
            ret = AVERROR(EINVAL);
            goto fail;
        }

        if (SSL_CTX_use_PrivateKey(c->ctx, pkey) != 1) {
            av_log(c, AV_LOG_ERROR, "SSL_CTX_use_PrivateKey failed for self-signed cert, %s\n", openssl_get_error(c));
            ret = AVERROR(EINVAL);
            goto fail;
        }
    }

    ret = 0;
fail:
    X509_free(cert);
    EVP_PKEY_free(pkey);
    return ret;
}

/**
 * Once the DTLS role has been negotiated - active for the DTLS client or passive for the
 * DTLS server - we proceed to set up the DTLS state and initiate the handshake.
 */
static int dtls_start(URLContext *h, const char *url, int flags, AVDictionary **options)
{
    TLSContext *c = h->priv_data;
    TLSShared *s = &c->tls_shared;
    int ret = 0;
    s->is_dtls = 1;

    if (!c->tls_shared.external_sock) {
        if ((ret = ff_tls_open_underlying(&c->tls_shared, h, url, options)) < 0) {
            av_log(c, AV_LOG_ERROR, "Failed to connect %s\n", url);
            return ret;
        }
    }

    c->ctx = SSL_CTX_new(s->listen ? DTLS_server_method() : DTLS_client_method());
    if (!c->ctx) {
        ret = AVERROR(ENOMEM);
        goto fail;
    }

    ret = openssl_init_ca_key_cert(h);
    if (ret < 0) goto fail;

    /* Note, this doesn't check that the peer certificate actually matches the requested hostname. */
    if (s->verify)
        SSL_CTX_set_verify(c->ctx, SSL_VERIFY_PEER|SSL_VERIFY_FAIL_IF_NO_PEER_CERT, NULL);

    if (s->use_srtp) {
        /**
         * The profile for OpenSSL's SRTP is SRTP_AES128_CM_SHA1_80, see ssl/d1_srtp.c.
         * The profile for FFmpeg's SRTP is SRTP_AES128_CM_HMAC_SHA1_80, see libavformat/srtp.c.
         */
        const char* profiles = "SRTP_AES128_CM_SHA1_80";
        if (SSL_CTX_set_tlsext_use_srtp(c->ctx, profiles)) {
            av_log(c, AV_LOG_ERROR, "Init SSL_CTX_set_tlsext_use_srtp failed, profiles=%s, %s\n",
                profiles, openssl_get_error(c));
            ret = AVERROR(EINVAL);
            goto fail;
        }
    }

    /* The ssl should not be created unless the ctx has been initialized. */
    c->ssl = SSL_new(c->ctx);
    if (!c->ssl) {
        ret = AVERROR(ENOMEM);
        goto fail;
    }

    if (!s->listen && !s->numerichost)
        SSL_set_tlsext_host_name(c->ssl, s->host);

    /* Setup the callback for logging. */
    SSL_set_ex_data(c->ssl, 0, c);
    SSL_CTX_set_info_callback(c->ctx, openssl_info_callback);

    /**
     * We have set the MTU to fragment the DTLS packet. It is important to note that the
     * packet is split to ensure that each handshake packet is smaller than the MTU.
     */
    if (s->mtu <= 0)
        s->mtu = 1096;
    SSL_set_options(c->ssl, SSL_OP_NO_QUERY_MTU);
    SSL_set_mtu(c->ssl, s->mtu);
    DTLS_set_link_mtu(c->ssl, s->mtu);
    init_bio_method(h);

    /* This seems to be necessary despite explicitly setting client/server method above. */
    if (s->listen)
        SSL_set_accept_state(c->ssl);
    else
        SSL_set_connect_state(c->ssl);

    /**
     * During initialization, we only need to call SSL_do_handshake once because SSL_read consumes
     * the handshake message if the handshake is incomplete.
     * To simplify maintenance, we initiate the handshake for both the DTLS server and client after
     * sending out the ICE response in the start_active_handshake function. It's worth noting that
     * although the DTLS server may receive the ClientHello immediately after sending out the ICE
     * response, this shouldn't be an issue as the handshake function is called before any DTLS
     * packets are received.
     *
     * The SSL_do_handshake can't be called if DTLS hasn't prepare for udp.
     */
    if (!c->tls_shared.external_sock) {
        ret = dtls_handshake(h);
        // Fatal SSL error, for example, no available suite when peer is DTLS 1.0 while we are DTLS 1.2.
        if (ret < 0) {
            av_log(c, AV_LOG_ERROR, "Failed to drive SSL context, ret=%d\n", ret);
            return AVERROR(EIO);
        }
    }

    av_log(c, AV_LOG_VERBOSE, "Setup ok, MTU=%d\n", c->tls_shared.mtu);

    return 0;
fail:
    tls_close(h);
    return ret;
}

static int tls_open(URLContext *h, const char *uri, int flags, AVDictionary **options)
{
    TLSContext *c = h->priv_data;
    TLSShared *s = &c->tls_shared;
    int ret;

    if ((ret = ff_tls_open_underlying(s, h, uri, options)) < 0)
        goto fail;

    // We want to support all versions of TLS >= 1.0, but not the deprecated
    // and insecure SSLv2 and SSLv3.  Despite the name, TLS_*_method()
    // enables support for all versions of SSL and TLS, and we then disable
    // support for the old protocols immediately after creating the context.
    c->ctx = SSL_CTX_new(s->listen ? TLS_server_method() : TLS_client_method());
    if (!c->ctx) {
        av_log(h, AV_LOG_ERROR, "%s\n", openssl_get_error(c));
        ret = AVERROR(EIO);
        goto fail;
    }
    if (!SSL_CTX_set_min_proto_version(c->ctx, TLS1_VERSION)) {
        av_log(h, AV_LOG_ERROR, "Failed to set minimum TLS version to TLSv1\n");
        ret = AVERROR_EXTERNAL;
        goto fail;
    }
    ret = openssl_init_ca_key_cert(h);
    if (ret < 0) goto fail;

    if (s->verify)
        SSL_CTX_set_verify(c->ctx, SSL_VERIFY_PEER|SSL_VERIFY_FAIL_IF_NO_PEER_CERT, NULL);
    c->ssl = SSL_new(c->ctx);
    if (!c->ssl) {
        av_log(h, AV_LOG_ERROR, "%s\n", openssl_get_error(c));
        ret = AVERROR(EIO);
        goto fail;
    }
    SSL_set_ex_data(c->ssl, 0, c);
    SSL_CTX_set_info_callback(c->ctx, openssl_info_callback);
    init_bio_method(h);
    if (!s->listen && !s->numerichost) {
        // By default OpenSSL does too lax wildcard matching
        SSL_set_hostflags(c->ssl, X509_CHECK_FLAG_NO_PARTIAL_WILDCARDS);
        if (!SSL_set1_host(c->ssl, s->host)) {
            av_log(h, AV_LOG_ERROR, "Failed to set hostname for TLS/SSL verification: %s\n",
                openssl_get_error(c));
            ret = AVERROR_EXTERNAL;
            goto fail;
        }
        if (!SSL_set_tlsext_host_name(c->ssl, s->host)) {
            av_log(h, AV_LOG_ERROR, "Failed to set hostname for SNI: %s\n", openssl_get_error(c));
            ret = AVERROR_EXTERNAL;
            goto fail;
        }
    }
    ret = s->listen ? SSL_accept(c->ssl) : SSL_connect(c->ssl);
    if (ret == 0) {
        av_log(h, AV_LOG_ERROR, "Unable to negotiate TLS/SSL session\n");
        ret = AVERROR(EIO);
        goto fail;
    } else if (ret < 0) {
        ret = print_ssl_error(h, ret);
        goto fail;
    }

    return 0;
fail:
    tls_close(h);
    return ret;
}

static int tls_read(URLContext *h, uint8_t *buf, int size)
{
    TLSContext *c = h->priv_data;
    TLSShared *s = &c->tls_shared;
    URLContext *uc = s->is_dtls ? s->udp : s->tcp;
    int ret;
    // Set or clear the AVIO_FLAG_NONBLOCK on the underlying socket
    uc->flags &= ~AVIO_FLAG_NONBLOCK;
    uc->flags |= h->flags & AVIO_FLAG_NONBLOCK;
    ret = SSL_read(c->ssl, buf, size);
    if (ret > 0)
        return ret;
    if (ret == 0)
        return AVERROR_EOF;
    return print_ssl_error(h, ret);
}

static int tls_write(URLContext *h, const uint8_t *buf, int size)
{
    TLSContext *c = h->priv_data;
    TLSShared *s = &c->tls_shared;
    URLContext *uc = s->is_dtls ? s->udp : s->tcp;
    int ret;

    // Set or clear the AVIO_FLAG_NONBLOCK on c->tls_shared.tcp
    uc->flags &= ~AVIO_FLAG_NONBLOCK;
    uc->flags |= h->flags & AVIO_FLAG_NONBLOCK;

    if (s->is_dtls) {
        const size_t mtu_size = DTLS_get_data_mtu(c->ssl);
        size = FFMIN(size, mtu_size);
    }

    ret = SSL_write(c->ssl, buf, size);
    if (ret > 0)
        return ret;
    if (ret == 0)
        return AVERROR_EOF;
    return print_ssl_error(h, ret);
}

static int tls_get_file_handle(URLContext *h)
{
    TLSContext *c = h->priv_data;
    TLSShared *s = &c->tls_shared;
    return ffurl_get_file_handle(s->is_dtls ? s->udp : s->tcp);
}

static int tls_get_short_seek(URLContext *h)
{
    TLSContext *c = h->priv_data;
    TLSShared *s = &c->tls_shared;
    return ffurl_get_short_seek(s->is_dtls ? s->udp : s->tcp);
}

static const AVOption options[] = {
    TLS_COMMON_OPTIONS(TLSContext, tls_shared),
    { NULL }
};

static const AVClass tls_class = {
    .class_name = "tls",
    .item_name  = av_default_item_name,
    .option     = options,
    .version    = LIBAVUTIL_VERSION_INT,
};

const URLProtocol ff_tls_protocol = {
    .name           = "tls",
    .url_open2      = tls_open,
    .url_read       = tls_read,
    .url_write      = tls_write,
    .url_close      = tls_close,
    .url_get_file_handle = tls_get_file_handle,
    .url_get_short_seek  = tls_get_short_seek,
    .priv_data_size = sizeof(TLSContext),
    .flags          = URL_PROTOCOL_FLAG_NETWORK,
    .priv_data_class = &tls_class,
};

static const AVClass dtls_class = {
    .class_name = "dtls",
    .item_name  = av_default_item_name,
    .option     = options,
    .version    = LIBAVUTIL_VERSION_INT,
};

const URLProtocol ff_dtls_protocol = {
    .name           = "dtls",
    .url_open2      = dtls_start,
    .url_handshake  = dtls_handshake,
    .url_close      = tls_close,
    .url_read       = tls_read,
    .url_write      = tls_write,
    .url_get_file_handle = tls_get_file_handle,
    .url_get_short_seek  = tls_get_short_seek,
    .priv_data_size = sizeof(TLSContext),
    .flags          = URL_PROTOCOL_FLAG_NETWORK,
    .priv_data_class = &dtls_class,
};
