import com.android.apksig.ApkSigner;
import com.android.apksig.ApkVerifier;

import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.security.KeyStore;
import java.security.PrivateKey;
import java.security.cert.X509Certificate;
import java.util.Collections;

/**
 * APK'yı apksig ile APK Signature Scheme v2 ile imzalar ve doğrular. minSdk 24+ (Android 7.0+) için
 * v1 (JAR) imzası gerekmez; apksig 2.3.0'ın v1 kodu JDK 17+ iç API'leriyle zaten çalışmaz.
 * Kullanım: java -cp apksig.jar Sign.java <keystore.p12> <parola> <takma-ad> <minSdk> <girdi.apk> <çıktı.apk>
 */
public class Sign {
    public static void main(String[] a) throws Exception {
        if (a.length != 6) {
            System.err.println("kullanım: Sign <keystore.p12> <parola> <takma-ad> <minSdk> <girdi.apk> <çıktı.apk>");
            System.exit(2);
        }
        char[] pass = a[1].toCharArray();
        KeyStore ks = KeyStore.getInstance("PKCS12");
        try (InputStream in = new FileInputStream(a[0])) {
            ks.load(in, pass);
        }
        PrivateKey key = (PrivateKey) ks.getKey(a[2], pass);
        X509Certificate cert = (X509Certificate) ks.getCertificate(a[2]);
        if (key == null || cert == null) throw new IllegalStateException("anahtar bulunamadı: " + a[2]);

        ApkSigner.SignerConfig signer = new ApkSigner.SignerConfig.Builder("UK3D", key, Collections.singletonList(cert)).build();
        new ApkSigner.Builder(Collections.singletonList(signer))
                .setInputApk(new File(a[4]))
                .setOutputApk(new File(a[5]))
                .setMinSdkVersion(Integer.parseInt(a[3]))
                .setV1SigningEnabled(false)
                .setV2SigningEnabled(true)
                .setCreatedBy("alpbahOS ULTRAKILL 3D build_apk.py")
                .build()
                .sign();

        ApkVerifier.Result r = new ApkVerifier.Builder(new File(a[5]))
                .setMinCheckedPlatformVersion(Integer.parseInt(a[3]))
                .build()
                .verify();
        System.out.println("doğrulandı=" + r.isVerified() + " v2=" + r.isVerifiedUsingV2Scheme());
        for (Object e : r.getErrors()) System.out.println("HATA: " + e);
        for (Object w : r.getWarnings()) System.out.println("uyarı: " + w);
        if (!r.isVerified() || !r.isVerifiedUsingV2Scheme()) System.exit(1);
        System.out.println("sertifika SHA-256: " + hex(java.security.MessageDigest.getInstance("SHA-256").digest(cert.getEncoded())));
    }

    private static String hex(byte[] b) {
        StringBuilder s = new StringBuilder();
        for (byte x : b) s.append(String.format("%02x", x));
        return s.toString();
    }
}
