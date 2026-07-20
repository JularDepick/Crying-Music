# 开发教程

本项目是一个 **Qt Quick Application**（Qt 6 + QML + C++），使用 CMake 构建，目标平台为 Windows（MinGW）。

## 环境准备

| 工具 | 版本 | 说明 |
|:---:|:---:|:---|
| Qt | 6.11.1 | 需安装 Quick、Multimedia 模块 |
| 编译器 | MinGW 64-bit | Qt 安装器自带 |
| CMake | >= 3.16 | Qt Creator 内置或独立安装 |
| IDE | Qt Creator | 推荐，自动识别 Qt Kit |

在 Qt Creator 中打开 `CMakeLists.txt` 即可加载项目。选择 Kit：`Desktop Qt 6.11.1 MinGW 64-bit`。

## 构建与运行

```bash
# 命令行方式（需已 source Qt 环境变量）
cmake -B build -G "MinGW Makefiles" -DCMAKE_BUILD_TYPE=Release
cmake --build build
```

也可直接在 Qt Creator 中按 **Ctrl+R** 构建运行。构建产物在 `build/` 目录下，构建后会自动调用 `windeployqt6` 复制依赖 DLL。

## 目录结构

```
quick_app/
├── CMakeLists.txt      # 构建配置 — 唯一的构建入口
├── defines.hpp         # 全局宏定义（VERSION 等），作为预编译头
├── main.cpp            # C++ 入口：创建 QApplication + QML 引擎
├── Main.qml            # QML 界面入口（嵌入 Qt 资源系统）
├── core/               # 业务逻辑目录（C++ 代码放这里）
├── resource.rc         # Windows 资源文件（图标等）
├── favicon.jpg         # 应用图标素材
├── icon.ico            # Windows 可执行文件图标
└── build/              # 构建输出（勿手动编辑）
```

## 如何添加业务代码

### 1. 添加 C++ 业务逻辑

所有业务代码放在 `core/` 目录下。CMake 已配置自动扫描：

```cmake
file(GLOB_RECURSE CORE_SOURCES "core/*.cpp" "core/*.h")
```

你只需要在 `core/` 下新建 `.cpp` 和 `.h` 文件，重新构建即可，**无需修改 CMakeLists.txt**。

示例：添加一个音乐管理类

```
core/
├── music_manager.h
└── music_manager.cpp
```

`music_manager.h`:

```cpp
#pragma once
#include <QObject>
#include <QString>

class MusicManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString currentTrack READ currentTrack NOTIFY currentTrackChanged)

public:
    explicit MusicManager(QObject *parent = nullptr);

    QString currentTrack() const;

    Q_INVOKABLE void play(const QString &filePath);

signals:
    void currentTrackChanged();

private:
    QString m_currentTrack;
};
```

`music_manager.cpp`:

```cpp
#include "music_manager.h"

MusicManager::MusicManager(QObject *parent) : QObject(parent) {}

QString MusicManager::currentTrack() const { return m_currentTrack; }

void MusicManager::play(const QString &filePath) {
    m_currentTrack = filePath;
    emit currentTrackChanged();
}
```

### 2. 在 main.cpp 中注册 C++ 类到 QML

要让 QML 能访问 C++ 对象，需在 `main.cpp` 中注册。有三种方式：

**方式 A：注册为 QML 单例（推荐）**

```cpp
// main.cpp 中，engine.load() 之前
#include "core/music_manager.h"

qmlRegisterSingletonType<MusicManager>(
    "App.Core", 1, 0, "MusicManager",
    [](QQmlEngine *, QJSEngine *) -> QObject * {
        return new MusicManager;
    });
```

QML 中使用：

```qml
import App.Core 1.0

MusicManager.currentTrack  // 读属性
MusicManager.play("xxx")   // 调方法
```

**方式 B：注册为 QML 类型（可动态创建实例）**

```cpp
qmlRegisterType<MusicManager>("App.Core", 1, 0, "MusicManager");
```

QML 中使用：

```qml
import App.Core 1.0

MusicManager {
    id: mgr
    onCurrentTrackChanged: console.log("Now playing:", currentTrack)
}
```

**方式 C：设置上下文属性（最简单，适合快速原型）**

```cpp
// main.cpp 中
#include "core/music_manager.h"

MusicManager musicManager;
engine.rootContext()->setContextProperty("musicManager", &musicManager);
```

QML 中直接使用 `musicManager.play(...)`，无需 import。

### 3. 添加 QML 界面文件

在项目根目录新建 `.qml` 文件，然后在 CMakeLists.txt 中将其添加到资源：

```cmake
qt_add_resources(appCryingMusic "qml_resources"
    PREFIX "/"
    FILES Main.qml MusicPlayer.qml  # 加上新文件
)
```

QML 中用 `import` 引入：

```qml
// Main.qml 中
MusicPlayer {
    anchors.fill: parent
}
```

### 4. 添加第三方库

在 CMakeLists.txt 中添加：

```cmake
find_package(SomeLib REQUIRED)
target_link_libraries(appCryingMusic PRIVATE Qt6::Quick Qt6::Multimedia SomeLib)
```

头文件路径同理：

```cmake
target_include_directories(appCryingMusic PRIVATE ${CMAKE_SOURCE_DIR}/third_party/include)
```

## 项目架构要点

### C++ 与 QML 的分工

| 层 | 技术 | 职责 |
|:---:|:---:|:---|
| 界面层 | QML (Main.qml) | 布局、动画、用户交互、样式 |
| 业务层 | C++ (core/) | 数据处理、文件操作、音频播放、网络请求等 |
| 桥接 | Q_PROPERTY / Q_INVOKABLE / signal | C++ 暴露接口给 QML 调用 |

**原则**：QML 负责"长什么样"，C++ 负责"做什么"。复杂逻辑写 C++，简单界面交互留在 QML。

### 预编译头 (defines.hpp)

`defines.hpp` 通过 `target_precompile_headers` 被所有 `.cpp` 文件自动包含。全局宏定义（如 `VERSION`）放在这里。新增全局常量/宏也放此处。

### 信号与槽

Qt 的核心通信机制。C++ 中用 `signals:` 定义信号，`slots:` 定义槽函数。QML 中用 `onXxxChanged` 响应信号。

```cpp
// C++ 侧
signals:
    void trackChanged(const QString &name);
```

```qml
// QML 侧
MusicManager.onTrackChanged: function(name) {
    label.text = name
}
```

### Qt Quick Controls Basic

本项目使用 `QtQuick.Controls.Basic` 样式（最轻量的内置样式），不依赖系统主题。自定义样式直接在 QML 中通过 `contentItem` 和 `background` 属性覆盖。

## 常见开发场景速查

| 我想... | 去哪里改 |
|:---|:---|
| 改界面布局/样式 | `Main.qml` 或新建 QML 文件 |
| 加一个 C++ 功能类 | `core/` 目录下新建 .h/.cpp |
| 把 C++ 类暴露给 QML | `main.cpp` 中注册（见上文三种方式） |
| 加第三方库 | `CMakeLists.txt` 中 find_package + target_link_libraries |
| 改应用版本号 | `defines.hpp` 的 `VERSION` 宏 + `CMakeLists.txt` 的 `project(... VERSION ...)` |
| 改应用图标 | 替换 `icon.ico` 和 `favicon.jpg`，`resource.rc` 会引用它们 |
| 加新的 QML 组件文件 | 项目根目录建文件，CMakeLists.txt 的 `qt_add_resources` 中注册 |
