// Shared logic of every Hoş Geldin design (WELCOME-02): the three choices, the Glass check and the calls into the
// C++ backend (alpbah-hosgeldin-uygula durum/uygula/gec, quick actions, quit). A design only draws; it never runs
// a command itself, so all five designs apply the same settings in the same way.
import QtQuick

QtObject {
    id: m
    required property var backend

    readonly property var st: backend.durum()
    property string tema: st.tema || "alpbahos"
    property string gorunum: (st.gorunum === "glass" && glassOk) ? "glass" : "solid"
    property string cubuk: st.cubuk || "sol"
    readonly property bool glassOk: st.glass_kullanilabilir === true
    readonly property string glassNeden: st.glass_neden || "durum okunamadı"
    property string mesaj: ""
    property bool mesgul: false

    readonly property var temaAdi: ({ alpbahos: "alpbahOS", ataturk: "Atatürk" })
    readonly property var gorunumAdi: ({ solid: "Solid", glass: "Glass" })
    readonly property var cubukAdi: ({ sol: "Simgeler solda", orta: "Simgeler ortada" })

    function onizleme(k) {
        return st.onizleme && st.onizleme[k] ? "file://" + st.onizleme[k] : "";
    }
    // The 1920x1080 image of the wallpaper package (large previews); the small screenshot when there is none.
    function buyukResim(k) {
        return st.onizleme && st.onizleme[k] ? "file://" + backend.buyukResim(st.onizleme[k]) : "";
    }
    function gorunumSec(g) {
        if (g === "glass" && !glassOk) {
            mesaj = "Glass kullanılamaz: " + glassNeden + ".";
            return;
        }
        gorunum = g;
    }
    function uygula() {
        mesgul = true;
        mesaj = "Uygulanıyor…";
        var r = backend.uygula(tema, gorunum, cubuk);
        mesgul = false;
        if (r.kod === 0) {
            mesaj = "";
            backend.bitir();
        } else {
            mesaj = r.hata !== "" ? r.hata : "Seçimler uygulanamadı.";
        }
    }
    function gec() {
        backend.gec();
        backend.bitir();
    }
    // Quick actions: the backend maps the id to a fixed command (System Settings modules); unknown ids are refused.
    function ac(id) {
        if (!backend.ac(id))
            mesaj = "Açılamadı. Sistem Ayarları'ndan da ulaşabilirsin.";
    }
}
