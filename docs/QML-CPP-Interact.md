# QML-CPP通信

Qt 6 提供了强大而灵活的机制，实现 C++ 对象与 QML 界面之间的双向通信与数据交换。本文档以手册形式，系统性地介绍 C++ → QML、QML → C++ 的全部通信方式、数据类型转换、高级集成技巧以及最佳实践。

---

## 一、C++ 端 → QML 端通信

### 1. 上下文属性（`setContextProperty`）

**作用**  
将 `QObject*` 或任意值注入 QML 的全局上下文，使其在任何 QML 文件中像内置变量一样直接使用。

**使用步骤**
```cpp
QQmlApplicationEngine engine;
Backend backend;
engine.rootContext()->setContextProperty("backend", &backend);
```
或者在 Qt 6 中推荐使用 `qmlRegisterSingletonInstance` 替代，但在简单场景中上下文属性依然可用。

**生命周期**  
避免传递栈对象！一旦栈对象析构，QML 端引用将悬空。应使用 `new` 分配对象并设置父对象，或使用 `QSharedPointer` 管理。

```cpp
// 推荐方式：使用 QObject 父对象管理
Backend *backend = new Backend(&engine);
engine.rootContext()->setContextProperty("backend", backend);
```

**上下文层次**  
`rootContext()` 是根上下文，所有 QML 组件都能访问其中的属性。如果创建子 `QQmlContext`（例如用于不同窗口或组件），子上下文可访问父上下文属性，但父上下文不可见子上下文的新增属性。这提供了隔离机制。

**示例：暴露 Backend 对象**
```cpp
class Backend : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString userName READ userName WRITE setUserName NOTIFY userNameChanged)
public:
    Backend(QObject *parent = nullptr) : QObject(parent) {}
    QString userName() const { return m_userName; }
    void setUserName(const QString &name) {
        if (m_userName != name) {
            m_userName = name;
            emit userNameChanged();
        }
    }
signals:
    void dataUpdated(int count);
public slots:
    void refresh() { /* ... */ }
private:
    QString m_userName;
};
```
QML 中使用：
```qml
Text { text: backend.userName }
Button { onClicked: backend.refresh() }
Connections {
    target: backend
    onDataUpdated: (count) => console.log("Count:", count)
}
```

**示例：暴露基本类型**
```cpp
engine.rootContext()->setContextProperty("appVersion", "2.1.0");
engine.rootContext()->setContextProperty("maxRetryCount", 3);
engine.rootContext()->setContextProperty("themeColor", QColor("lightblue"));
```

**注意事项**
- 命名冲突：避免使用 `window`、`parent`、`model` 等 QML 内置属性名。
- 对象所有权：QML 不会自动销毁由 C++ 创建且未设置父对象的普通对象。建议设置父对象或显式管理。

---

### 2. 注册 QML 类型（`qmlRegisterType` 家族）

**注册可实例化类型**
```cpp
qmlRegisterType<Backend>("com.example.app", 1, 0, "Backend");
```
QML 中即可创建对象：
```qml
import com.example.app 1.0
Backend { id: myBackend }
```

**注册单例类型**  
（1）使用单例工厂函数：
```cpp
qmlRegisterSingletonType<Settings>("com.example.app", 1, 0, "Settings",
    [](QQmlEngine *, QJSEngine *) -> QObject * {
        return Settings::instance();
    });
```
（2）直接注册已有实例（Qt 6 推荐）：
```cpp
qmlRegisterSingletonInstance("com.example.app", 1, 0, "Settings", Settings::instance());
```
QML 中：
```qml
import com.example.app 1.0
Text { text: Settings.appName }
```

**注册不可实例化类型**  
用于暴露枚举或静态方法：
```cpp
qmlRegisterUncreatableType<Enums>("com.example.app", 1, 0, "AppEnums",
    "Cannot create AppEnums object");
```
配合 `Q_ENUM` 可在 QML 中直接使用枚举值。

