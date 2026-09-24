#!/usr/bin/env python3
"""ULTRAKILL 3D Android APK derleyicisi (Android SDK gerektirmez).

Oyunun tek dosyalık HTML'ini (dist/ultrakill-3d.html) tam ekran, yatay, çevrimdışı bir WebView
kabuğuna paketler: dist/ultrakill-3d.apk.

Araçlar Maven Central'dan indirilir, SHA-256 ile doğrulanır ve android/.cache altında tutulur:
  - org.apktool:apktool-lib  → aapt2 (linux) + çerçeve kaynakları (android-framework.jar)
  - com.google.android:android (API 16 derleme saplamaları)
  - com.google.android.tools:dx  → classes.dex
  - com.android.tools.build:apksig  → APK Signature Scheme v2 imzası ve doğrulama
Gerekenler: Python 3.8+, JDK 11+ (javac, java, keytool), Linux x86-64.

İmza anahtarı: UK3D_KEYSTORE (PKCS12), UK3D_KEYSTORE_PASS, UK3D_KEY_ALIAS ortam değişkenleri.
Verilmezse ~/.config/uk3d/debug.p12 oluşturulur. Anahtarı depoya koyma; farklı anahtarla imzalanmış
bir sürümü güncellemek için telefondaki eski uygulamayı önce kaldırmak gerekir.

Kullanım (ultrakill-3d kökünden):  npm run build && python3 android/build_apk.py
"""
import hashlib
import os
import re
import shutil
import struct
import subprocess
import sys
import urllib.request
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
CACHE = os.path.join(HERE, ".cache")
BUILD = os.path.join(HERE, "build")
DIST_HTML = os.path.join(ROOT, "dist", "ultrakill-3d.html")
OUT_APK = os.path.join(ROOT, "dist", "ultrakill-3d.apk")

VERSION_CODE = 2
VERSION_NAME = "1.1"
MIN_SDK = 24  # Android 7.0; WebGL2 için güncel Android System WebView gerekir
TARGET_SDK = 34

MIRRORS = [
    "https://maven-central.storage-download.googleapis.com/maven2",
    "https://repo.maven.apache.org/maven2",
    "https://repo1.maven.org/maven2",
]
TOOLS = {
    "apktool-lib.jar": ("org/apktool/apktool-lib/3.0.3/apktool-lib-3.0.3.jar",
                        "983773879fd89ede2cd938858e3efce2a90ac1123f6a5140e9d949dcf4464e3e"),
    "android.jar": ("com/google/android/android/4.1.1.4/android-4.1.1.4.jar",
                    "84072541cbb711eff89f7277100ff854929a446dba7ceb1b195c340e0b4fd3cb"),
    "dx.jar": ("com/google/android/tools/dx/1.7/dx-1.7.jar",
               "923302e666d76e126e4cdf7129318532b258b1a66e435b92ccc29e91a60357bf"),
    "apksig.jar": ("com/android/tools/build/apksig/2.3.0/apksig-2.3.0.jar",
                   "9637078c0016244e4be0941836295365a7e2e5b164c59cb7885783c40460bfee"),
}
AAPT2_SHA256 = "df312db814c018019b2b79a993b041b738d7b76f4a8f28da25bc874a026368cc"
FRAMEWORK_SHA256 = "5dd984016ed5a5eb0eef866e2c6e8cd352e1427828ec23adb18005cf5648f3d7"


def log(msg):
    print("[apk] " + msg, flush=True)


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def run(cmd, **kw):
    r = subprocess.run(cmd, capture_output=True, text=True, **kw)
    out = "\n".join(l for l in (r.stdout + r.stderr).splitlines() if not l.startswith("Picked up JAVA_TOOL_OPTIONS"))
    if r.returncode != 0:
        sys.exit("[apk] HATA: " + " ".join(cmd[:3]) + " ...\n" + out)
    return out


