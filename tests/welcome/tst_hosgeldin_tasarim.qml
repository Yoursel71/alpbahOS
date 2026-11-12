// WELCOME-02 (D177): the Hoş Geldin window (design 4, Main.qml) does what its controls say (qmltestrunner, offscreen).
// A fake backend records the calls the real one would turn into alpbah-hosgeldin-uygula runs and System Settings starts.
// Run: QT_QPA_PLATFORM=offscreen qmltestrunner -import <dir with AlpbahHosgeldin/> -input tst_hosgeldin_tasarim.qml
import QtQuick
import QtTest

TestCase {
    id: tc
    name: "HosgeldinTasarim"
    when: windowShown
    width: 10; height: 10
    visible: true

    Component {
        id: sahteC
        QtObject {
            property var cagri: []
            property bool bitti: false
            property var acilan: []
            property bool glass: true
            property int kod: 0
            function durum() {
                return { glass_kullanilabilir: glass, glass_neden: glass ? "" : "ekran kartı hızlandırması yok",
                         tema: "alpbahos", gorunum: "solid", cubuk: "sol",
                         onizleme: { alpbahos: "/usr/share/wallpapers/alpbahOS-Brand/contents/screenshot.png",
                                     ataturk: "/usr/share/wallpapers/alpbahOS-Ataturk/contents/screenshot.png" } };
            }
            function uygula(t, g, c) { cagri = [t, g, c]; return { kod: kod, cikti: "", hata: kod === 0 ? "" : "Görünüm uygulanmadı: deneme" }; }
            function gec() { cagri = ["gec"]; }
            function bitir() { bitti = true; }
            function ac(id) { acilan = acilan.concat([id]); return true; }
            function kullanici() { return "Deneme Kullanıcı"; }
            function buyukResim(p) { return p; }
        }
    }

    // Click path that picks Atatürk + Glass + Ortada and applies.
    readonly property var yollar: ({ Main: ["tema_ataturk", "gorunum_glass", "cubuk_orta", "uygula"] })

    function olustur(ad, sahte) {
        var c = Qt.createComponent("AlpbahHosgeldin", ad);
        verify(c.status === Component.Ready, ad + ": " + c.errorString());
        var w = c.createObject(null, { backend: sahte });
        verify(w !== null, ad + " oluşturulamadı");
        waitForRendering(w.contentItem);
        return w;
    }
    function bul(w, ad) {
        var o = findChild(w.contentItem, ad);
        verify(o !== null, ad + " bulunamadı");
        return o;
    }
    function tikla(w, ad) {
        var o = bul(w, ad);
        verify(o.visible, ad + " görünmüyor");
        mouseClick(o);
        wait(20);
    }

    function test_1_secip_uygula_data() {
        return [{ tag: "Main" }];
    }
    function test_1_secip_uygula(d) {
        var s = sahteC.createObject(tc);
        var w = olustur(d.tag, s);
        var yol = yollar[d.tag];
        for (var i = 0; i < yol.length; ++i)
            tikla(w, yol[i]);
        compare(s.cagri, ["ataturk", "glass", "orta"], d.tag + ": uygula çağrısı");
        verify(s.bitti, d.tag + ": pencere kapanmadı");
        w.destroy();
    }

    function test_2_gec_data() { return test_1_secip_uygula_data(); }
    function test_2_gec(d) {
        var s = sahteC.createObject(tc);
        var w = olustur(d.tag, s);
        tikla(w, "gec");
        compare(s.cagri, ["gec"]);
        verify(s.bitti);
        w.destroy();
    }

    // Glass is refused when the backend says it cannot work: the apply call keeps Solid.
    function test_3_glass_yok_data() { return test_1_secip_uygula_data(); }
    function test_3_glass_yok(d) {
        var s = sahteC.createObject(tc, { glass: false });
        var w = olustur(d.tag, s);
        var yol = yollar[d.tag];
        for (var i = 0; i < yol.length; ++i) {
            if (yol[i] === "gorunum_glass") {
                var g = bul(w, "gorunum_glass");
                if (g.visible) mouseClick(g);
                continue;
            }
            tikla(w, yol[i]);
        }
        compare(s.cagri, ["ataturk", "solid", "orta"], d.tag);
        w.destroy();
    }

    // A failed apply keeps the window open and shows the error.
    function test_4_hata_data() { return test_1_secip_uygula_data(); }
    function test_4_hata(d) {
        var s = sahteC.createObject(tc, { kod: 1 });
        var w = olustur(d.tag, s);
        var yol = yollar[d.tag];
        for (var i = 0; i < yol.length; ++i)
            tikla(w, yol[i]);
        verify(!s.bitti, d.tag + ": hata varken kapandı");
        verify(bul(w, "mesaj").text.indexOf("deneme") >= 0, d.tag + ": hata metni görünmüyor");
        w.destroy();
    }

    // Keyboard: focus an option, Space selects it.
    function test_5_klavye_data() { return test_1_secip_uygula_data(); }
    function test_5_klavye(d) {
        var s = sahteC.createObject(tc);
        var w = olustur(d.tag, s);
        w.requestActivate();
        tryCompare(w, "active", true);
        var t = bul(w, "tema_ataturk");
        t.forceActiveFocus();
        verify(t.activeFocus, d.tag + ": odak alınamadı");
        keyClick(Qt.Key_Space);
        var yol = yollar[d.tag];
        for (var i = 0; i < yol.length; ++i)
            if (yol[i] !== "tema_ataturk" && yol[i] !== "gorunum_glass" && yol[i] !== "cubuk_orta")
                tikla(w, yol[i]);
        compare(s.cagri[0], "ataturk", d.tag + ": Space ile seçilmedi");
        w.destroy();
    }

    // Start centre: every tile asks the backend for its fixed action and the window stays open.
    function test_7_merkez_kutular() {
        var s = sahteC.createObject(tc);
        var w = olustur("Main", s);
        var ids = ["ag", "yazici", "ekran", "ses", "kisayol", "bilgi"];
        for (var i = 0; i < ids.length; ++i)
            tikla(w, "ac_" + ids[i]);
        compare(s.acilan, ids);
        verify(!s.bitti);
        w.destroy();
    }

}