**其他注册函数（Qt 6）**
- `qmlRegisterAnonymousType`: 注册类型但不导出名称，常用于基类。
- `qmlRegisterModule`: 批量注册同一模块的类型。
- `qmlRegisterNamespace`: 将 C++ 命名空间注册为 QML 命名空间。

**使用 `QML_ELEMENT` 宏简化注册（Qt 6 推荐）**
```cpp
class Backend : public QObject {
    Q_OBJECT
    QML_ELEMENT
    // ...
};
```
配合构建系统自动注册，无需手动调用 `qmlRegisterType`。需在 CMake 中启用：
```cmake
qt_add_qml_module(app
    URI "com.example.app"
    VERSION 1.0
    QML_FILES main.qml
    SOURCES backend.cpp
)
```

**打包为插件**  
通过继承 `QQmlExtensionPlugin` 并编写 `qmldir` 文件，可将类型编译为 QML 插件，方便分发和延迟加载。

**对比：上下文属性 vs. 注册类型**
| 方式               | 适用场景                               |
|--------------------|----------------------------------------|
| 上下文属性         | 少量全局单例，快速原型，无需 import    |
| 注册类型           | 需要实例化多个对象，模块化，类型安全   |

---

### 3. 属性暴露（`Q_PROPERTY`）

**声明可读/可写属性**
```cpp
Q_PROPERTY(QString title READ title WRITE setTitle NOTIFY titleChanged)
```
完整的 READ、WRITE、NOTIFY 信号实现是 QML 属性绑定的基础。

**属性变更信号与 QML 绑定联动**
```qml
Text { text: myObject.title }  // 当 titleChanged 信号发出后自动更新
```

**双向属性绑定**  
结合 QML `Binding` 元素实现 `TextField` ↔ C++ 字符串同步：
```qml
TextField { id: nameField }
Binding {
    target: backend
    property: "userName"
    value: nameField.text
}
```
当用户在 TextField 输入时，`backend.userName` 自动更新；反过来 `backend.userName` 改变也会更新 TextField 显示（需设置 `TextField` 的 `text: backend.userName`，并防止循环更新）。

**防止循环更新**  
在属性的 WRITE 函数中检查新旧值是否相同，避免重复发射信号：
```cpp
void setUserName(const QString &name) {
    if (m_userName != name) {
        m_userName = name;
        emit userNameChanged();
    }
}
```

**只读属性与 `REQUIRED` 属性（Qt 6.2+）**
- 只读属性：只有 READ 和 NOTIFY，没有 WRITE。
- `REQUIRED`：QML 实例化时必须提供初始值。
```cpp
Q_PROPERTY(int id READ id REQUIRED)
```

**动态属性提供者：`QQmlPropertyMap`**  
可以在运行时动态添加属性，无需修改 C++ 类：
```cpp
QQmlPropertyMap map;
map.insert("color", QColor("red"));
engine.rootContext()->setContextProperty("dynamicProps", &map);
```
QML 中绑定 `dynamicProps.color`。

---

### 4. 方法暴露（`Q_INVOKABLE` 与槽函数）

**使用 `Q_INVOKABLE`**
```cpp
class Calculator : public QObject {
    Q_OBJECT
public:
    Q_INVOKABLE int add(int a, int b) { return a + b; }
};
```
QML 调用：
```qml
let result = calculator.add(5, 3);
```

**公共槽**  
公共槽自动可被 QML 调用，但推荐使用 `Q_INVOKABLE` 以区分 UI 调用接口。

**带参数和返回值的方法**  
支持基本类型、QObject*、QVariant 等。返回值为 `void` 或基础类型，异步任务应通过信号返回结果。

**异步调用建议**  
长时间操作不应阻塞 GUI 线程。启动一个任务后，待完成时通过信号通知 QML。
```cpp
Q_INVOKABLE void startLongTask() {
    // 在工作线程执行...
    emit taskFinished(result);
}
```

---

### 5. C++ 发信号 → QML 响应

**C++ 定义信号**
```cpp
signals:
    void progressChanged(float progress);
```

