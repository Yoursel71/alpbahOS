#!/usr/bin/env python3
"""BLFS paket betiği üretir (chroot içi). Kullanım: gen_blfs_chroot.py <NN> -> gen_blfs/<NN>.sh
BUILD/INSTALL/CONFIG/ROOT bloklarını alır; OPTIONAL, TEST-only ve SKIPPED-BOX bloklarını atlar."""
import re, sys, pathlib, csv
B = pathlib.Path(__file__).parent
nn = sys.argv[1]
rows = {r[0]: r for r in csv.reader(open(B/"src-meta/packages.tsv", encoding="utf-8"), delimiter="\t")}
row = rows[nn] if nn in rows else None
src = (B/"build-cmds/packages").glob(f"{nn}-*.sh")
path = next(src)
text = path.read_text(encoding="utf-8").split("\n")
blocks = []; cur_tags = None; buf = []
def flush():
    if cur_tags is not None and buf:
        blocks.append((cur_tags, buf[:]))
for ln in text:
    m = re.match(r"^# --- \[(.*)\] ---$", ln)
    if m:
        flush(); cur_tags = set(t.strip() for t in m.group(1).split(",")); buf = []
    elif cur_tags is not None:
        buf.append(ln)
flush()
keep = []
for tags, lines in blocks:
    if tags & {"OPTIONAL", "SKIPPED-BOX"}: continue
    if tags == {"TEST"}: continue
    # 004: Makebelieve_CA_Root örneği (isteğe bağlı CA geçersiz kılma); 192: /etc/sudoers.d/qt (yalnızca sudo kuruluysa)
    if "Makebelieve" in "\n".join(lines) or "sudoers.d" in "\n".join(lines): continue
    # 274 ffmpeg: FATE test takımı (~1 GB örnek indirme + 3800 test) atlanır; test-only
    if "fate-rsync" in "\n".join(lines) or "make fate " in "\n".join(lines): continue
    # 274 ffmpeg: PDF/PS belgeleri yalnızca üretildiyse kurulur (koşullu); üretilmediyse atlanır
    if "doc/*.pdf" in "\n".join(lines): continue
    # 274 ffmpeg: Doxygen API belgeleri yalnızca doxygen kuruluysa üretilir; yoksa atlanır
    if "doc/doxy/html" in "\n".join(lines): continue
    _desc = " ".join(l for l in lines if l.startswith("#")).lower()
    if any(k in _desc for k in ("if you have not", "if you have passed", "if desired", "optional", "if you wish", "if you want")) or (any(k in _desc for k in ("if you have",)) and "INSTALL" not in tags and "OPTIONAL" not in tags):
        continue
    body = [l for l in lines if l.strip() and not (l.startswith("# SKIPPED-BOX") )]
    if not any(not l.startswith("#") for l in body): continue
    keep.append("\n".join(body))
tb = row[2] if row else "MISSING"
pkgfile = f"{row[1]}" if row else nn
hdr = ["#!/bin/bash", "set -eo pipefail", "export XORG_PREFIX=/usr", "export XORG_CONFIG=\"--prefix=$XORG_PREFIX --sysconfdir=/etc --localstatedir=/var --disable-static\"", "export KF6_PREFIX=/usr", "as_root() { \"$@\"; }; export -f as_root", "cd /sources/blfs-build 2>/dev/null || { mkdir -p /sources/blfs-build && cd /sources/blfs-build; }",
       f'TB="/sources/blfs-src/{tb}"; [ -f "$TB" ] || {{ echo "KAYNAK_YOK $TB"; exit 2; }}',
       ('PKG=$(basename "$TB" .zip); rm -rf "$PKG"; mkdir -p "$PKG"; cd "$PKG"; unzip -q "$TB"' if tb.endswith('.zip') else 'PKG=$(tar -tf "$TB" | sed -n 1p | cut -d/ -f1); rm -rf "$PKG"; tar -xf "$TB"; cd "$PKG"')]