def fetch_tools():
    os.makedirs(CACHE, exist_ok=True)
    paths = {}
    for name, (rel, digest) in TOOLS.items():
        dst = os.path.join(CACHE, name)
        if not (os.path.exists(dst) and sha256(dst) == digest):
            for base in MIRRORS:
                try:
                    log(f"indiriliyor {rel}")
                    with urllib.request.urlopen(f"{base}/{rel}", timeout=120) as r, open(dst + ".part", "wb") as f:
                        shutil.copyfileobj(r, f)
                    if sha256(dst + ".part") == digest:
                        os.replace(dst + ".part", dst)
                        break
                    log(f"özet uyuşmadı: {base}")
                except OSError as e:
                    log(f"{base}: {e}")
            else:
                sys.exit(f"[apk] HATA: {name} indirilemedi veya doğrulanamadı")
        paths[name] = dst
    aapt2 = os.path.join(CACHE, "aapt2")
    framework = os.path.join(CACHE, "android-framework.jar")
    if not (os.path.exists(aapt2) and sha256(aapt2) == AAPT2_SHA256 and os.path.exists(framework)
            and sha256(framework) == FRAMEWORK_SHA256):
        with zipfile.ZipFile(paths["apktool-lib.jar"]) as z:
            with open(aapt2, "wb") as f:
                f.write(z.read("prebuilt/linux/aapt2"))
            with open(framework, "wb") as f:
                f.write(z.read("prebuilt/android-framework.jar"))
        os.chmod(aapt2, 0o755)
        if sha256(aapt2) != AAPT2_SHA256 or sha256(framework) != FRAMEWORK_SHA256:
            sys.exit("[apk] HATA: aapt2/çerçeve özeti uyuşmadı")
    paths["aapt2"] = aapt2
    paths["framework"] = framework
    return paths


def prepare_assets():
    """assets/www: yerel yazı tipleri ve yerel köprü betiği gömülmüş index.html."""
    if not os.path.exists(DIST_HTML):
        sys.exit("[apk] HATA: dist/ultrakill-3d.html yok — önce `npm run build` çalıştır")
    www = os.path.join(BUILD, "assets", "www")
    shutil.rmtree(os.path.join(BUILD, "assets"), ignore_errors=True)
    shutil.copytree(os.path.join(HERE, "assets-src", "fonts"), os.path.join(www, "fonts"))
    html = open(DIST_HTML, encoding="utf-8").read()
    # Google Fonts bağlantıları → APK içindeki yerel kopya
    html, n = re.subn(r'<link rel="stylesheet" href="https://fonts\.googleapis\.com/css2[^"]*">',
                      '<link rel="stylesheet" href="fonts/fonts.css">', html)
    if n != 1:
        sys.exit("[apk] HATA: Google Fonts bağlantısı bulunamadı (index.html değişmiş olabilir)")
    html = re.sub(r'<link rel="preconnect" href="https://fonts\.[^"]*"( crossorigin)?>\n?', "", html)
    shim = open(os.path.join(HERE, "assets-src", "native-shim.js"), encoding="utf-8").read()
    marker = "<!--ART-HEAD-START-->"
    if marker not in html:
        sys.exit("[apk] HATA: ART-HEAD-START işareti bulunamadı")
    html = html.replace(marker, "<script>\n" + shim + "</script>\n" + marker, 1)
    with open(os.path.join(www, "index.html"), "w", encoding="utf-8") as f:
        f.write(html)
    return os.path.join(BUILD, "assets")


def compile_dex(tools):
    classes = os.path.join(BUILD, "classes")
    shutil.rmtree(classes, ignore_errors=True)
    os.makedirs(classes)
    sources = []
    for d, _, files in os.walk(os.path.join(HERE, "java")):
        sources += [os.path.join(d, f) for f in files if f.endswith(".java")]
    # Saplamalar (-sourcepath) yalnız derlemede kullanılır; -implicit:none ile dex'e girmez.
    run(["javac", "--release", "8", "-Xlint:-options", "-implicit:none", "-encoding", "UTF-8",
         "-classpath", tools["android.jar"], "-sourcepath", os.path.join(HERE, "stubs"), "-d", classes] + sources)
    # dx 1.7 en fazla Java 6 (sürüm 50) sınıf dosyası kabul eder; kod Java 7+ özelliği
    # (invokedynamic, lambda, try-with-resources) kullanmadığı için bayt kodu aynıdır.
    for d, _, files in os.walk(classes):
        for f in files:
            p = os.path.join(d, f)
            with open(p, "r+b") as fh:
                head = fh.read(8)
                major = struct.unpack(">H", head[6:8])[0]
                if major > 50:
                    fh.seek(6)
                    fh.write(struct.pack(">H", 50))
    dex = os.path.join(BUILD, "classes.dex")
    run(["java", "-cp", tools["dx.jar"], "com.android.dx.command.Main", "--dex", "--output=" + dex, classes])
    return dex