**QML 中 `on<SignalName>` 连接**  
对于上下文属性对象，直接使用：
```qml
onProgressChanged: (progress) => progressBar.value = progress
```
此语法需要信号对象是当前 Item 的直接属性或 id。

**使用 `Connections` 元素（更灵活）**
```qml
Connections {
    target: backend
    onProgressChanged: function(progress) { progressBar.value = progress; }
}
```
可动态改变 `target`，连接任意对象。

**传递复杂参数**  
信号参数可以是注册的类型或 `QVariantList`/`QVariantMap`：
```cpp
signals:
    void dataReceived(QVariantMap data);
```
QML 中：
```qml
onDataReceived: (data) => console.log(data["name"])
```

**示例：定时器信号更新文本**
```cpp
class Clock : public QObject {
    Q_OBJECT
public:
    Clock() {
        QTimer *timer = new QTimer(this);
        connect(timer, &QTimer::timeout, this, [this]() {
            emit timeUpdated(QDateTime::currentDateTime().toString());
        });
        timer->start(1000);
    }
signals:
    void timeUpdated(QString currentTime);
};
```
QML：
```qml
Connections {
    target: clock
    onTimeUpdated: (time) => timeLabel.text = time
}
```

---

### 6. 从 C++ 端访问 QML 对象

**获取根对象**
```cpp
QObject *root = engine.rootObjects().first();
```

**按 objectName 查找**
```cpp
QObject *button = root->findChild<QObject*>("submitButton");
```
确保 QML 中设置了 `objectName: "submitButton"`。

**调用 QML 函数**
```cpp
QMetaObject::invokeMethod(button, "doSomething", Q_ARG(int, 42));
```

**访问 QML 属性**
```cpp
button->setProperty("text", "Clicked");
QString text = button->property("text").toString();
```

**处理生命周期**  
使用 `QPointer` 跟踪 QML 对象，避免访问已销毁对象。也可在对象销毁时通过 `deleteLater` 进行清理。

---

### 7. 暴露对象列表：`QQmlListProperty`

**作用**  
允许 QML 直接操作 C++ 维护的对象列表，例如支持 `ListView` 绑定的同时可在 QML 中 `push`、`pop` 等。

**实现方法**
```cpp
class ItemModel : public QObject {
    Q_OBJECT
    Q_PROPERTY(QQmlListProperty<Item> items READ items)
public:
    QQmlListProperty<Item> items() {
        return QQmlListProperty<Item>(this, m_items);
    }
private:
    QList<Item*> m_items;
};
```
对于更复杂的增删操作，需要提供回调函数（`append`、`count`、`at`、`clear`）。Qt 6 中也常用 `QList<QObject*>` 直接暴露（配合 `Q_PROPERTY` 和类型注册），但 `QQmlListProperty` 仍具有内存控制优势。

**QML 中使用**
```qml
ListView {
    model: itemModel.items
    delegate: Text { text: model.name }
}
Button { onClicked: itemModel.items.push(newItem) }
```

**注意事项**  
需保证线程安全；列表中的对象需设置父对象或手动管理内存。

---

## 二、QML 端 → C++ 端通信

### 1. 访问上下文属性对象

直接在 QML 中通过名称访问 C++ 对象的属性、方法和信号，如前面示例：
```qml
Text { text: backend.userName }
Button { onClicked: backend.refresh() }
```
属性绑定：`property int count: backend.itemCount`，一旦 C++ 的 `itemCountChanged` 信号触发，绑定会自动更新。

### 2. 使用已注册的 C++ 类型

```qml
import MyTypes 1.0
MyClass {
    id: instance
    onSomeEvent: console.log("triggered")
}
Component.onCompleted: instance.doSomething()
```

单例类型：
```qml
Text { text: SingletonType.currentUser }
```

### 3. 使用 `Connections` 元素

显式连接任意 C++ 对象的信号，尤其适合非父子关系的对象：
```qml
Connections {
    target: someExternalObject
    onDataChanged: function(newData) { process(newData) }
}
```
**Qt 6 优化**：信号参数解析更灵活，支持函数参数类型自动推断，并增强了错误提示。