out = hdr + [""] + [f"# --- blok {i} ---\n{b}\n_rc=$?; [ \"$_rc\" -eq 0 ] || {{ echo \"BLOK-FAIL {i} rc=$_rc\"; exit 1; }}" for i, b in enumerate(keep, 1)]
# SAPMALAR (BLFS kitabının kendi seçeneği; plandaki eksik öneri bağımlılığı için):
#  009 cmake: libuv 'Recommended' ama plan'da yok -> kitabın --no-system-libuv seçeneği (bundled libuv)
OVR = {"009": [("--system-libs        \\", "--system-libs        \\\n            --no-system-libuv    \\")]}
for old, new in OVR.get(nn, []):
    out_text = "\n".join(out)
    if old in out_text:
        out = out_text.replace(old, new).split("\n")
# 021 URI: test bağımlılıkları (Test::Needs, Test::Warnings) isteğe bağlı; testler başarısız olursa kaydet, devam et
if nn == "021":
    _t = "\n".join(out)
    _t = _t.replace("\nmake test\n", '\nmake test || echo "URI-5.32: 3 test programi isteğe bağlı Test::Needs/Test::Warnings olmadan çalışmadı" >> /sources/test-skips.txt\n')
    out = _t.split("\n")
# 036 alsa-lib: API dokümantasyonu isteğe bağlı (Doxygen gerektirir); doküman adımlarını atla
if nn == "036":
    _t = "\n".join(out)
    _t = _t.replace("\nmake doc\n", "\n# make doc atlandi (Doxygen yok, istege bagli)\n")
    _t = _t.split("# To install the API documentation")[0]
    out = _t.split("\n")
# 040 libical: GObject introspection yok -> kitabın -DGOBJECT_INTROSPECTION=False seçeneği; API dokümanları (make docs) isteğe bağlı
if nn == "040":
    _t = "\n".join(out)
    _t = _t.replace("-D GOBJECT_INTROSPECTION=true", "-D GOBJECT_INTROSPECTION=False")
    _t = _t.replace("      -D ICAL_GLIB_VAPI=false        \\", "      -D ICAL_GLIB=False             \\\n      -D ICAL_GLIB_VAPI=false        \\")
    _t = _t.replace("-D ICAL_GLIB=true", "-D ICAL_GLIB=False")
    _t = _t.replace("\nmake docs\n", "\n# make docs atlandi (istege bagli)\n")
    _t = _t.split("# --- blok 4 ---")[0]
    out = _t.split("\n")
# 040 libical: ICAL_GLIB_VAPI=true GObject Introspection gerektirir (sayfa GOBJECT_INTROSPECTION=False); Vala vapi Plasma için gerekmez
if nn == "040":
    out = ["\n".join(out).replace("-D ICAL_GLIB_VAPI=true", "-D ICAL_GLIB_VAPI=false").replace("-D ICAL_GLIB_VAPI=false", "-D ICAL_GLIB_VAPI=false -D ICAL_GLIB=false").split("\n")][0]
# GENEL: doxygen (isteğe bağlı API dokümanı) çağıran satırları atla; Doxygen kurulu değil
out = [("# doxygen atlandi (istege bagli): " + l if l.lstrip().startswith("doxygen ") else l) for l in out]
# 047 glib: man-pages docutils (rst2man) gerektirir; planda docutils yok -> man sayfaları kapalı
if nn == "047":
    out = ["\n".join(out).replace("-D man-pages=enabled", "-D man-pages=disabled").split("\n")][0]
# 047 glib: GObject Introspection ikinci derleme (ek indirme) isteğe bağlı -> bloklar 3+ atlanır (GLib introspection kapalı)
if nn == "047":
    _keep=[]
    for _b in out:
        if "gobject-introspection" in _b or "gi-build" in _b:
            break
        _keep.append(_b)
    out = _keep
