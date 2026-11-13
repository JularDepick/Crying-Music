"""
从指定路径 P 复制纯净可独立运行的 Release 内容到指定路径 Q。
在下方配置 SOURCE_DIR 和 DEST_DIR，然后运行此脚本。

复制原则: 只复制运行时真正会用到的内容。
- 样式: 程序启动时把 Qt Quick Controls 固定为 Basic, 因此只带 Basic 样式, 其余样式与样式插件一律不带
- 翻译: 程序不安装 QTranslator, translations 目录不带
- 多媒体: 程序强制使用 FFmpeg 后端, 因此不带 Windows 多媒体后端插件
- 图片格式: 界面只用 jpeg 与 svg, 不带 gif 与 ico 插件
- 网络: HTTPS 走系统 schannel 后端, 不带仅处理证书的 certonly 后端; 程序不查询网络状态, 不带 networkinformation
- 已停用的模块: 托盘迁移到 QSystemTrayIcon 之后不再需要 Qt.labs.platform 与 Qt.labs.folderlistmodel
- 工具元数据: 所有 *.qmltypes 属于开发期工具数据, 不带

复制来源为 SOURCE_DIR: windeployqt 部署后的构建输出目录, 提供主程序与 Qt 运行时依赖;
项目自身的许可, 版权, 中英说明, 第三方组件声明与 Qt, FFmpeg 的许可文本从源码目录另行附加。

配置路径以脚本所在目录为基准解析, 可在任意工作目录下运行。
复制结束后会自检构建产物中既未纳入清单, 也不在忽略表里的 DLL 与插件目录, 提示可能漏带的依赖。

本脚本同时被 GitHub Actions 工作流 .github/workflows/release-quick_app.yml 调用,
发布 release 时由它产出上传到 assets 的便携版; 因此 SOURCE_DIR 指向的构建输出目录名
必须与工作流里的构建目录名保持一致, 新增依赖时需要同步补充 COPY_TARGETS。
"""

import shutil
import sys
from pathlib import Path

# ==== 配置区域 ====

# 脚本所在目录: 配置路径均以它为基准, 避免依赖运行时工作目录
SCRIPT_DIR = Path(__file__).resolve().parent

# 源路径: Release 构建输出目录(含主 exe 与已部署的依赖)
SOURCE_DIR = (SCRIPT_DIR / "../build/Desktop_Qt_6_11_1_MinGW_64_bit_Release").resolve()

# 目标路径: 纯净 Release 的输出位置
DEST_DIR = (SCRIPT_DIR / "../release/Crying-Music").resolve()

# 主可执行文件名
MAIN_EXE = "CryingMusic.exe"

# 需要复制的条目(相对于 SOURCE_DIR); 文件写完整文件名, 目录以 / 结尾
COPY_TARGETS: list[str] = [
    # 主程序
    MAIN_EXE,
    MAIN_EXE + ".manifest",

    # MinGW 运行时库(Qt6Core/Qt6Gui 依赖)
    "libgcc_s_seh-1.dll",
    "libstdc++-6.dll",
    "libwinpthread-1.dll",

    # Qt 基础库
    "Qt6Core.dll",
    "Qt6Gui.dll",
    "Qt6Network.dll",
    "Qt6OpenGL.dll",
    "Qt6Qml.dll",
    "Qt6QmlMeta.dll",
    "Qt6QmlModels.dll",
    "Qt6QmlWorkerScript.dll",
    "Qt6Quick.dll",
    "Qt6QuickEffects.dll",
    "Qt6QuickLayouts.dll",
    "Qt6QuickTemplates2.dll",
    "Qt6Svg.dll",
    "Qt6Widgets.dll",

    # Qt Quick Controls: 只带 Basic 样式(程序启动时已固定为该样式)
    "Qt6QuickControls2.dll",
    "Qt6QuickControls2Impl.dll",
    "Qt6QuickControls2Basic.dll",
    "Qt6QuickControls2BasicStyleImpl.dll",

    # Qt Quick Dialogs(本地页的 FileDialog/FolderDialog 依赖)
    "Qt6QuickDialogs2.dll",
    "Qt6QuickDialogs2QuickImpl.dll",
    "Qt6QuickDialogs2Utils.dll",

    # Qt Multimedia 与 FFmpeg 后端(Main.qml 的 MediaPlayer 依赖)
    "Qt6Multimedia.dll",
    "Qt6MultimediaQuick.dll",
    "avcodec-61.dll",
    "avformat-61.dll",
    "avutil-59.dll",
    "swresample-5.dll",
    "swscale-8.dll",

    # 插件逐个列出, 不带整目录: 目录里往往混着用不到的插件
    "platforms/qwindows.dll",
    "styles/qmodernwindowsstyle.dll",
    "multimedia/ffmpegmediaplugin.dll",
    "imageformats/qjpeg.dll",
    "imageformats/qsvg.dll",
    "tls/qschannelbackend.dll",

    # QML 模块: QtQuick 与 Controls 按子目录排除, 其余整树复制
    "qml/QML/",
    "qml/QtQml/",
    "qml/QtMultimedia/",
    "qml/QtQuick/",
    "qml/QtQuick/Controls/",
]