**忽略未知信号**（避免警告）：
```qml
Connections {
    target: backend
    ignoreUnknownSignals: true
}
```

### 4. QML 发信号 → C++ 响应

**QML 中定义信号**
```qml
Rectangle {
    id: root
    signal userClicked(string buttonId)
    MouseArea {
        onClicked: root.userClicked("ok")
    }
}
```

**C++ 端连接**
```cpp
QObject *qmlObject = ...; // 获取 QML 对象
QObject::connect(qmlObject, SIGNAL(userClicked(QString)),
                 &handler, SLOT(onUserClicked(QString)));
```
Qt 6 中推荐使用新式语法：
```cpp
connect(qmlObject, &QQuickItem::userClicked, &handler, &Handler::onUserClicked);
```
若信号定义在 QML 中，无相应的 C++ 类定义，则可使用 `QQmlEngine::connect` 辅助函数（或者使用字符串连接，但新式连接不适用）。对于纯 QML 信号，字符串连接仍常见。

**参数类型限制**  
QML 信号参数仅支持 QML 引擎可转换的类型，基本类型、对象等。

### 5. QML 调用 C++ 方法

直接通过上下文属性或实例调用：
```qml
let result = backend.calculate(42);
```

**`Qt.callLater` 延迟调用**  
用于防抖或合并更新，避免在循环中重复触发昂贵的操作：
```qml
for (let i=0; i<1000; i++) {
    Qt.callLater(backend.appendLog, "line " + i);
}
```
所有调用将在当前事件循环结束后批量执行（仅执行最后一次调用，取决于实现，实际会将多次相同函数调用合并为一次）。需注意参数不可变。

**同步返回值注意**  
若 C++ 方法耗时较长，会阻塞 UI，应改为异步（通过信号返回结果）。

### 6. 在 QML 中操作列表（`QQmlListProperty`）

使用暴露的列表，QML 可调用标准方法：
```qml
myList.push(someObject)
myList.pop()
myList.length
```

---

## 三、数据类型与转换

### 1. Qt 6 支持的数据类型列表

| C++ 类型         | QML 中对应/用法                              |
|------------------|----------------------------------------------|
| `int`            | `int`                                        |
| `bool`           | `bool`                                       |
| `double`/`qreal` | `real`                                       |
| `QString`        | `string`                                     |
| `QUrl`           | `url`                                        |
| `QColor`         | `color`                                      |
| `QDateTime`      | `Date` 对象（通过 `valueOf` 等操作）         |
| `QPoint`/`QSize` 等 | 未直接转换，需使用 `QVariant` 或自定义类型 |
| `QVariantList`   | `var` 数组，如 `[1, "two"]`                  |
| `QVariantMap`    | `var` 对象，如 `{"key": value}`              |
| `QObject*`       | 可访问其属性、方法和信号                     |
| 枚举             | 需注册后作为 `int` 或具名常量使用            |

### 2. 自动转换规则

引擎在 QML 与 C++ 之间自动转换上述标准类型。例如：
- C++ 属性类型 `QString` → QML 中 `string`
- 信号参数 `QColor` → QML 中可作为 `color` 传递给其他属性

需要注意，`QDateTime` 在 QML 中转换为 JavaScript `Date` 对象，精度为毫秒，使用 `.toLocaleString()` 等方法。

### 3. 传递复杂数据结构

**`Q_GADGET`（轻量级数据类）**
```cpp
struct DataPoint {
    Q_GADGET
    Q_PROPERTY(double x MEMBER x)
    Q_PROPERTY(double y MEMBER y)
public:
    double x = 0, y = 0;
};
Q_DECLARE_METATYPE(DataPoint)
```
可将其包装在 `QVariant` 中传递，QML 中作为普通对象访问属性（Qt 6 支持）。注意 `Q_GADGET` 没有信号、槽，不能作为上下文属性对象（不是 QObject），适合纯数据传输。

**`Q_OBJECT` 业务对象**  
功能完整，支持信号槽、属性绑定。推荐用于需要交互逻辑的场景。