# 049 harfbuzz: graphite2 planda yok (önerilen); kitabın -D graphite2=disabled seçeneği
if nn == "049":
    out = [l.replace("-D graphite2=enabled", "-D graphite2=disabled") if isinstance(l,str) else l for l in out]
    out = "\n".join(out).replace("-D graphite2=enabled", "-D graphite2=disabled").split("\n")
# 062 polkit: GObject Introspection planda yok -> introspection=false
if nn == "062":
    out = ["\n".join(out).replace("-D tests=true", "-D tests=true                \\\n      -D introspection=false").split("\n")][0]
# 062 polkit: polkitd kullanıcısı zaten varsa yeniden oluşturma
if nn == "062":
    out = "\n".join(out).replace("\nuseradd -c \"PolicyKit", "\nid polkitd >/dev/null 2>&1 || useradd -c \"PolicyKit").split("\n")
# 064 NetworkManager: GObject introspection yok; isteğe bağlı -> kitabın -Dintrospection=false seçeneği
if nn == "064":
    out = "\n".join(out).replace("      -D modem_manager=false      &&", "      -D modem_manager=false      \\\n      -D introspection=false      &&").split("\n")
    out = [("# <username> yer tutucu, atlandi (kullanici tanimlanmadi): " + l if "<username>" in l else l) for l in out]
# 066 ModemManager: mbim-glib/qmi (isteğe bağlı modem sürücüleri) yok -> kapat
if nn == "066":
    out = "\n".join(out).replace("      -D qrtr=false            &&", "      -D qrtr=false            \\\n      -D mbim=false            \\\n      -D qmi=false             &&").split("\n")
# 066 ModemManager: GObject Introspection planda yok -> introspection=false
if nn == "066":
    out = ["\n".join(out).replace("      -D qmi=false             &&", "      -D qmi=false             \\\n      -D introspection=false   &&").split("\n")][0]
# 128 mesa: Vulkan zinciri (glslang, Vulkan-Headers, Vulkan-Loader) planda yok -> vulkan-drivers kapalı (Plasma Wayland için gerekmez)
if nn == "128":
    out = ["\n".join(out).replace("-D vulkan-drivers=auto  ", "-D vulkan-drivers=[]    ").split("\n")][0]
# 128 mesa: LLVM'siz derleme; sürücüler nouveau + virgl (açık sürücüler); rusticl/OpenCL kapalı (libclc yok)
if nn == "128":
    out = "\n".join(out).replace("      -D gallium-drivers=auto  \\", "      -D gallium-drivers=nouveau,virgl \\\n      -D llvm=disabled         \\\n      -D gallium-rusticl=false \\").split("\n")
# GRUP: md5-listeli döngü blokları (lib-7.md5 / xcb-utils.md5). Grup başı tüm döngüyü çalıştırır; üyeler atlanır.
import html as _h, re as _re, glob as _g
_grp = None
_HEADS = {"lib-7.md5": "079", "xcb-utils.md5": "074", "app-7.md5": "130", "font-7.md5": "164", "frameworks-6.17.0.md5": "201", "plasma-6.4.4.md5": "280"}
for _b in out:
    _mm = _re.search(r"\.\./([A-Za-z0-9_.-]+\.md5)", _b) or _re.search(r"<\s*([A-Za-z0-9_.-]+\.md5)\s*$", _b, flags=_re.M)
    if _mm and _mm.group(1) in _HEADS:
        _grp = (_mm.group(1), _HEADS[_mm.group(1)])
