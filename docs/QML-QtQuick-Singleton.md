# QML QtQuick 单例注册通用经验

本文档提炼将 QML 文件注册为单例类型的通用经验,适用 Qt 6 与 CMake 构建体系,内容不绑定具体项目,可直接复用到其他工程

---

## 一、机制总览

QML 单例指每个 QML 引擎维度最多创建一次的类型实例,生命周期与引擎一致。注册链路由三个条件协同构成,缺一不可

| 注册条件 | 所在位置 | 作用 |
|:---:|:---:|:---:|
| `pragma Singleton` | QML 文件首行 | 源文件声明自身为单例类型 |
| `QT_QML_SINGLETON_TYPE TRUE` 文件属性 | CMakeLists.txt(`qt_add_qml_module` 体系) | 使构建工具在生成的 qmldir 中写入 singleton 条目 |
| `singleton` 前缀条目 | qmldir | 运行时引擎识别该类型为单例的依据 |

单例注册可完全由 QML 源文件声明与构建期配置完成,不依赖 C++ 注册代码。全局共享的常量配置、分组相关数据等状态适合以单例承载,相比上下文属性具备类型信息,可被 QML Language Server 等工具识别

---

## 二、注册方式

### 1. QML 源文件声明

单例文件首行

```qml
pragma Singleton
import QtQuick

Item {
    property int spacing: 8;
    property color brandColor: "#336699";
    property bool expanded: true;
}
```

要点:
- `pragma Singleton` 必须位于文件第一行,其后才能写 import 语句与类型定义
- 根元素可为任意 QtQuick 类型,常用 `Item` 作为纯数据容器,`visible` 设为 false 可避免参与渲染
- 全部数据以 `property` 声明,使用处按名访问即可,读与写与普通对象一致

### 2. CMake 构建期注册(推荐)

适用于 `qt_add_qml_module` 自动化构建

```cmake
set(ALL_QML_FILES
    Main.qml
    GlobalConfig.qml
    components/MyItem.qml
)

# 标记单例,必须位于 qt_add_qml_module 之前
set_source_files_properties(GlobalConfig.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_qml_module(myapp
    URI MyModule
    VERSION 1.0
    QML_FILES ${ALL_QML_FILES}
)
```

要点:
- `QT_QML_SINGLETON_TYPE` 为文件属性,官方要求先设置属性,再调用 `qt_add_qml_module`,顺序颠倒会导致注册失效
- `URI` 定义模块名,单例文件与普通类型文件同属该模块
- `QML_FILES` 可批量传入文件,多个单例可集中设置属性,例如 `set_source_files_properties(A.qml B.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)`
- 资源前缀与资源路径布局决定嵌入式资源的 qrc URL,应保证加载入口 URL 与之一致
- `QML_FILES` 使用 GLOB 收集时,新增单例文件会被自动纳入构建,但 GLOB 仅收集文件列表,单例属性仍需对新文件显式设置

### 3. 手动 qmldir 注册(不依赖 `qt_add_qml_module`)

不使用 `qt_add_qml_module` 时,需在模块目录手动维护 qmldir

```
module MyModule
singleton GlobalConfig 1.0 GlobalConfig.qml
MyItem 1.0 MyItem.qml
```

注册落地点即 qmldir 中的 `singleton` 前缀条目,两条构建路线的产物形式一致。单例也可与 C++ 插件类型混合声明于同一 qmldir

### 4. 验证方法

构建后检查生成的 qmldir,应出现如下行,该行存在即注册成功,可作为可复现的验收手段

```
singleton GlobalConfig 1.0 GlobalConfig.qml
```

---

## 三、使用方式

模块导入后按名访问

```qml
import MyModule

Item {
    width: GlobalConfig.spacing;
    color: GlobalConfig.brandColor;
}
```

- 目录导入:以 `import "path/"` 或 `import "./"` 导入相对目录后同样按名访问,实际工程中建议与模块级注册配合使用,以保证单例身份的确定性
- 单例属性可读可写,跨文件全局共享,多处修改时需注意状态一致性
- 单例按引擎维度创建,多个 QQmlEngine 各自持有独立实例,互不共享

---

## 四、常见遗漏与注意事项

- 仅有 `pragma Singleton` 而缺少注册条目时,构建产物 qmldir 中该类型仍为普通条目,不构成单例,此为最常见遗漏,务必以生成的 qmldir 的 `singleton` 行作为验收
- 设置属性与调用 `qt_add_qml_module` 的顺序颠倒会导致注册失效
- 单例属性不能直接安装属性绑定,若需绑定请改用 `Binding` 元素,且多个文件同时绑定的结果未定义
- 单例生命周期与引擎一致,引擎销毁时释放
- 单模块内的单例数量宜克制,单例属于全局状态,过多会增加耦合与共享状态风险

---

## 五、其他注册途径(C++ 侧)

- Qt 6 推荐 `QML_SINGLETON` 与 `QML_ELEMENT` 宏组合,声明式注册 C++ 类为单例。非默认可构造类另需 `QML_NAMED_ELEMENT` 与静态 `create(QQmlEngine*, QJSEngine*)` 函数
- 旧式命令式 API 为 `qmlRegisterSingletonType` 与 `qmlRegisterSingletonInstance`,在 Qt 6 中作为备选,存在类型信息缺失、工具不友好的问题
- C++ 侧注册与 QML 声明式注册按需二选一,不必混用

---

## 六、参考

- Qt 官方文档 QML 单例指南,https://doc.qt.io/qt-6.8/zh/qml-singleton.html
- Qt 官方文档 qmldir 模块说明,https://doc.qt.io/qt-6/qtqml-modules-qmldir.html
- Qt 官方文档 QML 目录导入,https://doc.qt.io/qt-6/qtqml-syntax-imports.html