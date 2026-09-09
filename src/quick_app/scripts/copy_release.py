"""
从指定路径 P 复制纯净可独立运行的 Release 内容到指定路径 Q。
在下方配置 SOURCE_DIR 和 DEST_DIR，然后运行此脚本。
"""

import shutil
import sys
from pathlib import Path

# ==== 配置区域 ====

# 源路径：Release 构建输出目录（包含主 exe）
SOURCE_DIR = Path("../build/Desktop_Qt_6_11_1_MinGW_64_bit_Release")

# 目标路径：纯净 Release 的输出位置
DEST_DIR = Path("../release/Crying-Music")

# 主可执行文件名
MAIN_EXE = "appCryingMusic.exe"

# 需要复制的文件和目录列表（相对于 SOURCE_DIR）
# 此列表定义了 Qt6 MinGW 独立运行所需的最小集合。
COPY_TARGETS: list[str] = [
    # 主程序
    MAIN_EXE,
    MAIN_EXE + ".manifest",

    # MinGW 运行时库
    "libgcc_s_seh-1.dll",
    "libstdc++-6.dll",
    "libwinpthread-1.dll",

    # Qt 核心库
    "Qt6Core.dll",
    "Qt6Gui.dll",
    "Qt6LabsPlatform.dll",
    "Qt6Network.dll",
    "Qt6OpenGL.dll",
    "Qt6Qml.dll",
    "Qt6QmlMeta.dll",
    "Qt6QmlModels.dll",
    "Qt6QmlWorkerScript.dll",
    "Qt6Quick.dll",
    "Qt6Quick3DUtils.dll",
    "Qt6QuickControls2.dll",
    "Qt6QuickControls2Basic.dll",
    "Qt6QuickControls2BasicStyleImpl.dll",
    "Qt6QuickControls2Impl.dll",
    "Qt6QuickLayouts.dll",
    "Qt6QuickShapes.dll",
    "Qt6QuickTemplates2.dll",
    "Qt6Svg.dll",
    "Qt6Widgets.dll",

    # 平台插件
    "platforms/",

    # QML 模块（整个目录树）
    "qml/",

    # 其他插件目录
    "generic/",
    "iconengines/",
    "imageformats/",
    "styles/",
    "tls/",
    "networkinformation/",
    "translations/",

    # 可选：OpenGL 软件渲染器（无显卡驱动的机器需要）
    "opengl32sw.dll",
]


# ==== 逻辑 ====

def copy_entry(src: Path, dst: Path, name: str) -> int:
    """复制单个文件或目录树，返回复制的文件数量。"""
    src_path = src / name
    dst_path = dst / name

    if not src_path.exists():
        print(f"  [跳过] 未找到: {name}")
        return 0

    if src_path.is_file():
        dst_path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src_path, dst_path)
        print(f"  [文件] {name}")
        return 1

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
        return count

    return 0


def main() -> None:
    if not SOURCE_DIR.is_dir():
        print(f"错误: 源目录不存在:\n  {SOURCE_DIR}")
        sys.exit(1)

    print(f"源路径:    {SOURCE_DIR}")
    print(f"目标路径:  {DEST_DIR}")
    print(f"共 {len(COPY_TARGETS)} 个复制目标")
    print()

    # 如果目标目录已存在则先清空
    if DEST_DIR.exists():
        print("正在清理已有目标目录...")
        shutil.rmtree(DEST_DIR)
    DEST_DIR.mkdir(parents=True)

    total = 0
    for name in COPY_TARGETS:
        total += copy_entry(SOURCE_DIR, DEST_DIR, name)

    print()
    print(f"完成。共复制 {total} 个文件到 {DEST_DIR}")


if __name__ == "__main__":
    main()