if _grp:
    _md5name, _head = _grp
    if nn != _head:
        out = ["#!/bin/bash", "# GRUP ÜYESİ: %s grup başı %s tarafından derlenir" % (nn, _head), "echo GROUP-MEMBER-OF-%s" % _head]
    else:
        _txt = ""
        for _f in _g.glob(str(B/"build-cmds"/"raw"/"*.html")):
            _raw = open(_f, encoding="utf-8", errors="replace").read()
            _m = _re.search(r'cat &gt; ' + _re.escape(_md5name) + r' &lt;&lt; "EOF"\s*(.*?)\n\s*EOF', _raw, flags=_re.S)
            if _m:
                _txt = _h.unescape(_re.sub(r'<[^>]+>', '', _m.group(1))).strip("\n")
                break
        _hdr = ["#!/bin/bash", "set -eo pipefail", "export XORG_PREFIX=/usr", 'export XORG_CONFIG="--prefix=$XORG_PREFIX --sysconfdir=/etc --localstatedir=/var --disable-static"',
                "export KF6_PREFIX=/usr", "mkdir -p /sources/blfs-build/xorg && cd /sources/blfs-build/xorg",
                "for _f in /sources/blfs-src/*; do ln -sfn \"$_f\" .; done",
                "cat > /sources/blfs-build/%s << 'MD5EOF'" % _md5name, _txt, "MD5EOF",
                "cp /sources/blfs-build/%s /sources/blfs-build/xorg/%s" % (_md5name, _md5name),
                "test -s /sources/blfs-build/%s" % _md5name]
        out = _hdr + [b for b in out if not b.startswith("#!/bin/bash") and not b.startswith("set -eo pipefail")
                      and not b.startswith("export ") and not b.startswith("cd /sources/blfs-build") and "TB=" not in b and "PKG=" not in b and "PKG" not in b]
        out = ["\n".join(out).replace("tar -xf $file", "rm -rf $packagedir; tar -xf $file").replace("tar -xf $package", "rm -rf $packagedir; tar -xf $package").split("\n")][0]
# 173 xorg-server: secure-rpc için libtirpc yok (planda değil) -> secure-rpc=false (NFS güvenli RPC, masaüstü için gereksiz)
if nn == "173":
    out = "\n".join(out).replace("      -D glamor=true        \\", "      -D glamor=true        \\\n      -D secure-rpc=false   \\").split("\n")
# 176 xwayland: secure-rpc için libtirpc gerekir (planda yok; glibc 2.42 RPC içermez) -> secure-rpc=false (xorg-server 173 ile aynı)
if nn == "176":
    out = ["\n".join(out).replace("      -D xkb_output_dir=/var/lib/xkb &&", "      -D xkb_output_dir=/var/lib/xkb \\\n      -D secure-rpc=false &&").split("\n")][0]
# 183 gnutls: libunistring planda yok -> kitabın --with-included-unistring seçeneği
if nn == "183":
    out = ["\n".join(out).replace('--with-default-trust-store-pkcs11="pkcs11:" &&', '--with-default-trust-store-pkcs11="pkcs11:" --with-included-unistring &&').split("\n")][0]
# 185 gsettings-desktop-schemas: GObject Introspection planda yok -> introspection=false
if nn == "185":
    out = ["\n".join(out).replace("meson setup --prefix=/usr --buildtype=release .. &&", "meson setup --prefix=/usr --buildtype=release -D introspection=false .. &&").split("\n")][0]
# 186 gdk-pixbuf: man sayfaları rst2man (docutils) ister, planda yok -> man=false
if nn == "186":
    out = ["\n".join(out).replace("      -D others=enabled   \\", "      -D others=enabled   \\\n      -D man=false        \\").split("\n")][0]
# 188 pango: introspection=enabled -> disabled (GObject Introspection planda yok)
if nn == "188":
    out = ["\n".join(out).replace("-D introspection=enabled", "-D introspection=disabled").split("\n")][0]
# 190 gtk3: man=true rst2man (docutils) ister -> man=false; GI planda yok -> introspection=false
if nn == "190":
    out = ["\n".join(out).replace("-D man=true         \\", "-D man=false        \\\n      -D introspection=false \\").split("\n")][0]