# 目录复制时要跳过的子项: 键为清单里的目录条目(带结尾斜杠), 值为该目录第一层要跳过的名字.
# 排除只作用于被复制的那个目录本身, 因此 Controls 单独列一条时可以再排除它的样式子目录
DIR_EXCLUDES: dict[str, set[str]] = {
    # QtQuick 下只保留界面真正用到的子模块; Controls 单独列为一条, 以便再排除未使用的样式
    "qml/QtQuick/": {"Controls", "NativeStyle", "Particles", "Timeline", "VectorImage",
                     "LocalStorage", "Shapes", "tooling"},
    # 只保留 Basic 与 impl, 其余四种样式与 Windows 原生样式都不带
    "qml/QtQuick/Controls/": {"Fusion", "Imagine", "Material", "Universal", "FluentWinUI3", "Windows"},
    # QtQml 下只用到 Models 与 WorkerScript
    "qml/QtQml/": {"XmlListModel"},
}

# 复制时跳过的文件后缀: *.qmltypes 只服务于开发期工具, 运行期不需要
SKIP_SUFFIXES: set[str] = {".qmltypes"}

# 发布包附加文件: 项目许可, 版权, 文档许可, Qt 许可, FFmpeg 许可, TagLib 双许可, 中英说明与第三方组件声明
# (源路径, 发布包内文件名); 这些文件取自源码目录, 不属于 windeployqt 的构建产物
# 许可四件套 COPYRIGHT, LICENSE, LICENSE.FDL, LICENSE.Qt 与 qml/GlobalFileStorage.qml 的
# licenseFileNames 以及 resource.qrc 内嵌的 licenses/ 别名保持同一口径;
# LICENSE.FFmpeg, LICENSE.TagLib-LGPL, LICENSE.TagLib-MPL 与 THIRD-PARTY-NOTICES.md 只随包分发,
# 供合规查阅, 不嵌入界面; TagLib 的两份全文取自 external/taglib 下的上游原文
EXTRA_SOURCES: list[tuple[Path, str]] = [
    ((SCRIPT_DIR / "../../../LICENSE").resolve(), "LICENSE"),
    ((SCRIPT_DIR / "../../../COPYRIGHT").resolve(), "COPYRIGHT"),
    ((SCRIPT_DIR / "../LICENSE.FDL").resolve(), "LICENSE.FDL"),
    ((SCRIPT_DIR / "../LICENSE.Qt").resolve(), "LICENSE.Qt"),
    ((SCRIPT_DIR / "../LICENSE.FFmpeg").resolve(), "LICENSE.FFmpeg"),
    ((SCRIPT_DIR / "../external/taglib/COPYING.LGPL").resolve(), "LICENSE.TagLib-LGPL"),
    ((SCRIPT_DIR / "../external/taglib/COPYING.MPL").resolve(), "LICENSE.TagLib-MPL"),
    ((SCRIPT_DIR / "../README.md").resolve(), "README.md"),
    ((SCRIPT_DIR / "../README_en-US.md").resolve(), "README_en-US.md"),
    ((SCRIPT_DIR / "../THIRD-PARTY-NOTICES.md").resolve(), "THIRD-PARTY-NOTICES.md"),
]

# 允许在源目录中缺失的清单条目: 其余条目缺失即视为打包失败
OPTIONAL_TARGETS: set[str] = set()

# 构建产物中刻意不分发的条目: 自检时跳过, 并在提示里给出原因
IGNORED_UNCOVERED: dict[str, str] = {
    "translations": "程序不安装 QTranslator, 翻译文件用不到",
    "generic": "TUIO 触摸输入插件, 用不到",
    "iconengines": "QIcon 不加载 svg, 图标由界面组件自己绘制",
    "networkinformation": "程序不查询网络状态",
    "opengl32sw.dll": "Qt 6 在 Windows 默认走 Direct3D, 不启用软件 OpenGL 兜底",
    "Qt6Quick3DUtils.dll": "Qt Quick 3D 未使用",
    "Qt6QuickShapes.dll": "界面未 import QtQuick.Shapes",
    "Qt6LabsPlatform.dll": "托盘已迁移到 QSystemTrayIcon",
    "Qt6LabsFolderListModel.dll": "托盘已迁移到 QSystemTrayIcon",
    "Qt6QuickControls2Fusion.dll": "样式已固定为 Basic",
    "Qt6QuickControls2FusionStyleImpl.dll": "样式已固定为 Basic",
    "Qt6QuickControls2Imagine.dll": "样式已固定为 Basic",
    "Qt6QuickControls2ImagineStyleImpl.dll": "样式已固定为 Basic",
    "Qt6QuickControls2Material.dll": "样式已固定为 Basic",
    "Qt6QuickControls2MaterialStyleImpl.dll": "样式已固定为 Basic",
    "Qt6QuickControls2Universal.dll": "样式已固定为 Basic",
    "Qt6QuickControls2UniversalStyleImpl.dll": "样式已固定为 Basic",
    "Qt6QuickControls2FluentWinUI3StyleImpl.dll": "样式已固定为 Basic",
    "Qt6QuickControls2WindowsStyleImpl.dll": "样式已固定为 Basic",
    "qmltooling": "开发期调试插件, 不分发",
}


