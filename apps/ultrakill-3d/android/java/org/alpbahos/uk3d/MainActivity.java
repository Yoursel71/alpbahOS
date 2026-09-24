package org.alpbahos.uk3d;

import android.app.Activity;
import android.content.Context;
import android.content.res.AssetManager;
import android.graphics.Color;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.Vibrator;
import android.view.KeyEvent;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;
import android.webkit.JavascriptInterface;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceResponse;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Toast;

import java.io.IOException;
import java.io.InputStream;

/**
 * ULTRAKILL 3D (hayran yapımı) için tam ekran, yatay WebView kabuğu.
 * Oyun APK içindeki assets/ klasöründen, sahte bir https kökenine
 * (appassets.androidplatform.net) eşlenerek sunulur; ağ izni yoktur, tamamen çevrimdışıdır.
 */
public class MainActivity extends Activity {
    private static final String ORIGIN = "https://appassets.androidplatform.net/";
    // View.SYSTEM_UI_FLAG_* (API 16-19): LAYOUT_STABLE | LAYOUT_HIDE_NAVIGATION | LAYOUT_FULLSCREEN
    // | HIDE_NAVIGATION | FULLSCREEN | IMMERSIVE_STICKY
    private static final int IMMERSIVE = 0x100 | 0x200 | 0x400 | 0x2 | 0x4 | 0x1000;

    private WebView web;
    private Vibrator vibrator;
    private final Handler ui = new Handler(Looper.getMainLooper());
    private long lastBack;

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        Window w = getWindow();
        w.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON | WindowManager.LayoutParams.FLAG_FULLSCREEN);
        vibrator = (Vibrator) getSystemService(Context.VIBRATOR_SERVICE);

        web = new WebView(this);
        web.setBackgroundColor(Color.BLACK);
        web.setOverScrollMode(View.OVER_SCROLL_NEVER);
        web.setVerticalScrollBarEnabled(false);
        web.setHorizontalScrollBarEnabled(false);
        web.setHapticFeedbackEnabled(false);
        web.setLongClickable(false);
        web.setOnLongClickListener(new View.OnLongClickListener() {
            @Override
            public boolean onLongClick(View v) { return true; }
        });

        WebSettings s = web.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setSupportZoom(false);
        s.setBuiltInZoomControls(false);
        s.setDisplayZoomControls(false);
        s.setTextZoom(100);
        s.setAllowFileAccess(false);
        s.setAllowContentAccess(false);
        s.setCacheMode(WebSettings.LOAD_NO_CACHE);
        callOptional(s, "setMediaPlaybackRequiresUserGesture", boolean.class, Boolean.FALSE); // API 17
        callOptional(s, "setSafeBrowsingEnabled", boolean.class, Boolean.FALSE); // API 26, yerel içerik

        web.addJavascriptInterface(new Bridge(), "UKNative");
        web.setWebChromeClient(new WebChromeClient());
        web.setWebViewClient(new AssetClient(getAssets()));

        setContentView(web);
        applyImmersive();
        web.loadUrl(ORIGIN + "index.html");
    }

    private static void callOptional(Object target, String name, Class<?> type, Object value) {
        try {
            target.getClass().getMethod(name, type).invoke(target, value);
        } catch (Exception ignored) {
            // eski sürümde yok
        }
    }

    private void applyImmersive() {
        getWindow().getDecorView().setSystemUiVisibility(IMMERSIVE);
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        if (hasFocus) applyImmersive();
    }

    @Override
    protected void onPause() {
        web.loadUrl("javascript:window.__ukNativeLifecycle&&__ukNativeLifecycle(false)");
        web.onPause();
        super.onPause();
    }

    @Override
    protected void onResume() {
        super.onResume();
        web.onResume();
        web.loadUrl("javascript:window.__ukNativeLifecycle&&__ukNativeLifecycle(true)");
        applyImmersive();
    }

    @Override
    protected void onDestroy() {
        web.destroy();
        super.onDestroy();
    }

    @Override
    public boolean onKeyDown(int keyCode, KeyEvent event) {
        if (keyCode == KeyEvent.KEYCODE_BACK) {
            // Sonuç Bridge.back() ile döner.
            web.loadUrl("javascript:UKNative.back(window.__ukNativeBack?__ukNativeBack():'exit')");
            return true;
        }
        return super.onKeyDown(keyCode, event);
    }

    private void backResult(String r) {
        if (!"exit".equals(r)) return;
        long now = System.currentTimeMillis();
        if (now - lastBack < 2000) {
            finish();
        } else {
            lastBack = now;
            Toast.makeText(this, "Çıkmak için GERİ'ye tekrar bas", Toast.LENGTH_SHORT).show();
        }
    }

    /** JS → yerel köprü. Metotlar JavaBridge iş parçacığında çağrılır. */
    public final class Bridge {
        @JavascriptInterface
        public void vibrate(String pattern) {
            if (vibrator == null) return;
            try {
                String[] parts = pattern.split(",");
                if (parts.length == 1) {
                    long ms = Long.parseLong(parts[0].trim());
                    if (ms <= 0) vibrator.cancel();
                    else vibrator.vibrate(Math.min(ms, 1000));
                } else {
                    long[] p = new long[parts.length + 1];
                    p[0] = 0; // Vibrator kalıbı bekleme ile başlar
                    for (int i = 0; i < parts.length; i++) p[i + 1] = Math.min(Long.parseLong(parts[i].trim()), 1000);
                    vibrator.vibrate(p, -1);
                }
            } catch (RuntimeException ignored) {
                // geçersiz kalıp
            }
        }

        @JavascriptInterface
        public void back(final String result) {
            ui.post(new Runnable() {
                @Override
                public void run() { backResult(result); }
            });
        }
    }

    /** assets/ içeriğini ORIGIN altında sunar; başka her istek engellenir. */
    private static final class AssetClient extends WebViewClient {
        private final AssetManager assets;

        AssetClient(AssetManager assets) { this.assets = assets; }

        @Override
        public WebResourceResponse shouldInterceptRequest(WebView view, String url) {
            if (!url.startsWith(ORIGIN)) {
                return new WebResourceResponse("text/plain", "utf-8", null);
            }
            String path = url.substring(ORIGIN.length());
            int q = path.indexOf('?');
            if (q >= 0) path = path.substring(0, q);
            int h = path.indexOf('#');
            if (h >= 0) path = path.substring(0, h);
            if (path.length() == 0) path = "index.html";
            if (path.contains("..")) return new WebResourceResponse("text/plain", "utf-8", null);
            try {
                InputStream in = assets.open("www/" + path);
                return new WebResourceResponse(mime(path), mime(path).startsWith("text/") ? "utf-8" : null, in);
            } catch (IOException e) {
                return new WebResourceResponse("text/plain", "utf-8", null);
            }
        }

        @Override
        public boolean shouldOverrideUrlLoading(WebView view, String url) {
            // Dış bağlantılar uygulama içinde açılmaz.
            return !url.startsWith(ORIGIN);
        }

        private static String mime(String p) {
            if (p.endsWith(".html")) return "text/html";
            if (p.endsWith(".css")) return "text/css";
            if (p.endsWith(".js")) return "text/javascript";
            if (p.endsWith(".woff2")) return "font/woff2";
            if (p.endsWith(".png")) return "image/png";
            if (p.endsWith(".json")) return "application/json";
            return "application/octet-stream";
        }
    }
}
