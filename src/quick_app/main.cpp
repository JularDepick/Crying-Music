#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QUrl>
#include <qqml.h>
#ifdef Q_OS_WIN
#include <windows.h>
#endif
#include <cstdio>

/* #include "./components/AppPathHelper.hpp" */
#include "./components/AppDebugHelper.hpp"
#include "./components/AppFileHelper.hpp"
#include "./components/AppNetHelper.hpp"
#include "./components/AppClickHelper.hpp"
#include "./components/AppSearchHelper.hpp"
#include "./components/AppSongFileHelper.hpp"
#include "./components/SystemTrayHelper.hpp"

/* using namespace std; */

/* 命令行里是否出现某个开关: 只做逐项比对, 不引入额外的解析器 */
static bool hasCommandLineFlag(int argc, char *argv[], const char *flag)
{
    for (int i = 1; i < argc; ++i) {
        if (qstrcmp(argv[i], flag) == 0) {
            return true;
        }
    }
    return false;
}

int main(int argc, char *argv[])
{
    /* 命令行开关: --debug 打开调试输出.
     * 程序是 GUI 子系统, 默认没有控制台; 因此先把标准输出接到父控制台,
     * 再放开 Qt 的控制台输出判定, 这样在 cmd 里运行 CryingMusic.exe --debug 就能直接看到输出.
     * 不带该开关时全部调试轨迹短路, 可恢复异常的告警与致命错误照常输出 */
    const bool debugMode = hasCommandLineFlag(argc, argv, "--debug");
    AppDebug::setEnabled(debugMode);
    if (debugMode) {
        qputenv("QT_ASSUME_STDERR_HAS_CONSOLE", "1");
#ifdef Q_OS_WIN
        if (AttachConsole(ATTACH_PARENT_PROCESS) != 0) {
            std::freopen("CONOUT$", "w", stdout);
            std::freopen("CONOUT$", "w", stderr);
        }
#endif
        qInfo().noquote() << QStringLiteral("[调试] 命令行带 --debug, 调试输出已开启");
    }
    /* 媒体后端与编解码器: 必须在构造应用之前设置。
     * QT_MEDIA_BACKEND 强制使用 FFmpeg 后端, 避免回退到系统原生后端;
     * QT_ENABLE_EXPERIMENTAL_CODECS 启用 Vorbis 与 Opus 等实验性编解码器, 以便播放 .ogg。 */
    qputenv("QT_MEDIA_BACKEND", "ffmpeg");
    qputenv("QT_ENABLE_EXPERIMENTAL_CODECS", "1");
    /* 创建GUI应用并接收命令行参数:
     * 托盘改用 QtWidgets 的 QSystemTrayIcon, 因此基类取 QApplication 而不是 QGuiApplication */
    QApplication app(argc, argv);
    /* 固定 Qt Quick Controls 的样式为 Basic: 界面全部按 Basic 设计, 固定后发布包只需要带 Basic 一份样式,
     * 不必把 Fusion/Imagine/Material/Universal/FluentWinUI3 一并打进包里.
     * 用环境变量而不是 QQuickStyle, 免得为这一行额外链接 QuickControls2 模块 */
    qputenv("QT_QUICK_CONTROLS_STYLE", "Basic");
    /* 设置GUI应用版本号 */
    QApplication::setApplicationVersion(VERSION);
    QCoreApplication::setOrganizationName(ORG_NAME);
    QCoreApplication::setOrganizationDomain(ORG_DOMAIN);
    QCoreApplication::setApplicationName(APP_NAME);
    /* 注册AppHelpers实例 */
    /* AppPathHelper _aph_; */
    AppFileHelper _afh_;
    AppNetHelper _anh_;
    AppClickHelper _ach_;
    AppSearchHelper _ash_;
    AppSongFileHelper _asfh_;
    SystemTrayHelper _sth_;
    AppDebugHelper _adbg_;
    /* qmlRegisterSingletonInstance("AppHelper",1,0,"AppPathHelper",&_aph_); */
    qmlRegisterSingletonInstance("AppHelper",1,0,"AppFileHelper",&_afh_);
    qmlRegisterSingletonInstance("AppHelper",1,0,"AppNetHelper",&_anh_);
    qmlRegisterSingletonInstance("AppHelper",1,0,"AppClickHelper",&_ach_);
    qmlRegisterSingletonInstance("AppHelper",1,0,"AppSearchHelper",&_ash_);
    qmlRegisterSingletonInstance("AppHelper",1,0,"AppSongFileHelper",&_asfh_);
    qmlRegisterSingletonInstance("AppHelper",1,0,"SystemTray",&_sth_);
    qmlRegisterSingletonInstance("AppHelper",1,0,"AppDebug",&_adbg_);
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
    return app.exec();
}