**选择指南**
| 特性              | Q_GADGET     | Q_OBJECT        |
|-------------------|--------------|-----------------|
| 属性通知信号      | 无           | 有              |
| 继承 QObject      | 否           | 是              |
| 可在 QML 中创建   | 否           | 注册后可        |
| 适合场景          | 数值/记录传递 | 交互、模型项    |

**动态传递 JSON 数据**
```cpp
Q_INVOKABLE QVariantMap fetchData() {
    QVariantMap map;
    map["name"] = "Alice";
    map["age"] = 30;
    return map;
}
```
QML:
```qml
let data = backend.fetchData();
console.log(data.name, data.age);
```

**图片传递**  
避免直接传递 `QImage`，应使用 `QQuickImageProvider`，它通过 URL 在 QML 端请求图片，性能更好。

### 4. 枚举在 QML 中的使用

**传统方式**
```cpp
class MyEnums : public QObject {
    Q_OBJECT
public:
    enum Status { Idle, Running, Finished };
    Q_ENUM(Status)
};
// 注册不可创建类型
qmlRegisterUncreatableType<MyEnums>("MyEnums", 1, 0, "StatusEnum", "Not creatable");
```
QML：
```qml
import MyEnums 1.0
Component.onCompleted: console.log(StatusEnum.Idle)
```

**Qt 6 自动方式**  
使用 `QML_ELEMENT` 时，`Q_ENUM` 的枚举自动暴露：
```cpp
class Task : public QObject {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(Status status READ status NOTIFY statusChanged)
public:
    enum Status { Idle, Running, Finished };
    Q_ENUM(Status)
    // ...
};
```
QML 中：
```qml
Task { status: Task.Idle }
```

---

## 四、高级主题

### 1. 模型-视图集成

**暴露 `QAbstractListModel` 子类**
```cpp
class TaskModel : public QAbstractListModel {
    Q_OBJECT
public:
    enum Roles { TitleRole = Qt::UserRole + 1, DoneRole };
    QHash<int, QByteArray> roleNames() const override {
        return { {TitleRole, "title"}, {DoneRole, "done"} };
    }
    int rowCount(const QModelIndex &parent = QModelIndex()) const override { return m_tasks.count(); }
    QVariant data(const QModelIndex &index, int role) const override {
        if (!index.isValid()) return {};
        const Task &t = m_tasks.at(index.row());
        switch (role) {
        case TitleRole: return t.title;
        case DoneRole:  return t.done;
        }
        return {};
    }
    void addTask(const Task &task) {
        beginInsertRows(QModelIndex(), m_tasks.size(), m_tasks.size());
        m_tasks.append(task);
        endInsertRows();
    }
private:
    QList<Task> m_tasks;
};
```
注册为上下文属性后，QML：
```qml
ListView {
    model: taskModel
    delegate: Row {
        Text { text: title }
        CheckBox { checked: done }
    }
}
```

**数据变更通知**  
使用 `beginInsertRows`、`endInsertRows`、`dataChanged` 等信号确保视图高效更新。

### 2. 动态对象创建

**C++ 中动态创建 QML 对象**
```cpp
QQmlComponent component(&engine, QUrl("qrc:/DynamicItem.qml"));
QObject *dynamicItem = component.create();
dynamicItem->setParent(root);
// 可进一步设置属性或注入上下文
```

**QML 中动态创建**
```qml
let component = Qt.createComponent("DynamicItem.qml");
let obj = component.createObject(parent, {"x": 100});
```
也可用 `Qt.createQmlObject` 从字符串创建。

### 3. 异步操作

**C++ 耗时任务信号返回结果**  
在工作线程中计算，通过信号将结果传回主线程（连接为 `Qt::QueuedConnection`）。

**使用 `QFuture` 和 `QtConcurrent`**
```cpp
QFuture<int> future = QtConcurrent::run([]() { return heavyCalculation(); });
auto *watcher = new QFutureWatcher<int>(this);
connect(watcher, &QFutureWatcher<int>::finished, this, [watcher, this]() {
    emit calculationDone(watcher->result());
});
watcher->setFuture(future);
```

