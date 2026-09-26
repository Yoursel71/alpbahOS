// alpbahOS Solid varsayılan masaüstü düzeni (Plasma 6.4.4 scripting API).
// Kaynak: docs/alpbahOS-design-mockups.md §4.1 ve §5; MASTER_PLAN §7.1 (üst panel + dock korunur).
// Yalnız yeni kullanıcıda ya da "plasma-apply-lookandfeel --resetLayout" ile çalışır.
// Durum: statik taslak; gerçek Plasma oturumunda çalıştırılmadı.

// Üst panel: sol alpbahOS sembolü (uygulama menüsü) + etkin pencere adı, ortada saat,
// sağda ağ/ses/güç (sistem tepsisi). 34 px: tokens.json panel.height_min/max 32-36.
var topPanel = new Panel;
topPanel.location = "top";
topPanel.height = 34;
topPanel.lengthMode = "fill";
topPanel.floating = false;
topPanel.opacity = "opaque"; // Solid profili: opak yüzey (MASTER_PLAN §7.2); Glass ayrı profil
topPanel.hiding = "none";

// Tek başlatıcı: plasmashell tek başına Meta tuşunu ilk "launchermenu" applet'ine
// gönderir (shellcorona.cpp activateLauncherMenu); ikinci başlatıcı Win davranışını belirsizleştirir.
var launcher = topPanel.addWidget("org.kde.plasma.kickoff");
launcher.currentConfigGroup = ["General"];
launcher.writeConfig("icon", "alpbahos");

topPanel.addWidget("org.kde.plasma.windowlist"); // etkin uygulama adı (showText varsayılanı true)
topPanel.addWidget("org.kde.plasma.panelspacer");
topPanel.addWidget("org.kde.plasma.digitalclock");
topPanel.addWidget("org.kde.plasma.panelspacer");
topPanel.addWidget("org.kde.plasma.systemtray");

// Alt dock: ortalanmış, içeriğe göre genişleyen yüzen panel.
// Sıra (mockup §5): Terminal, Dosyalar, Web, Ayarlar. App Center, alp mağaza arayüzü
// hazır olunca eklenecek (PKG-02); uygulama menüsü üst paneldeki alpbahOS sembolündedir.
var dock = new Panel;
dock.location = "bottom";
dock.height = 52;
dock.lengthMode = "fit";
dock.alignment = "center";
dock.floating = true;
dock.opacity = "opaque";
dock.hiding = "none";

var tasks = dock.addWidget("org.kde.plasma.icontasks");
tasks.currentConfigGroup = ["General"];
tasks.writeConfig("launchers", [
    "applications:org.kde.konsole.desktop",
    "preferred://filemanager",
    "preferred://browser",
    "applications:systemsettings.desktop"
]);

// Duvar kâğıdı eklentisi; görüntünün kendisi look-and-feel defaults [Wallpaper] Image
// anahtarından gelir (libkworkspace DefaultWallpaper), burada yol sabitlenmez.
var desktopsArray = desktopsForActivity(currentActivity());
for (var j = 0; j < desktopsArray.length; j++) {
    desktopsArray[j].wallpaperPlugin = "org.kde.image";
}
