// alpbahOS Solid varsayılan masaüstü düzeni (Plasma 6 scripting API).
// Karar: D115 (docs/DECISIONS.md) -- Windows tarzı tek alt görev çubuğu; üst panel ve dock kaldırıldı.
// Yalnız yeni kullanıcıda ya da "plasma-apply-lookandfeel --resetLayout" ile çalışır.
// Durum: statik taslak; gerçek Plasma oturumunda çalıştırılmadı.

// Tek alt panel: tam genişlik, 44 px. Soldan sağa: başlat menüsü, görev çubuğu (sabitlenmiş
// başlatıcılar + açık pencereler), ayırıcı, sistem tepsisi, saat, masaüstünü göster (sağ uç).
var panel = new Panel;
panel.location = "bottom";
panel.height = 44;
panel.lengthMode = "fill";
panel.floating = false;
panel.opacity = "opaque"; // Solid profili: opak yüzey (MASTER_PLAN §7.2); Glass ayrı profil
panel.hiding = "none";

// Tek başlatıcı: plasmashell tek başına Meta tuşunu ilk "launchermenu" applet'ine
// gönderir (shellcorona.cpp activateLauncherMenu); ikinci başlatıcı Win davranışını belirsizleştirir.
var launcher = panel.addWidget("org.kde.plasma.kickoff");
launcher.currentConfigGroup = ["General"];
launcher.writeConfig("icon", "alpbahos");

// Görev çubuğu: sabitli başlatıcılar (Dolphin, Firefox, Konsole, LibreOffice Writer) ve açık pencereler.
// Firefox ve LibreOffice henüz paketlenmedi; başlatıcı kaydı olarak yer alıyor.
var tasks = panel.addWidget("org.kde.plasma.icontasks");
tasks.currentConfigGroup = ["General"];
tasks.writeConfig("launchers", [
    "applications:org.kde.dolphin.desktop",
    "applications:firefox.desktop",
    "applications:org.kde.konsole.desktop",
    "applications:libreoffice-writer.desktop"
]);

panel.addWidget("org.kde.plasma.marginsseparator");
panel.addWidget("org.kde.plasma.systemtray");
panel.addWidget("org.kde.plasma.digitalclock");
panel.addWidget("org.kde.plasma.showdesktop"); // Win+D benzeri: masaüstünü geçici göster

// Duvar kâğıdı eklentisi; görüntünün kendisi look-and-feel defaults [Wallpaper] Image
// anahtarından gelir (libkworkspace DefaultWallpaper), burada yol sabitlenmez.
var desktopsArray = desktopsForActivity(currentActivity());
for (var j = 0; j < desktopsArray.length; j++) {
    desktopsArray[j].wallpaperPlugin = "org.kde.image";
}
