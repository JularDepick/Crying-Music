#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QUrl>
#include <qqml.h>

/* #include "./components/AppPathHelper.hpp" */
#include "./components/AppFileHelper.hpp"
#include "./components/AppClickHelper.hpp"

/* using namespace std; */

int main(int argc, char *argv[])
{
    /* 媒体后端与编解码器: 必须在构造应用之前设置。
     * QT_MEDIA_BACKEND 强制使用 FFmpeg 后端, 避免回退到系统原生后端;
     * QT_ENABLE_EXPERIMENTAL_CODECS 启用 Vorbis 与 Opus 等实验性编解码器, 以便播放 .ogg。 */
    qputenv("QT_MEDIA_BACKEND", "ffmpeg");
    qputenv("QT_ENABLE_EXPERIMENTAL_CODECS", "1");
    /* 创建GUI应用并接收命令行参数 */
    QGuiApplication app(argc, argv);
    /* 设置GUI应用版本号 */
    QGuiApplication::setApplicationVersion(VERSION);
    QCoreApplication::setOrganizationName(ORG_NAME);
    QCoreApplication::setOrganizationDomain(ORG_DOMAIN);
    QCoreApplication::setApplicationName(APP_NAME);
    /* 注册AppHelpers实例 */
    /* AppPathHelper _aph_; */
    AppFileHelper _afh_;
    AppClickHelper _ach_;
    /* qmlRegisterSingletonInstance("AppHelper",1,0,"AppPathHelper",&_aph_); */
    qmlRegisterSingletonInstance("AppHelper",1,0,"AppFileHelper",&_afh_);
    qmlRegisterSingletonInstance("AppHelper",1,0,"AppClickHelper",&_ach_);
    /* 创建QML引擎 */
    QQmlApplicationEngine engine;
    /* 当QML引擎创建失败时自动退出应用 */
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    /* 加载根QML文件 */
    engine.load(QStringLiteral("qrc:/Main.qml"));
    if (!engine.rootObjects().isEmpty()) {
        _ach_.attach(engine.rootObjects().constFirst());
    }
    /* 进入应用消息循环 */
    return QGuiApplication::exec();
}
