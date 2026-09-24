package android.webkit;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * Yalnız derleme için taslak (API 17). Derleme sınıf yolundaki android-4.1.1.4.jar (API 16) bunu
 * içermez; dex'e girmez, çalışma anında cihazın android.webkit.JavascriptInterface sınıfı kullanılır.
 */
@Retention(RetentionPolicy.RUNTIME)
@Target({ElementType.METHOD})
public @interface JavascriptInterface {
}
