// alpbahOS Hoş Geldin (WELCOME-01, D121): Qt 6 QML window; the settings logic lives in alpbah-hosgeldin-uygula.
// --ilk-acilis (XDG autostart): exits at once unless "alpbah-hosgeldin-uygula ilk-acilis-mi" says this is the first
// login of an installed user (no marker, not the live session).
// WELCOME-02: --tasarim <Main|Sihirbaz|Ayna|Kompakt|Merkez|Vitrin> picks the window (default Main); every design gets
// the backend as its required property "backend". --ozellik <ad=değer> (repeatable) sets other initial properties
// (screenshots of one state, e.g. adim=3).
#include <QApplication>
#include <QDir>
#include <QFileInfo>
#include <QHash>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QSGRendererInterface>
#include <QTimer>
#include <QVariantMap>
#include <pwd.h>
#include <unistd.h>

static const char *APPLY_TOOL = "alpbah-hosgeldin-uygula";

class Backend : public QObject
{
    Q_OBJECT
public:
    using QObject::QObject;

    Q_INVOKABLE QVariantMap durum()
    {
        QProcess p;
        p.start(QString::fromLatin1(APPLY_TOOL), {QStringLiteral("durum")});
        p.waitForFinished(60000);
        const auto doc = QJsonDocument::fromJson(p.readAllStandardOutput());
        return doc.object().toVariantMap();
    }

    Q_INVOKABLE QVariantMap uygula(const QString &tema, const QString &gorunum, const QString &cubuk)
    {
        QProcess p;
        p.start(QString::fromLatin1(APPLY_TOOL), {QStringLiteral("uygula"), QStringLiteral("--tema"), tema,
                                                  QStringLiteral("--gorunum"), gorunum, QStringLiteral("--cubuk"), cubuk});
        p.waitForFinished(120000);
        QVariantMap r;
        r[QStringLiteral("kod")] = p.exitStatus() == QProcess::NormalExit ? p.exitCode() : -1;
        r[QStringLiteral("cikti")] = QString::fromUtf8(p.readAllStandardOutput()).trimmed();
        r[QStringLiteral("hata")] = QString::fromUtf8(p.readAllStandardError()).trimmed();
        return r;
    }

    Q_INVOKABLE void gec()
    {
        QProcess::execute(QString::fromLatin1(APPLY_TOOL), {QStringLiteral("gec")});
    }

    Q_INVOKABLE void bitir()
    {
        QCoreApplication::quit();
    }

    // Full name from the password database (first GECOS field), else the login name.
    Q_INVOKABLE QString kullanici()
    {
        const struct passwd *pw = getpwuid(getuid());
        if (!pw)
            return QString();
        QString ad = pw->pw_gecos ? QString::fromLocal8Bit(pw->pw_gecos).section(QLatin1Char(','), 0, 0).trimmed() : QString();
        return ad.isEmpty() ? QString::fromLocal8Bit(pw->pw_name) : ad;
    }

    // <package>/contents/screenshot.png -> <package>/contents/images/1920x1080.<ext> when the package has it.
    Q_INVOKABLE QString buyukResim(const QString &onizleme)
    {
        const QDir images(QFileInfo(onizleme).dir().filePath(QStringLiteral("images")));
        const QStringList found = images.entryList({QStringLiteral("1920x1080.*")}, QDir::Files, QDir::Name);
        return found.isEmpty() ? onizleme : images.filePath(found.first());
    }

    // Quick actions: fixed commands only; the QML side passes an id, never a command line.
    Q_INVOKABLE bool ac(const QString &id)
    {
        static const QHash<QString, QStringList> komutlar = {
            {QStringLiteral("ag"), {QStringLiteral("systemsettings"), QStringLiteral("kcm_networkmanagement")}},
            {QStringLiteral("yazici"), {QStringLiteral("systemsettings"), QStringLiteral("kcm_printer_manager")}},
            {QStringLiteral("ekran"), {QStringLiteral("systemsettings"), QStringLiteral("kcm_kscreen")}},
            {QStringLiteral("ses"), {QStringLiteral("systemsettings"), QStringLiteral("kcm_pulseaudio")}},
            {QStringLiteral("kisayol"), {QStringLiteral("systemsettings"), QStringLiteral("kcm_keys")}},
            {QStringLiteral("bilgi"), {QStringLiteral("kinfocenter")}},
            {QStringLiteral("ayarlar"), {QStringLiteral("systemsettings")}},
        };
        const auto it = komutlar.constFind(id);
        if (it == komutlar.constEnd())
            return false;
        QStringList args = *it;
        const QString program = args.takeFirst();
        return QProcess::startDetached(program, args);
    }
};

int main(int argc, char *argv[])
{
    // Round 45 (D135): Qt Quick's software renderer. This window is static (cards, text, images); with OpenGL it held
    // about 210 MiB RSS on llvmpipe in QEMU (rounds 43/44 idle lists), most of it the GL context. Must be set before the
    // first window exists.
    QQuickWindow::setGraphicsApi(QSGRendererInterface::Software);
    QApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("alpbah-hosgeldin"));
    app.setApplicationDisplayName(QStringLiteral("Hoş Geldin"));
    app.setDesktopFileName(QStringLiteral("alpbah-hosgeldin"));
    if (app.arguments().contains(QStringLiteral("--ilk-acilis"))
        && QProcess::execute(QString::fromLatin1(APPLY_TOOL), {QStringLiteral("ilk-acilis-mi")}) != 0) {
        return 0;
    }
    Backend backend;
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("backend"), &backend);
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app, [] { QCoreApplication::exit(1); },
                     Qt::QueuedConnection);
    const QStringList args = app.arguments();
    static const QStringList tasarimlar = {QStringLiteral("Main"), QStringLiteral("Sihirbaz"), QStringLiteral("Ayna"),
                                           QStringLiteral("Kompakt"), QStringLiteral("Merkez"), QStringLiteral("Vitrin")};
    QString tasarim = QStringLiteral("Main");
    QVariantMap initial{{QStringLiteral("backend"), QVariant::fromValue(static_cast<QObject *>(&backend))}};
    for (int i = 1; i + 1 < args.size(); ++i) {
        if (args.at(i) == QLatin1String("--tasarim") && tasarimlar.contains(args.at(i + 1))) {
            tasarim = args.at(i + 1);
        } else if (args.at(i) == QLatin1String("--ozellik") && args.at(i + 1).contains(QLatin1Char('='))) {
            const QString key = args.at(i + 1).section(QLatin1Char('='), 0, 0);
            const QString value = args.at(i + 1).section(QLatin1Char('='), 1);
            bool isInt = false;
            const int n = value.toInt(&isInt);
            initial.insert(key, isInt ? QVariant(n) : QVariant(value));
        }
    }
    engine.setInitialProperties(initial);
    engine.loadFromModule("AlpbahHosgeldin", tasarim);
    // --ekran-goruntusu <png> (tests and docs): save the window as an image after it is drawn, then quit.
    const int shotArg = app.arguments().indexOf(QStringLiteral("--ekran-goruntusu"));
    if (shotArg > 0 && shotArg + 1 < app.arguments().size() && !engine.rootObjects().isEmpty()) {
        const QString path = app.arguments().at(shotArg + 1);
        auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
        QTimer::singleShot(3000, &app, [window, path] {
            QCoreApplication::exit(window && window->grabWindow().save(path) ? 0 : 3);
        });
    }
    return app.exec();
}

#include "main.moc"