def link(tools, assets):
    res_zip = os.path.join(BUILD, "res.zip")
    run([tools["aapt2"], "compile", "--dir", os.path.join(HERE, "res"), "-o", res_zip])
    base = os.path.join(BUILD, "base.apk")
    run([tools["aapt2"], "link", "-o", base, "-I", tools["framework"],
         "--manifest", os.path.join(HERE, "AndroidManifest.xml"), "-A", assets,
         "--min-sdk-version", str(MIN_SDK), "--target-sdk-version", str(TARGET_SDK),
         "--version-code", str(VERSION_CODE), "--version-name", VERSION_NAME, res_zip])
    return base


def package(base, dex):
    """base.apk + classes.dex → hizalanmış, imzasız APK. resources.arsc sıkıştırılmadan 4 bayta hizalanır."""
    out = os.path.join(BUILD, "unsigned.apk")
    with zipfile.ZipFile(base) as src, zipfile.ZipFile(out, "w") as dst:
        entries = [(i, src.read(i)) for i in src.infolist()]
        entries.append((zipfile.ZipInfo("classes.dex", date_time=(2026, 1, 1, 0, 0, 0)), open(dex, "rb").read()))
        for info, data in entries:
            zi = zipfile.ZipInfo(info.filename, date_time=(2026, 1, 1, 0, 0, 0))
            zi.external_attr = 0o644 << 16
            stored = info.filename == "resources.arsc" or (info.filename != "classes.dex" and info.compress_type == zipfile.ZIP_STORED)
            zi.compress_type = zipfile.ZIP_STORED if stored else zipfile.ZIP_DEFLATED
            if stored:
                # yerel başlık (30) + ad + hizalama ekstra alanı (6 + dolgu) sonrası veri 4'ün katı olsun
                pos = dst.fp.tell() + 30 + len(info.filename.encode()) + 6
                pad = (-pos) % 4
                zi.extra = struct.pack("<HHH", 0xD935, 2 + pad, 4) + b"\0" * pad
            dst.writestr(zi, data)
    return out


def keystore():
    ks = os.environ.get("UK3D_KEYSTORE")
    pw = os.environ.get("UK3D_KEYSTORE_PASS", "uk3d-debug")
    alias = os.environ.get("UK3D_KEY_ALIAS", "uk3d")
    if ks:
        return ks, pw, alias
    ks = os.path.join(os.path.expanduser("~"), ".config", "uk3d", "debug.p12")
    if not os.path.exists(ks):
        os.makedirs(os.path.dirname(ks), exist_ok=True)
        log("hata ayıklama imza anahtarı oluşturuluyor: " + ks)
        run(["keytool", "-genkeypair", "-keystore", ks, "-storetype", "PKCS12", "-storepass", pw, "-keypass", pw,
             "-alias", alias, "-keyalg", "RSA", "-keysize", "2048", "-validity", "10000",
             "-dname", "CN=ULTRAKILL 3D fan build, O=alpbahOS"])
    return ks, pw, alias


def main():
    tools = fetch_tools()
    shutil.rmtree(BUILD, ignore_errors=True)
    os.makedirs(BUILD)
    assets = prepare_assets()
    log("kaynaklar bağlanıyor (aapt2)")
    base = link(tools, assets)
    log("Java derleniyor → classes.dex")
    dex = compile_dex(tools)
    unsigned = package(base, dex)
    ks, pw, alias = keystore()
    log("imzalanıyor (apksig, v2)")
    # apksig 2.3.0 sınıf yüklenirken JDK iç sınıfı sun.security.x509'a erişir (JDK 16+ varsayılan olarak kapatır).
    exports = []
    for pkg in ("sun.security.x509",):
        exports += ["--add-exports", "java.base/" + pkg + "=ALL-UNNAMED"]
    print(run(["java"] + exports + ["-cp", tools["apksig.jar"], os.path.join(HERE, "tools", "Sign.java"),
               ks, pw, alias, str(MIN_SDK), unsigned, OUT_APK]))
    badging = run([tools["aapt2"], "dump", "badging", OUT_APK])
    print("\n".join(l for l in badging.splitlines() if re.match(r"(package|sdkVersion|targetSdkVersion|application-label:|launchable-activity|uses-permission|native-code)", l)))
    log(f"yazıldı dist/ultrakill-3d.apk ({os.path.getsize(OUT_APK) / 1024:.0f} KB) SHA-256 {sha256(OUT_APK)}")


if __name__ == "__main__":
    main()
