# BLFS 12.4-systemd build commands, copied verbatim from the page.
# REFERENCE ONLY: nothing here has been run. Boxes marked SKIPPED-BOX are commented out.
# package: CrackLib-2.10.3   (order.txt row 045, REQ)
# page: https://www.linuxfromscratch.org/blfs/view/12.4-systemd/postlfs/cracklib.html

# --- [BUILD] ---
# Install CrackLib by running the following commands:
CPPFLAGS+=' -I /usr/include/python3.13' \
./configure --prefix=/usr               \
            --disable-static            \
            --with-default-dict=/usr/lib/cracklib/pw_dict &&
make

# --- [INSTALL,ROOT] ---
# Now, as the root user:
make install

# --- [INSTALL,ROOT] ---
# Issue the following commands as the root user to install the recommended word list and create
# the CrackLib dictionary. Other word lists (text based, one word per line) can also be used by
# simply installing them into /usr/share/dict and adding them to the create-cracklib-dict command.
xzcat ../cracklib-words-2.10.3.xz \
                       > /usr/share/dict/cracklib-words       &&
ln -v -sf cracklib-words /usr/share/dict/words                &&
echo $(hostname) >>      /usr/share/dict/cracklib-extra-words &&
install -v -m755 -d      /usr/lib/cracklib                    &&

create-cracklib-dict     /usr/share/dict/cracklib-words \
                         /usr/share/dict/cracklib-extra-words

# --- [TEST,OPTIONAL] ---
# If desired, check the proper operation of the library as an unprivileged user by issuing the
# following command:
make test

# --- [TEST,OPTIONAL] ---
# If desired, test the Python module with:
python3 -c 'import cracklib; cracklib.test()'