# 190 gtk3: isteğe bağlı gtk.css yazımı için hedef dizini oluştur
if nn == "190":
    out = "\n".join(out).replace("cat > ~/.config/gtk-3.0/gtk.css", "mkdir -p ~/.config/gtk-3.0 && cat > ~/.config/gtk-3.0/gtk.css").split("\n")
# 192 qt6: $QT6PREFIX kitabın dışlanan qt6-prefix bloğunda; kitabın varsayılanı /opt/qt6
if nn == "192":
    out = ["export QT6PREFIX=/opt/qt6"] + out
# Qt6 ortamı (192 sonrası paketler): profile.d değişkenleri betiğe geçmediği için açıkça tanımlanır
if nn >= "192":
    out = ["export QT6DIR=/opt/qt6", "export QT6PREFIX=/opt/qt6", "export PATH=/opt/qt6/bin:$PATH", "export PKG_CONFIG_PATH=/opt/qt6/lib/pkgconfig:${PKG_CONFIG_PATH:-}"] + out
# 128 mesa: llvmpipe (yazılım çizimi) için LLVM etkin olmalı; kitabın llvm=disabled satırı değiştirilir
if nn == "128":
    out = ["\n".join(out).replace("-D llvm=disabled", "-D llvm=enabled ").split("\n")][0]
# 200 sddm: man sayfaları rst2man (docutils) ister, planda yok -> BUILD_MAN_PAGES=OFF
if nn == "200":
    out = ["\n".join(out).replace("-D BUILD_MAN_PAGES=ON", "-D BUILD_MAN_PAGES=OFF").split("\n")][0]
# 128 mesa: llvmpipe (swrast) gallium sürücüsü eklenir -> yazılım çizimi
if nn == "128":
    out = ["\n".join(out).replace("-D gallium-drivers=nouveau,virgl", "-D gallium-drivers=nouveau,virgl,llvmpipe").split("\n")][0]
# 200 sddm: test-mode bloğu yer tutucu (<theme path>) içerir -> atlanır
if nn == "200":
    out = [b for b in out if "--test-mode" not in b]
# 186 gdk-pixbuf: test hedefleri varsayılan ninja'da derleniyor ve gdk-pixbuf/gdk-pixbuf.h hatasıyla kırılıyor -> tests=false (DEVIATIONS.md)
if nn == "186":
    out = ["\n".join(out).replace("-D man=false        \\", "-D man=false        \\\n      -D tests=false      \\").split("\n")][0]
# 064 NetworkManager: nmtui kapalı (libnewt planda yok; DEVIATIONS.md'ye bakın); plasma-nm/networkmanager-qt libnm kullanır
if nn == "064":
    out = ["\n".join(out).replace("-D nmtui=true", "-D nmtui=false").split("\n")][0]
# 064 NetworkManager: kripto arka ucu gnutls (183 tamam); /etc/NetworkManager dizini yoksa oluşturulur
if nn == "064":
    out = ["\n".join(out).replace("-D libaudit=no", "-D crypto=gnutls  \\\n      -D libaudit=no").replace("cat >> /etc/NetworkManager/NetworkManager.conf", "install -vdm755 /etc/NetworkManager && cat >> /etc/NetworkManager/NetworkManager.conf").split("\n")][0]
# 064: /etc/NetworkManager/conf.d dizini yoksa oluşturulur
if nn == "064":
    out = ["\n".join(out).replace("cat > /etc/NetworkManager/conf.d/polkit.conf", "install -vdm755 /etc/NetworkManager/conf.d && cat > /etc/NetworkManager/conf.d/polkit.conf").split("\n")][0]
# 064: chroot içinde systemctl çalışmaz; etkinleştirme önyüklenmiş sistemde yapılacak (satırlar yorum)
if nn == "064":
    out = ["\n".join("# CHROOT-SKIP: " + l if l.lstrip().startswith("systemctl ") else l for l in "\n".join(out).split("\n")).split("\n")][0]
    out = ["\n".join(out).replace("\n", "\n")][0].split("\n")
