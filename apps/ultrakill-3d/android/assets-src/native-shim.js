// Android APK köprüsü: oyun kodundan önce yüklenir. Oyun kaynağına dokunmadan WebView'e uyarlar.
// UKNative, MainActivity'nin addJavascriptInterface ile verdiği nesnedir.
(function () {
  var N = window.UKNative;
  if (!N) return;
  document.documentElement.classList.add('uk-native');

  // Titreşim: WebView navigator.vibrate'i desteklemez, yerel Vibrator'a yönlendir.
  try {
    Object.defineProperty(navigator, 'vibrate', {
      configurable: true,
      value: function (p) {
        try { N.vibrate(Array.isArray(p) ? p.join(',') : String(p || 0)); } catch (e) { /* yok say */ }
        return true;
      },
    });
  } catch (e) { /* yok say */ }

  // Uygulama zaten tam ekran ve yatay: Fullscreen API'yi sessizce kabul et.
  var ok = function () { return Promise.resolve(); };
  Element.prototype.requestFullscreen = ok;
  Element.prototype.webkitRequestFullscreen = ok;
  try { if (screen.orientation) screen.orientation.lock = ok; } catch (e) { /* yok say */ }

  // Tam ekran butonu ve fare kilidi ipucu gereksiz.
  var st = document.createElement('style');
  st.textContent = '.uk-native .t-full{display:none!important}';
  document.head.appendChild(st);

  // GERİ tuşu: oyundaki duruma göre davran; 'exit' dönerse uygulama çıkışı ister.
  window.__ukNativeBack = function () {
    var g = window.__uk;
    if (!g) return 'exit';
    if (g.touch && g.touch.editing) { g.touch.endEdit(); return 'ok'; }
    switch (g.state) {
      case 'intro': g.ui.introClick(); return 'ok';
      case 'playing': g.pause(); return 'ok';
      case 'paused': g.resume(); return 'ok';
      case 'shop': g.closeShop(); return 'ok';
      case 'results': g.toMenu(); return 'ok';
      case 'dead': return 'ok';
      default: return 'exit';
    }
  };

  // Uygulama arka plana gidince duraklat ve sesi askıya al; dönünce sesi aç.
  window.__ukNativeLifecycle = function (visible) {
    var g = window.__uk;
    if (!g) return;
    var ctx = g.audio && g.audio.ctx;
    if (visible) {
      if (ctx && ctx.state === 'suspended') ctx.resume();
    } else {
      if (g.state === 'playing') g.pause();
      if (g.touch && g.touch.releaseAll) g.touch.releaseAll();
      if (ctx && ctx.state === 'running') ctx.suspend();
    }
  };
})();
