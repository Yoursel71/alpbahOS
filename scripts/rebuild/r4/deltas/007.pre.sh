# BLFS 13.1 wget, "make the package compatible with OpenSSL 4" (basicnet/wget.html, the step before configure).
NEW_LINE='#if !defined OPENSSL_NO_SSL3_METHOD '
NEW_LINE+='&& OPENSSL_VERSION_NUMBER < 0x40000000L'
sed -i "/SSL3/c $NEW_LINE" src/openssl.c