dst = B/"gen_blfs"/f"{nn}.sh"; dst.parent.mkdir(exist_ok=True)
# 280 plasma grubu: kinfocenter opengl-helper QVulkanInstance ister (Qt Vulkan'sız derlendi) -> yalnız kinfocenter için alt dizin kapatılır (DEVIATIONS.md)
if nn == "280":
    _kfix = "    [ \"$name\" = kinfocenter ] && sed -i 's/^add_subdirectory(opengl-helper)/#&/' kcms/about-distro/src/CMakeLists.txt && sed -i 's/add_subdirectory( *about-distro *)/#&/' kcms/CMakeLists.txt\n"
    out = ["\n".join(out).replace("    pushd $packagedir\n", "    pushd $packagedir\n" + _kfix).split("\n")][0]
    # plasma-desktop: mouse/touchpad KCM'leri X11 (xorg-libinput) ister; planda yok -> X11 varyantları kapalı (DEVIATIONS.md)
    out = re.sub(r"(-D BUILD_TESTING=OFF\s*\\)", r"\1\n             -D BUILD_KCM_MOUSE_X11=OFF \\\n             -D BUILD_KCM_TOUCHPAD_X11=OFF \\", "\n".join(out)).split("\n")
# 276 sassc: kitabın 'popd' satırı pushd'u (libsass derlemesi) gerektirir; libsass 275'te /usr'a kuruldu -> popd yerine SASS_LIBSASS_PATH=/usr
if nn == "276":
    out = ["\n".join(out).replace("popd &&", "export SASS_LIBSASS_PATH=/usr &&").split("\n")][0]
# 274 ffmpeg: nasm/yasm yok, planda olmayan codec kütüphaneleri (aom, ass, fdk-aac, mp3lame, opus, vpx, x264, x265, nonfree) kaldırıldı; --disable-x86asm (DEVIATIONS.md)
if nn == "274":
    _t = "\n".join(out)
    _t = re.sub(r"\n[ \t]*--enable-(?:libaom|libass|libfdk-aac|libmp3lame|libopus|libvpx|libx264|libx265|nonfree)[ \t]*\\(?=\n)", "", _t)
    _t = _t.replace("--disable-debug      \\", "--disable-debug      \\\n            --disable-x86asm     \\")
    out = _t.split("\n")
# 201 KF6 Sonnet: yazım denetimi arka ucu yok (hunspell/aspell/hspell/voikko kurulu değil; hunspell kaynağı/md5 doğrulanamadı) -> SONNET_NO_BACKENDS=ON (DEVIATIONS.md)
if nn == "201":
    out = ["\n".join(out).replace("-D BUILD_PYTHON_BINDINGS=OFF        \\", "-D BUILD_PYTHON_BINDINGS=OFF        \\\n            -D SONNET_NO_BACKENDS=ON \\\n            -D BUILD_KWALLETD=OFF \\").split("\n")][0]
# Yeniden çalıştırmada kalan doc dizini mv'yi bozmasın: mv -v /usr/share/doc/X{-ver,} öncesi hedefi temizle
out = [re.sub(r"mv -v /usr/share/doc/([A-Za-z0-9_.+-]+)\{(-[^,}]+),\}", r"rm -rf /usr/share/doc/\1 && mv -v /usr/share/doc/\1{\2,}", l) for l in out]
out = [re.sub(r"mv -v (\$XORG_PREFIX|/usr)/share/doc/([A-Za-z0-9_.+-]+)\{,(-[^}]+)\}", r"rm -rf \1/share/doc/\2\3 && mv -v \1/share/doc/\2{,\3}", l) for l in out]
dst.write_text("\n".join(out) + "\n", encoding="utf-8")
print(dst, len(keep), "blok")