# ==== 逻辑 ====

def is_excluded(target: str, name: str) -> bool:
    """按 DIR_EXCLUDES 判断某个子项是否要在被复制目录的第一层跳过。"""
    return name in DIR_EXCLUDES.get(target, set())


def copy_entry(src: Path, dst: Path, name: str) -> tuple[int, bool]:
    """复制单个文件或目录树，返回（复制的文件数量，源条目是否存在）。"""
    src_path = src / name
    dst_path = dst / name

    if not src_path.exists():
        print(f"  [跳过] 未找到: {name}")
        return 0, False

    if src_path.is_file():
        dst_path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src_path, dst_path)
        print(f"  [文件] {name}")
        return 1, True

    if src_path.is_dir():
        base_rel = name.rstrip("/")
        count = 0
        for item in src_path.rglob("*"):
            if not item.is_file():
                continue
            if item.suffix.lower() in SKIP_SUFFIXES:
                continue
            rel = item.relative_to(src)
            # 排除项只作用于被复制目录的第一层: 这里取相对该目录的第一段路径
            rel_to_target = item.relative_to(src_path)
            if is_excluded(name, rel_to_target.parts[0]):
                continue
            target = dst / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(item, target)
            count += 1
        print(f"  [目录] {name} ({count} 个文件)")
        return count, True

    return 0, False


def copy_extras(dst: Path) -> int:
    """复制项目许可, 版权, 中英说明, 第三方组件声明与 Qt, FFmpeg 的许可文本到发布包, 返回复制的文件数量"""
    count = 0
    for src, name in EXTRA_SOURCES:
        if not src.is_file():
            print(f"  [跳过] 未找到: {src}")
            continue
        shutil.copy2(src, dst / name)
        print(f"  [附加] {name}")
        count += 1
    return count


def check_uncovered(src: Path, covered: set[str]) -> int:
    """自检构建产物中既未纳入清单也不在忽略表里的 DLL 与插件目录; 返回未覆盖项数量。"""
    uncovered: list[str] = []
    for item in sorted(src.iterdir()):
        name = item.name
        if name in covered or name in IGNORED_UNCOVERED:
            continue
        if item.is_dir():
            # 目录只要有一条子项被清单覆盖就算已覆盖
            if any(entry.startswith(name + "/") for entry in covered):
                continue
            if any(child.is_file() for child in item.rglob("*.dll")):
                uncovered.append(f"{name}/")
        elif item.suffix.lower() == ".dll":
            uncovered.append(name)

    if not uncovered:
        return 0

    print()
    print("提示: 以下构建产物未纳入复制清单，若为新增依赖请补充 COPY_TARGETS:")
    for name in uncovered:
        print(f"  - {name}")
    return len(uncovered)


def main() -> None:
    if not SOURCE_DIR.is_dir():
        print(f"错误: 源目录不存在:\n  {SOURCE_DIR}")
        sys.exit(1)

    if not (SOURCE_DIR / MAIN_EXE).is_file():
        print(f"错误: 源目录缺少主程序，请先构建 Release:\n  {SOURCE_DIR / MAIN_EXE}")
        sys.exit(1)

    print(f"源路径:    {SOURCE_DIR}")
    print(f"目标路径:  {DEST_DIR}")
    print(f"共 {len(COPY_TARGETS)} 个复制目标，{len(EXTRA_SOURCES)} 个附加文件")
    print()

    # 如果目标目录已存在则先清空
    if DEST_DIR.exists():
        print("正在清理已有目标目录...")
        shutil.rmtree(DEST_DIR)
    DEST_DIR.mkdir(parents=True)

    total = 0
    skipped: list[str] = []
    for name in COPY_TARGETS:
        count, found = copy_entry(SOURCE_DIR, DEST_DIR, name)
        total += count
        if not found:
            skipped.append(name)

    total += copy_extras(DEST_DIR)

    print()
    missing = [name for name in skipped if name not in OPTIONAL_TARGETS]
    if missing:
        print(f"错误: {len(missing)} 个必需条目在源目录中不存在: {', '.join(missing)}")
    uncovered = check_uncovered(SOURCE_DIR, {name.rstrip("/") for name in COPY_TARGETS})

    print()
    if missing or uncovered > 0:
        print(f"自检未通过: 必需条目缺 {len(missing)} 个, 未覆盖的产物 {uncovered} 项")
        sys.exit(1)
    print(f"完成。共复制 {total} 个文件到 {DEST_DIR}")


if __name__ == "__main__":
    main()