**`WorkerScript` 限制**  
仅能传递简单 JSON 序列化数据，适合轻量数据处理，不适合传递 QObject。

**轮询**  
使用 `QTimer` 定时触发属性更新或信号。

### 4. 线程模型与安全

QML 引擎运行在主线程，所有对 QML 对象的访问必须在此线程进行。
```cpp
// 子线程中修改 UI 属性错误
// 正确做法：通过信号发送到主线程
QMetaObject::invokeMethod(qmlObject, "updateText", Qt::QueuedConnection,
                          Q_ARG(QString, text));
```
`QMetaObject::invokeMethod` 配合 `Qt::QueuedConnection` 可安全跨线程调用。

### 5. 调试与日志

- **QML 控制台**：`console.log`, `console.warn`, `console.assert`。
- **C++ 端检查上下文**：`engine.rootContext()->contextProperty("name")`。
- **启用警告输出**：默认开启，可通过环境变量 `QT_LOGGING_RULES` 控制。
- **QML Profiler**：分析绑定频率、信号执行时间，定位性能瓶颈。
- **Qt Creator 调试器**：可对 QML/JS 设置断点，单步调试。
- **环境变量调试**：
  - `QML_IMPORT_TRACE=1` 查看模块导入过程。
  - `QQMLDEBUG=1` 开启 QML 调试服务。

### 6. 图形交互与 `QQuickItem` 访问

```cpp
QQuickItem *item = qobject_cast<QQuickItem*>(root->findChild<QObject*>("myRect"));
if (item) {
    qreal x = item->x();
    item->setProperty("width", 200);
    // 坐标映射
    QPointF globalPos = item->mapToScene(QPointF(10, 10));
}
```

**自定义 `QQuickPaintedItem`**  
继承后重写 `paint()` 使用 `QPainter` 绘制，可作为 QML 元素直接嵌入。

**鼠标/触摸事件**  
可在 C++ 侧通过事件过滤器或重写 `QQuickItem::mousePressEvent` 处理。

---

## 五、最佳实践与常见陷阱

### 1. 生命周期管理

- **避免栈对象**作为上下文属性；确保对象寿命覆盖 QML 使用期。
- **注册类型**时，优先设置 `QObject` 父对象或使用智能指针。
- QML 引用的 C++ 对象使用 `QPointer` 监测有效性。
- 使用 `QQmlEngine::setObjectOwnership` 明确 C++ 或 QML 负责销毁（默认 C++ 拥有所有权）。

### 2. 性能优化

- 减少高频属性更新，可合并为一次信号（如批量操作时）。
- 大量数据展示使用 `QAbstractListModel`，而非单独绑定属性。
- 避免在 QML 信号处理函数中执行长时间运行代码。
- 连续 UI 更新（如调整窗口大小）使用 `Qt.callLater` 合并。

### 3. 避免命名冲突与兼容性

- 上下文属性名勿与 QML 内置名称重复（如 `width`、`children`）。
- 使用带版本号的模块导入，实现可控升级。
- 迁移 Qt 5 代码时，注意 `Qt.call` 已弃用，改用 `Qt.callLater`。

### 4. 错误处理

- 调用 `QMetaObject::invokeMethod` 时检查返回值，避免方法不存在导致忽略。
- 严重错误可通过 `QQmlEngine::throwError` 抛给 QML。
- `Connections` 元素设置 `ignoreUnknownSignals: true` 防止拼写错误时的警告泛滥。

**常见错误速查**
| 现象                        | 可能原因                              |
|-----------------------------|---------------------------------------|
| UI 不更新                   | 忘记发射 NOTIFY 信号                  |
| 程序崩溃                   | 上下文对象被过早释放                  |
| QML 行为异常               | 子线程直接修改 QML 对象属性           |
| `Connections` 不工作        | `target` 未设置或信号名称拼写错误     |

---

## 六、附录

### 1. 常用代码模板

