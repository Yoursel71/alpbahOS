# Zsh 5.9 build commands (added 2026-11-05 as order row 337; not in BLFS 12.4 book; Konsole/Zsh hedefi).
# source: https://downloads.sourceforge.net/project/zsh/zsh/5.9/zsh-5.9.tar.xz
# verification: GPG signature zsh-5.9.tar.xz.asc by key 7CA7ECAAF06216B90F894146ACF8146CAE8CBBC4 (dana <dana@dana.is>); sha256 9b8d1ecedd5b5e81fbf1918e876752a7dd948e05c1a0dba10ab863842d45acd5
# standard autotools build (prefix /usr; etc dir /etc/zsh)

# --- [BUILD] ---
# ncurses 6.5 term.h boolcodes/numcodes ile çakışıyor (Src/Modules/termcap.c): yerel adlar yeniden adlandırılır.
sed -i 's/\bboolcodes\b/zsh_boolcodes/g; s/\bnumcodes\b/zsh_numcodes/g' Src/Modules/termcap.c &&
# configure sigsuspend/link/kill/tcsetpgrp denetimlerini tty'siz derleme ortamında "no" buluyor; zsh
# bu durumda yerine kırılgan bir pause() yolu seçiyor ve chroot içinde komut ikamesi ($(...)) kilitleniyor
# (2026-11-05 T3: strace ile doğrulandı). Linux/glibc'de bu dört denetim yes olmalı; önbellek değişkenleri
# açıkça verilir. Derleme sonrası: chroot'ta `x=$(echo ok)` testi yapılmalı.
./configure --prefix=/usr    \
            --bindir=/bin    \
            --enable-etcdir=/etc/zsh \
            zsh_cv_sys_sigsuspend=yes zsh_cv_sys_killesrch=yes zsh_cv_sys_link=yes zsh_cv_sys_tcsetpgrp=yes &&
make

# --- [INSTALL,ROOT] ---
make install
