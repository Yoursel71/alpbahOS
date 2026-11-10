// alpbahOS Hoş Geldin (WELCOME-01, D121): Qt 6 QML window; the settings logic lives in alpbah-hosgeldin-uygula.
// --ilk-acilis (XDG autostart): exits at once unless "alpbah-hosgeldin-uygula ilk-acilis-mi" says this is the first
// login of an installed user (no marker, not the live session).
#include <QApplication>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QTimer>
#include <QVariantMap>

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
};

int main(int argc, char *argv[])
{
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
    engine.loadFromModule("AlpbahHosgeldin", "Main");
    // --ekran-goruntusu <png> (tests and docs): save the window as an image after it is drawn, then quit.
    const int shotArg = app.arguments().indexOf(QStringLiteral("--ekran-goruntusu"));
    if (shotArg > 0 && shotArg + 1 < app.arguments().size() && !engine.rootObjects().isEmpty()) {
        const QString path = app.arguments().at(shotArg + 1);
        auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
        QTimer::singleShot(1500, &app, [window, path] {
            QCoreApplication::exit(window && window->grabWindow().save(path) ? 0 : 3);
        });
    }
    return app.exec();
}

#include "main.moc"
