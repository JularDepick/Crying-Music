"""
从指定路径 P 复制纯净可独立运行的 Release 内容到指定路径 Q。
在下方配置 SOURCE_DIR 和 DEST_DIR，然后运行此脚本。

复制来源为 SOURCE_DIR：windeployqt 部署后的构建输出目录，提供主程序与 Qt 运行时依赖；
项目自身的许可、版权、说明与 Qt 许可文本从源码目录另行附加。

配置路径以脚本所在目录为基准解析，可在任意工作目录下运行。
复制结束后会自检构建产物中未纳入清单的 DLL 与插件目录，提示可能漏带的依赖。

本脚本同时被 GitHub Actions 工作流 .github/workflows/release-quick_app.yml 调用，
发布 release 时由它产出上传到 assets 的便携版；因此 SOURCE_DIR 指向的构建输出目录名
必须与工作流里的构建目录名保持一致，新增依赖时需要同步补充 COPY_TARGETS。
"""

import shutil
import sys
from pathlib import Path

# ==== 配置区域 ====

# 脚本所在目录：配置路径均以它为基准，避免依赖运行时工作目录
SCRIPT_DIR = Path(__file__).resolve().parent

# 源路径：Release 构建输出目录（含主 exe 与已部署的依赖）
SOURCE_DIR = (SCRIPT_DIR / "../build/Desktop_Qt_6_11_1_MinGW_64_bit_Release").resolve()

# 目标路径：纯净 Release 的输出位置
DEST_DIR = (SCRIPT_DIR / "../release/Crying-Music").resolve()

# 主可执行文件名
MAIN_EXE = "CryingMusic.exe"

# 需要复制的文件和目录列表（相对于 SOURCE_DIR）
# 清单按 windeployqt 实际产物逐项核对，覆盖 Qt Quick 与 Qt Multimedia 及其插件依赖
COPY_TARGETS: list[str] = [
    # 主程序
    MAIN_EXE,
    MAIN_EXE + ".manifest",

    # MinGW 运行时库（Qt6Core/Qt6Gui 依赖）
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
    "Qt6QuickShapes.dll",
    "Qt6QuickTemplates2.dll",
    "Qt6Svg.dll",
    "Qt6Widgets.dll",

    # Qt Quick Dialogs（本地页的 FileDialog/FolderDialog 依赖）
    "Qt6QuickDialogs2.dll",
    "Qt6QuickDialogs2QuickImpl.dll",
    "Qt6QuickDialogs2Utils.dll",

    # QML 平台模块（qml/Qt/labs/platform 与 folderlistmodel 插件依赖）
    "Qt6LabsPlatform.dll",
    "Qt6LabsFolderListModel.dll",

    # Qt Quick Controls 2：样式由 qml/QtQuick/Controls/<样式> 内插件按需加载
    "Qt6QuickControls2.dll",
    "Qt6QuickControls2Impl.dll",
    "Qt6QuickControls2Basic.dll",
    "Qt6QuickControls2BasicStyleImpl.dll",
    "Qt6QuickControls2FluentWinUI3StyleImpl.dll",
    "Qt6QuickControls2Fusion.dll",
    "Qt6QuickControls2FusionStyleImpl.dll",
    "Qt6QuickControls2Imagine.dll",
    "Qt6QuickControls2ImagineStyleImpl.dll",
    "Qt6QuickControls2Material.dll",
    "Qt6QuickControls2MaterialStyleImpl.dll",
    "Qt6QuickControls2Universal.dll",
    "Qt6QuickControls2UniversalStyleImpl.dll",
    "Qt6QuickControls2WindowsStyleImpl.dll",

    # Qt Multimedia 与 FFmpeg 后端（Main.qml 的 MediaPlayer 依赖）
    "Qt6Multimedia.dll",
    "Qt6MultimediaQuick.dll",
    "avcodec-61.dll",
    "avformat-61.dll",
    "avutil-59.dll",
    "swresample-5.dll",
    "swscale-8.dll",

    # 平台与插件目录
    "platforms/",
    "multimedia/",
    "generic/",
    "iconengines/",
    "imageformats/",
    "styles/",
    "tls/",
    "networkinformation/",
    "translations/",

    # QML 模块（整个目录树）
    "qml/",

    # 可选：OpenGL 软件渲染器（无显卡驱动的机器需要）
    "opengl32sw.dll",
]

# 发布包附加文件：项目许可、版权、说明与 Qt 许可文本（源路径, 发布包内文件名）
# 这些文件取自源码目录，不属于 windeployqt 的构建产物
EXTRA_SOURCES: list[tuple[Path, str]] = [
    ((SCRIPT_DIR / "../../../LICENSE").resolve(), "LICENSE"),
    ((SCRIPT_DIR / "../../../COPYRIGHT").resolve(), "COPYRIGHT"),
    ((SCRIPT_DIR / "../README.md").resolve(), "README.md"),
    ((SCRIPT_DIR / "../LICENSE.Qt").resolve(), "LICENSE.Qt"),
]

# 构建产物中属于开发用途或刻意不分发的条目，自检时跳过
IGNORED_UNCOVERED = {"qmltooling", "Qt6Quick3DUtils.dll"}


# ==== 逻辑 ====

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
        count = 0
        for item in src_path.rglob("*"):
            if item.is_file():
                rel = item.relative_to(src)
                target = dst / rel
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(item, target)
                count += 1
        print(f"  [目录] {name}/ ({count} 个文件)")
        return count, True

    return 0, False


def copy_extras(dst: Path) -> int:
    """复制项目许可、版权、说明与 Qt 许可文本到发布包，返回复制的文件数量。"""
    count = 0
    for src, name in EXTRA_SOURCES:
        if not src.is_file():
            print(f"  [跳过] 未找到: {src}")
            continue
        shutil.copy2(src, dst / name)
        print(f"  [许可] {name}")
        count += 1
    return count


def check_uncovered(src: Path, covered: set[str]) -> None:
    """自检构建产物中未纳入清单的 DLL 与插件目录，提示可能漏带的依赖。"""
    uncovered: list[str] = []
    for item in sorted(src.iterdir()):
        if item.name in covered or item.name in IGNORED_UNCOVERED:
            continue
        if item.is_dir():
            if any(child.is_file() for child in item.rglob("*.dll")):
                uncovered.append(f"{item.name}/")
        elif item.suffix.lower() == ".dll":
            uncovered.append(item.name)

    if not uncovered:
        return

    print()
    print("提示: 以下构建产物未纳入复制清单，若为新增依赖请补充 COPY_TARGETS:")
    for name in uncovered:
        print(f"  - {name}")


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
    if skipped:
        print(f"注意: {len(skipped)} 个清单条目在源目录中不存在: {', '.join(skipped)}")
    check_uncovered(SOURCE_DIR, {name.rstrip("/") for name in COPY_TARGETS})

    print()
    print(f"完成。共复制 {total} 个文件到 {DEST_DIR}")


if __name__ == "__main__":
    main()