**模板 1：Bridge 类**
```cpp
class Bridge : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString text READ text WRITE setText NOTIFY textChanged)
public:
    explicit Bridge(QObject *parent = nullptr) : QObject(parent) {}
    QString text() const { return m_text; }
    void setText(const QString &t) {
        if (t != m_text) { m_text = t; emit textChanged(); }
    }
    Q_INVOKABLE void doAction() { /*...*/ }
signals:
    void textChanged();
    void actionDone();
private:
    QString m_text;
};
```

**模板 2：ListModel 子类**
```cpp
class SimpleListModel : public QAbstractListModel {
    Q_OBJECT
public:
    int rowCount(const QModelIndex &) const override { return m_data.size(); }
    QVariant data(const QModelIndex &index, int role) const override {
        if (role == Qt::DisplayRole) return m_data.at(index.row());
        return {};
    }
    void append(const QString &item) {
        beginInsertRows(QModelIndex(), m_data.size(), m_data.size());
        m_data << item;
        endInsertRows();
    }
private:
    QStringList m_data;
};
```

**模板 3：QML 端 Connections**
```qml
Connections {
    target: backend
    function onProgress(val) { bar.value = val }
}
```

**模板 4：C++ 调用 QML 函数**
```cpp
QObject *qmlObj = engine.rootObjects().first()->findChild<QObject*>("myElement");
QMetaObject::invokeMethod(qmlObj, "playAnimation");
```

**模板 5：Q_GADGET 数据类**
```cpp
struct GeoPoint {
    Q_GADGET
    Q_PROPERTY(double lat MEMBER lat)
    Q_PROPERTY(double lon MEMBER lon)
public:
    double lat = 0, lon = 0;
};
Q_DECLARE_METATYPE(GeoPoint)
```

**模板 6：QQmlPropertyMap**
```cpp
QQmlPropertyMap *map = new QQmlPropertyMap(this);
map->insert("width", 100);
engine.rootContext()->setContextProperty("uiParams", map);
```

**模板 7：QQmlListProperty**
```cpp
Q_PROPERTY(QQmlListProperty<Item> items READ items)
QQmlListProperty<Item> items() {
    return QQmlListProperty<Item>(this, m_items);
}
```

### 2. 类型转换速查表（C++ ↔ QML）

| C++                | QML          | 方向       |
|--------------------|--------------|------------|
| int                | int          | 双向       |
| QString            | string       | 双向       |
| bool               | bool         | 双向       |
| double             | real         | 双向       |
| QColor             | color        | 双向       |
| QUrl               | url          | 双向       |
| QDateTime          | Date         | 双向 (近似)|
| QVariantList       | var []       | 双向       |
| QVariantMap        | var {}       | 双向       |
| QObject*           | QML 对象     | 双向       |
| enum (注册)        | int/具名     | 双向       |

### 3. 常见问题与解答（FAQ）

**Q: 如何在 QML 中直接创建 C++ 对象？**  
A: 使用 `qmlRegisterType` 或 `QML_ELEMENT` 注册后，即可在 QML 中 `MyType {}` 创建。

**Q: 为什么属性更新后 QML 没反应？**  
A: 检查是否遗漏了 NOTIFY 信号，且信号在属性值实际改变时发射。

**Q: 跨线程操作 QML 对象安全吗？**  
A: 不安全，必须使用 `QMetaObject::invokeMethod` 或信号槽将操作投递到主线程。

**Q: `QQmlListProperty` 和 `QList<QObject*>` 暴露属性有什么区别？**  
A: `QQmlListProperty` 允许 QML 端修改列表，而 `QList<QObject*>` 作为属性时通常是只读引用，且变更通知较复杂。`QQmlListProperty` 更适合模型数据。

---

> 参考资料：[Qt官方文档 Integrating QML and C++](https://doc.qt.io/qt-6/qtqml-cppintegration-topic.html)、[Qt博客](https://www.qt.io/blog)、[KDAB学术文章](https://www.kdab.com/category/development/)、[ICS技术博客](https://www.ics.com/learn)
