# REBUILD-R4 193 (13.1 qca page): OpenSSL 4 fixes patch (no md5 on the page: TOFU) and the CA bundle path.
# Run from the build directory: the book applies them in the source tree before cmake.
cd .. && patch -Np1 -i ../qca-2.3.10-openssl4_fixes-1.patch && sed -i 's@cert.pem@certs/ca-bundle.crt@' CMakeLists.txt && cd build || exit 1
