# Qt6 QML / Qt Quick 组件完全参考手册

> 本文档整合自 Qt 6 官方文档（doc.qt.io），涵盖 QML 语言规范、QtQuick 核心组件、QtQuick.Controls 控件、QtQuick 子模块、Qt Quick 扩展模块（3D、Timeline）以及完整的属性值取值规范。是一份面向开发全流程的完整参考手册，而非速查摘要。

---

# 目录

**一、QML 核心语法与语言机制**
- [1.1 整体概览](#11-整体概览)
- [1.2 对象声明](#12-对象声明)
- [1.3 属性赋值（字面量赋值与属性绑定）](#13-属性赋值)
- [1.4 唯一 ID 标识符](#14-唯一-id-标识符)
- [1.5 子对象嵌套](#15-子对象嵌套)
- [1.6 自定义属性声明](#16-自定义属性声明)
- [1.7 信号与信号处理器](#17-信号与信号处理器)
- [1.8 方法声明](#18-方法声明)
- [1.9 导入语句](#19-导入语句)
- [1.10 注释](#110-注释)
- [1.11 列表与 JavaScript 数组](#111-列表与-javascript-数组)
- [1.12 附加属性与附加信号处理器](#112-附加属性与附加信号处理器)
- [1.13 JavaScript 环境与作用域规则](#113-javascript-环境与作用域规则)
- [1.14 状态与过渡语法](#114-状态与过渡语法)
- [1.15 基本类型值语法](#115-基本类型值语法)
- [1.16 语法检查清单](#116-语法检查清单)

**二、QtQuick 基础组件速览**
- [2.1 基础可视元素](#21-基础可视元素)
- [2.2 矢量与绘制](#22-矢量与绘制)
- [2.3 交互与事件处理器](#23-交互与事件处理器)
- [2.4 定位器与基础布局](#24-定位器与基础布局)
- [2.5 可滚动与视图基类](#25-可滚动与视图基类)
- [2.6 动画、状态与过渡基类](#26-动画状态与过渡基类)
- [2.7 非可视辅助元素](#27-非可视辅助元素)
- [2.8 顶层窗口](#28-顶层窗口)

**三、QtQuick 核心组件完整属性详表**
- [3.1 Item（所有视觉组件的基类）](#31-item所有视觉组件的基类)
- [3.2 Rectangle](#32-rectangle)
- [3.3 Text](#33-text)
- [3.4 Image](#34-image)
- [3.5 BorderImage](#35-borderimage)
- [3.6 AnimatedImage](#36-animatedimage)
- [3.7 AnimatedSprite](#37-animatedsprite)
- [3.8 Canvas](#38-canvas)
- [3.9 MouseArea](#39-mousearea)
- [3.10 Keys（附加属性）](#310-keys附加属性)
- [3.11 Flickable](#311-flickable)
- [3.12 ListView](#312-listview)
- [3.13 GridView](#313-gridview)
- [3.14 PathView](#314-pathview)
- [3.15 Timer](#315-timer)
- [3.16 Component](#316-component)
- [3.17 QtObject](#317-qtobject)
- [3.18 Connections](#318-connections)
- [3.19 Binding](#319-binding)
- [3.20 FontLoader](#320-fontloader)
- [3.21 Window](#321-window)

**四、QtQuick 官方核心子模块专题详解**
- [4.1 QtQuick.Controls](#41-qtquickcontrols)
- [4.2 QtQuick.Layouts](#42-qtquicklayouts)
- [4.3 QtQuick.Effects](#43-qtquickeffects)
- [4.4 QtQuick.Shapes](#44-qtquickshapes)
- [4.5 QtQuick.Particles](#45-qtquickparticles)
- [4.6 QtQuick.LocalStorage](#46-qtquicklocalstorage)
- [4.7 QtTest](#47-qttest)
- [4.8 QtQuick.VectorImage](#48-qtquickvectorimage)

**五、Qt Quick 扩展模块：三维图形与关键帧动画**
- [5.1 Qt Quick 3D 三维图形模块](#51-qt-quick-3d-三维图形模块)
- [5.2 Qt Quick Timeline 关键帧动画模块](#52-qt-quick-timeline-关键帧动画模块)

**六、属性值取值规范（完整）**
- [6.1 字面量](#61-字面量)
- [6.2 属性绑定](#62-属性绑定)
- [6.3 枚举值](#63-枚举值)
- [6.4 颜色值](#64-颜色值)
- [6.5 字体值](#65-字体值)
- [6.6 矩形值](#66-矩形值)
- [6.7 尺寸值](#67-尺寸值)
- [6.8 点值](#68-点值)
- [6.9 对象实例](#69-对象实例)
- [6.10 列表值](#610-列表值)
- [6.11 var 类型](#611-var-类型)
- [6.12 空值 / undefined](#612-空值--undefined)
- [6.13 附加属性值](#613-附加属性值)
- [6.14 取值规范速查总表](#614-取值规范速查总表)
- [6.15 取值规范核心要点](#615-取值规范核心要点)

**七、QML 值类型一览表**

**八、常用组件对照速查表（功能 vs QML vs HTML）**


# 一、QML 核心语法与语言机制

## 1.1 整体概览

QML 是一种**声明式**、基于 JSON 语法扩展的标记语言，用于描述用户界面的对象树及行为。其核心语法规则可概括为：

> **`[导入语句] [对象声明] { [属性赋值] [子对象] [信号处理器] [方法] }`**

## 1.2 对象声明

每个 QML 对象遵循 `TypeName { }` 的格式：

- **类型名称**首字母必须大写（如 `Rectangle`、`Text`、`Item`）。
- **花括号** `{ }` 内定义该对象的属性、子对象及逻辑。
- QML 文档必须有且仅有一个**根对象**。

```qml
// 根对象声明
Rectangle {
    // 属性、子对象等
}
```

## 1.3 属性赋值

属性赋值采用 **`属性名: 值`** 的键值对格式，使用冒号 `:` 分隔，每条赋值语句可用分号 `;` 或换行分隔。

| 类型 | 语法 | 特性 |
|------|------|------|
| **字面量赋值** | `width: 200` | 直接赋予静态值（数值、字符串、布尔等） |
| **属性绑定（Binding）** | `width: parent.width / 2` | 右侧为 JavaScript 表达式，依赖的值发生变化时自动重新求值（**响应式**） |

> **关键规则**：`属性: 表达式` 会建立**永久绑定**；若后续使用 `对象.属性 = 值`（JavaScript 赋值）会**破坏绑定**，转为静态值。

## 1.4 唯一 ID 标识符

- 每个对象可通过 `id` 属性赋予唯一名称（小写字母或下划线开头）。
- `id` 在 QML 文档作用域内必须唯一。
- 通过 `id` 可在任何子对象或逻辑中直接引用该对象。

```qml
Item {
    id: root
    Rectangle {
        id: rect
        width: root.width * 0.5
    }
}
```

## 1.5 子对象嵌套

在父对象的花括号内直接声明子对象，形成层级树：

```qml
Rectangle {
    id: parentItem
    Text { id: childText; text: "Hello" }
    MouseArea { anchors.fill: parent }
}
```

## 1.6 自定义属性声明

使用 `property` 关键字在对象内部声明自定义属性：

```qml
property <类型> <属性名> : <初始值>
```

- **类型**：支持基本类型（`int`、`real`、`string`、`bool`、`url`、`color`、`font`）、对象类型（`Item`、`Rectangle`）、`var`（任意类型）、`list<Type>`（列表）。
- 自定义属性默认具有**绑定能力**（可响应式更新）。

## 1.7 信号与信号处理器

**信号声明**：
```qml
signal <信号名>(<参数1类型> <参数1名>, <参数2类型> <参数2名>, ...)
```

**信号处理器**：自动生成 `on<信号名>` 格式的处理器，信号名首字母大写。
```qml
on<信号名>: { // JavaScript 代码 }
```

**属性变化信号**：当 QML 属性值发生变化时，系统自动发出 `on<属性名>Changed` 信号。
```qml
onPressedChanged: console.log("pressed changed:", pressed)
```

## 1.8 方法声明

使用 `function` 关键字在对象内部定义方法：

```qml
function <方法名>(<参数1>, <参数2>, ...) {
    // JavaScript 代码
    return <值>;
}
```

- 方法体内支持标准的 ECMAScript 6 语法。
- 可通过 `id.方法名()` 调用。

## 1.9 导入语句

QML 文档顶部必须声明所需模块：

```qml
import <Module> <Version> [as <Alias>]
import "本地目录路径"
```

- **版本**：通常指定主版本号（如 `6.0`、`2.15`）。
- **别名**：可选，用于避免命名冲突。

```qml
import QtQuick 6.0
import QtQuick.Controls 6.0 as Controls
```

## 1.10 注释

- **单行注释**：`// 注释内容`
- **多行注释**：`/* 注释内容 */`

## 1.11 列表与 JavaScript 数组

使用方括号 `[ ]` 表示列表类型属性：

```qml
states: [
    State { name: "state1" },
    State { name: "state2" }
]
```

- 纯值列表：`property var myList: [1, 2, 3]`
- 支持 `.push()`、`.length` 等 JavaScript 数组方法（针对 `var` 类型）。

## 1.12 附加属性与附加信号处理器

由外部类型附加到对象上的特殊属性：

| 类型 | 语法示例 | 说明 |
|------|----------|------|
| 附加属性 | `ListView.isCurrentItem: true` | 由 ListView 附加到其 delegate 项上 |
| 附加属性 | `Layout.fillWidth: true` | 由 QtQuick.Layouts 附加到子项上 |
| 附加信号处理器 | `Keys.onPressed: { ... }` | 由 Keys 附加对象提供键盘事件 |

## 1.13 JavaScript 环境与作用域规则

**属性绑定的 JS 表达式**：
- 允许使用算术、逻辑、三元运算符。
- 可以调用方法（`id.func()`）。
- 可以引用其他属性（`otherProperty + 10`）。
- **禁止**使用 `var` 声明变量（会破坏绑定），仅可使用表达式。

**作用域链（按优先级）**：
1. 当前对象的 `id` 和自定义属性。
2. 父对象的 `id`（逐级向上）。
3. 导入模块中的枚举/常量。
4. 全局 JavaScript 对象（如 `Math`、`Date`）。

**属性绑定与 JavaScript 赋值的区别**：

| 操作 | 语法 | 效果 |
|------|------|------|
| 绑定 | `width: parent.width` | 持续跟踪依赖，动态更新 |
| 赋值 | `width = parent.width`（在 JS 块内） | 只计算一次当前值，**永久解除绑定** |

## 1.14 状态与过渡语法

- **states** 属性接收 `State` 对象列表，每个 `State` 包含 `name` 和 `PropertyChanges`。
- **transitions** 属性接收 `Transition` 对象列表，定义状态切换动画。

```qml
states: [
    State {
        name: "hovered"
        PropertyChanges { target: rect; color: "red" }
    }
]
transitions: [
    Transition {
        ColorAnimation { target: rect; duration: 200 }
    }
]
```

## 1.15 基本类型值语法

| 类型 | 字面量/构造语法 |
|------|----------------|
| `int` / `real` | 直接数字（`10`, `3.14`） |
| `string` | 双引号包裹（`"text"`） |
| `bool` | `true` / `false` |
| `color` | 名称（`"red"`）/#RRGGBB/`Qt.rgba()` |
| `url` | 字符串（`"image.png"`） |
| `font` | `Qt.font({family: "Arial", pixelSize: 12})` |
| `rect` | `Qt.rect(x, y, w, h)` |
| `point` / `size` | `Qt.point(x, y)` / `Qt.size(w, h)` |
| `list` | `[item1, item2]` |
| `var` | 任意 JS 值 |

## 1.16 语法检查清单

| 规则 | 说明 |
|------|------|
| ✅ 根对象必须只有一个 | 每个 `.qml` 文件顶层只能有一个对象 |
| ✅ 类型名首字母大写 | `Rectangle` ✅ / `rectangle` ❌ |
| ✅ 属性名小写开头 | `width` ✅ / `Width` ❌（除枚举外） |
| ✅ 冒号赋值 | `属性: 值`，不是 `=`（除非在 JS 块内） |
| ✅ 分号可选 | 换行可替代分号，但推荐使用 |
| ✅ 绑定是响应式的 | `width: parent.width` 会自动更新 |
| ✅ ID 全局唯一 | 同一文档内不能重复 |
| ✅ 大小写敏感 | `onClicked` 与 `onclicked` 不同 |


# 二、QtQuick 基础组件速览

> `import QtQuick` 提供了 Qt Quick 的核心视觉与非视觉元素。`Item` 是所有视觉组件的基类。

## 2.1 基础可视元素

| 组件 | 说明 | 对标 HTML |
|------|------|-----------|
| `Item` | 所有视觉组件的基类，本身透明，用作容器 | `<div>` |
| `Rectangle` | 带填充色、圆角和边框的矩形 | `<div>` + CSS |
| `Text` | 显示格式化文本 | `<span>` / `<p>` |
| `Image` | 显示本地或网络图片 | `<img>` |
| `BorderImage` | 九宫格缩放边框图片 | CSS `border-image` |
| `AnimatedImage` | 播放 GIF 等动画图片 | `<img>` + GIF |
| `AnimatedSprite` | 从精灵表逐帧播放动画 | Canvas 精灵动画 |

## 2.2 矢量与绘制

| 组件 | 说明 |
|------|------|
| `Canvas` | 2D 画布，与 HTML Canvas API 类似 |
| `ShaderEffect` | 自定义着色器效果 |

## 2.3 交互与事件处理器

| 组件 | 说明 | 对标 HTML |
|------|------|-----------|
| `MouseArea` | 捕获鼠标点击、悬停、拖拽事件 | `onclick` / `onmouseover` |
| `DragHandler` | 拖拽事件处理器 | `ondrag` |
| `TapHandler` | 触摸/点击事件处理器 | `ontouch` / `onclick` |
| `WheelHandler` | 鼠标滚轮事件处理器 | `onwheel` |
| `Keys`（附加属性） | 键盘事件处理 | `onkeydown` / `onkeyup` |
| `DropArea` | 拖放目标区域 | `ondrop` / `ondragover` |

## 2.4 定位器与基础布局

| 组件 | 说明 | 对标 CSS |
|------|------|----------|
| `Row` | 水平排列子元素 | `flex-direction: row` |
| `Column` | 垂直排列子元素 | `flex-direction: column` |
| `Grid` | 网格排列子元素 | `display: grid` |
| `Flow` | 流式布局（自动换行） | `flex-wrap: wrap` |

## 2.5 可滚动与视图基类

| 组件 | 说明 |
|------|------|
| `Flickable` | 可滑动内容区域（基类） |
| `ListView` | 列表视图 |
| `GridView` | 网格视图 |
| `PathView` | 沿路径排列元素的视图 |

## 2.6 动画、状态与过渡基类

| 组件 | 说明 | 对标 CSS |
|------|------|----------|
| `PropertyAnimation` | 属性值变化动画 | CSS `transition` |
| `NumberAnimation` | 数值属性动画 | CSS 数值过渡 |
| `ColorAnimation` | 颜色变化动画 | CSS 颜色过渡 |
| `RotationAnimation` | 旋转动画 | `transform: rotate()` |
| `SequentialAnimation` | 顺序执行多个动画 | 多个 `@keyframes` 串联 |
| `ParallelAnimation` | 并行执行多个动画 | 多个动画同时播放 |
| `Behavior` | 属性变化的默认动画 | CSS `transition` |
| `Transition` | 状态切换时的过渡动画 | CSS 状态过渡 |
| `State` | 定义组件的不同状态 | CSS 类切换 |

## 2.7 非可视辅助元素

| 组件 | 说明 |
|------|------|
| `Timer` | 定时器 |
| `Component` | 可重用的 QML 类型模板 |
| `QtObject` | 非可视对象基类 |
| `Connections` | 连接信号与槽 |
| `Binding` | 动态属性绑定 |
| `FontLoader` | 加载自定义字体 |

## 2.8 顶层窗口

| 组件 | 说明 |
|------|------|
| `Window` | 顶层窗口（`import QtQuick`） |


# 三、QtQuick 核心组件完整属性详表

> 以下表格遵循“属性（名称） | 说明 | 取值规范”三列结构。取值规范的具体写法参见第六章“属性值取值规范（完整）”。

## 3.1 Item（所有视觉组件的基类）

所有视觉组件继承自 `Item`，拥有以下通用属性：

| 属性 | 说明 | 取值规范 |
|------|------|----------|
| `x` | X 坐标 | `real`，可绑定 |
| `y` | Y 坐标 | `real`，可绑定 |
| `width` | 宽度 | `real`，≥0 |
| `height` | 高度 | `real`，≥0 |
| `implicitWidth` | 隐式宽度（只读） | 由内容决定 |
| `implicitHeight` | 隐式高度（只读） | 由内容决定 |
| `opacity` | 不透明度 | `real`，0.0~1.0 |
| `visible` | 是否可见 | `true` / `false` |
| `enabled` | 是否启用 | `true` / `false` |
| `clip` | 是否裁剪溢出子内容 | `true` / `false` |
| `transform` | 变换列表 | `list<Transform>`，含 `Translate`/`Rotate`/`Scale` |
| `transformOrigin` | 变换原点 | `Item.Center`、`Item.TopLeft`、`Item.BottomRight` 等 |
| `rotation` | 旋转角度（度） | `real` |
| `scale` | 缩放倍数 | `real`，≥0，默认1 |
| `z` | Z 轴堆叠顺序 | `real`，数值越大越靠前 |
| `focus` | 是否拥有键盘焦点 | `true` / `false` |
| `activeFocus` | 是否处于活动焦点（只读） | — |
| `parent` | 父元素 | 通过 `id` 引用 |
| `children` | 子元素列表（只读） | — |
| `anchors` | 锚点布局（分组） | 见下方 |
| `state` | 当前状态名称 | `string` |
| `states` | 状态列表 | `[State { ... }, ...]` |
| `transitions` | 过渡列表 | `[Transition { ... }, ...]` |

### anchors 分组属性

| 属性 | 说明 | 取值规范 |
|------|------|----------|
| `anchors.left` / `right` / `top` / `bottom` | 边缘锚定 | 绑定到 `otherItem.left` 等 |
| `anchors.horizontalCenter` / `verticalCenter` | 中心锚定 | 绑定到 `otherItem.horizontalCenter` 等 |
| `anchors.baseline` | 基线锚定 | 绑定到 `otherItem.baseline` |
| `anchors.fill` | 填充目标元素 | `parent` 或 `id` |
| `anchors.centerIn` | 居中于目标元素 | `parent` 或 `id` |
| `anchors.alignWhenCentered` | 居中时是否对齐 | `true` / `false` |
| `anchors.margins` | 统一外边距 | `real` |
| `anchors.leftMargin` / `rightMargin` / `topMargin` / `bottomMargin` | 各边外边距 | `real` |
| `anchors.horizontalCenterOffset` / `verticalCenterOffset` | 中心偏移 | `real` |
| `anchors.baselineOffset` | 基线偏移 | `real` |

## 3.2 Rectangle

| 属性 | 说明 | 取值规范 |
|------|------|----------|
| `color` | 填充颜色 | 颜色值（SVG 名称、`#RRGGBB`、`Qt.rgba()` 等） |
| `gradient` | 渐变填充（优先级高于 `color`） | `Gradient { GradientStop { ... } }` |
| `border.color` | 边框颜色 | 颜色值 |
| `border.width` | 边框宽度 | `int`，≥0 |
| `radius` | 统一圆角半径 | `real`，≥0 |
| `topLeftRadius` / `topRightRadius` / `bottomLeftRadius` / `bottomRightRadius` | 各角圆角（Qt 6.7+） | `real`，≥0 |
| `antialiasing` | 抗锯齿 | `true` / `false` |

## 3.3 Text

| 属性 | 说明 | 取值规范 |
|------|------|----------|
| `text` | 文本内容 | `string` |
| `color` | 文本颜色 | 颜色值 |
| `font` | 字体（分组） | 见下方 |
| `horizontalAlignment` | 水平对齐 | `Text.AlignLeft`、`Text.AlignHCenter`、`Text.AlignRight` |
| `verticalAlignment` | 垂直对齐 | `Text.AlignTop`、`Text.AlignVCenter`、`Text.AlignBottom` |
| `effectiveHorizontalAlignment` | 实际水平对齐（只读） | — |
| `elide` | 省略模式 | `Text.ElideNone`、`Text.ElideLeft`、`Text.ElideMiddle`、`Text.ElideRight` |
| `wrapMode` | 换行模式 | `Text.NoWrap`、`Text.WordWrap`、`Text.WrapAnywhere`、`Text.WrapAtWordBoundaryOrAnywhere` |
| `lineHeight` | 行高 | `real` |
| `lineHeightMode` | 行高模式 | `Text.Proportional`（倍数）、`Text.Fixed`（像素） |
| `maximumLineCount` | 最大行数 | `int`，≥1 |
| `minimumPointSize` | 最小点大小 | `real` |
| `minimumPixelSize` | 最小像素大小 | `int` |
| `fontSizeMode` | 字体大小模式 | `Text.Fixed`、`Text.HorizontalFit`、`Text.VerticalFit`、`Text.Fit` |
| `clip` | 裁剪溢出文本 | `true` / `false` |
| `contentWidth` / `contentHeight` | 内容尺寸（只读） | — |
| `baseUrl` | 相对 URL 基础路径 | `url` |
| `advance` | 文本前进宽度（只读） | — |
| `antialiasing` | 抗锯齿 | `true` / `false` |
| `bottomPadding` | 底部内边距 | `real` |

### font 分组属性

| 属性 | 说明 | 取值规范 |
|------|------|----------|
| `font.family` | 字体家族 | `string`（如 `"Arial"`） |
| `font.pixelSize` | 像素大小 | `int` |
| `font.pointSize` | 点大小 | `real` |
| `font.bold` | 加粗 | `true` / `false` |
| `font.italic` | 斜体 | `true` / `false` |
| `font.underline` | 下划线 | `true` / `false` |
| `font.strikeout` | 删除线 | `true` / `false` |
| `font.capitalization` | 大小写转换 | `Font.MixedCase`、`Font.AllUppercase`、`Font.AllLowercase`、`Font.SmallCaps`、`Font.Capitalize` |
| `font.letterSpacing` | 字母间距 | `real` |
| `font.wordSpacing` | 单词间距 | `real` |
| `font.kerning` | 字距调整 | `true` / `false` |
| `font.hintingPreference` | 字体微调偏好 | `Font.PreferDefaultHinting`、`PreferNoHinting`、`PreferVerticalHinting`、`PreferFullHinting` |
| `font.features` | OpenType 字体特性（Qt 6.6+） | `object` |
| `font.preferShaping` | 是否优先使用字形整形 | `true` / `false` |

## 3.4 Image

| 属性 | 说明 | 取值规范 |
|------|------|----------|
| `source` | 图像源 | `url`（本地路径或网络 URL） |
| `sourceSize` | 源图像加载尺寸 | `Qt.size(w, h)` |
| `sourceClipRect` | 源图像裁剪区域 | `Qt.rect(x, y, w, h)` |
| `fillMode` | 填充模式 | `Image.Stretch`、`Image.PreserveAspectFit`、`Image.PreserveAspectCrop`、`Image.Tile`、`Image.TileVertically`、`Image.TileHorizontally`、`Image.Pad` |
| `horizontalAlignment` / `verticalAlignment` | 对齐方式 | `Image.AlignLeft`/`AlignHCenter`/`AlignRight` 等 |
| `cache` | 是否缓存 | `true` / `false` |
| `asynchronous` | 异步加载 | `true` / `false` |
| `mirror` | 水平镜像 | `true` / `false` |
| `mirrorVertically` | 垂直镜像（Qt 6.2+） | `true` / `false` |
| `smooth` | 平滑缩放 | `true` / `false` |
| `mipmap` | 使用 Mipmap | `true` / `false` |
| `autoTransform` | 自动应用元数据变换 | `true` / `false` |
| `progress` | 加载进度（只读） | `real`，0.0~1.0 |
| `status` | 加载状态（只读） | `Image.Null`、`Image.Ready`、`Image.Loading`、`Image.Error` |
| `frameCount` | 帧数（只读） | `int` |
| `currentFrame` | 当前帧索引 | `int` |
| `paintedWidth` / `paintedHeight` | 实际绘制尺寸（只读） | — |
| `retainWhileLoading` | 加载时保留旧图像（Qt 6.8+） | `true` / `false` |

## 3.5 BorderImage

| 属性 | 说明 | 取值规范 |
|------|------|----------|
| `source` | 图像源 | `url` |
| `border.left` / `right` / `top` / `bottom` | 各边边框宽度 | `int` |
| `horizontalTileMode` | 水平平铺模式 | `BorderImage.Stretch`、`BorderImage.Repeat`、`BorderImage.Round` |
| `verticalTileMode` | 垂直平铺模式 | `BorderImage.Stretch`、`BorderImage.Repeat`、`BorderImage.Round` |
| `asynchronous` | 异步加载 | `true` / `false` |
| `cache` | 是否缓存 | `true` / `false` |
| `status` | 加载状态（只读） | `BorderImage.Null`、`Ready`、`Loading`、`Error` |
| `progress` | 加载进度（只读） | `real`，0.0~1.0 |

## 3.6 AnimatedImage

| 属性 | 说明 | 取值规范 |
|------|------|----------|
| `source` | 图像源 | `url` |
| `currentFrame` | 当前帧索引 | `int` |
| `frameCount` | 总帧数（只读） | `int` |
| `playing` | 是否播放 | `true` / `false` |
| `paused` | 是否暂停 | `true` / `false` |
| `speed` | 播放速度倍率 | `real`，默认1.0 |
| `cache` | 是否缓存 | `true` / `false` |
| `asynchronous` | 异步加载 | `true` / `false` |
| `status` | 加载状态（只读） | `AnimatedImage.Null`、`Ready`、`Loading`、`Error` |

## 3.7 AnimatedSprite

| 属性 | 说明 | 取值规范 |
|------|------|----------|
| `source` | 精灵表图像源 | `url` |
| `frameCount` | 总帧数 | `int` |
| `frameWidth` / `frameHeight` | 每帧宽度/高度 | `int` |
| `frameDuration` | 每帧持续时间（毫秒） | `int` |
| `frameSync` | 是否同步帧切换 | `true` / `false` |
| `loops` | 循环次数（-1 为无限） | `int` |
| `running` | 是否运行 | `true` / `false` |
| `paused` | 是否暂停 | `true` / `false` |
| `currentFrame` | 当前帧索引 | `int` |
| `interpolate` | 是否插值 | `true` / `false` |

## 3.8 Canvas

| 属性 | 说明 | 取值规范 |
|------|------|----------|
| `contextType` | 上下文类型 | `"2d"`（唯一支持） |
| `canvasSize` | 画布尺寸 | `size` |
| `available` | 画布是否可用（只读） | — |
| `renderStrategy` | 渲染策略 | `Canvas.Cooperative`、`Canvas.Immediate`、`Canvas.Threaded` |
| `renderTarget` | 渲染目标 | `Canvas.Image`、`Canvas.FramebufferObject` |

主要方法：`getContext("2d")`、`requestPaint()`。

## 3.9 MouseArea

| 属性 | 说明 | 取值规范 |
|------|------|----------|
| `acceptedButtons` | 接受的鼠标按钮 | `Qt.LeftButton`、`Qt.RightButton`、`Qt.MiddleButton` 等（`\|` 组合） |
| `hoverEnabled` | 启用悬停事件 | `true` / `false` |
| `pressed` | 是否按下（只读） | — |
| `pressedButtons` | 当前按下的按钮（只读） | — |
| `containsMouse` | 鼠标是否在区域内（只读） | — |
| `propagateComposedEvents` | 传递组合事件 | `true` / `false` |
| `preventStealing` | 阻止事件被父级窃取 | `true` / `false` |
| `drag` | 拖拽配置（分组） | 见下方 |
| `scrollGestureEnabled` | 启用滚动手势（Qt 6.7+） | `true` / `false` |
| `cursorShape` | 鼠标光标形状 | `Qt.ArrowCursor`、`Qt.PointingHandCursor` 等 |
| `enabled` | 是否启用 | `true` / `false` |
| `visible` | 是否可见（默认 true） | `true` / `false` |

### drag 分组属性

| 属性 | 说明 | 取值规范 |
|------|------|----------|
| `drag.target` | 拖拽目标元素 | 通过 `id` 引用 |
| `drag.active` | 是否激活拖拽 | `true` / `false` |
| `drag.axis` | 拖拽轴 | `Drag.XAxis`、`Drag.YAxis`、`Drag.XAndYAxis` |
| `drag.minimumX` / `maximumX` | X 方向范围 | `real` |
| `drag.minimumY` / `maximumY` | Y 方向范围 | `real` |
| `drag.filterChildren` | 是否过滤子元素事件 | `true` / `false` |
| `drag.threshold` | 拖拽启动阈值 | `real` |

## 3.10 Keys（附加属性）

| 属性 | 说明 | 取值规范 |
|------|------|----------|
| `Keys.enabled` | 是否启用键盘处理 | `true` / `false` |
| `Keys.forwardTo` | 转发未处理事件的目标列表 | `list<Item>` |
| `Keys.priority` | 优先级 | `Keys.BeforeItem`、`Keys.AfterItem` |

常见信号处理器：`onPressed`、`onReleased`、`onClicked`、`onShortcutOverride`、`onDigit0`~`onDigit9`、`onA`~`onZ` 等。

## 3.11 Flickable

| 属性 | 说明 | 取值规范 |
|------|------|----------|
| `contentX` / `contentY` | 内容偏移量 | `real` |
| `contentWidth` / `contentHeight` | 内容尺寸 | `real` |
| `flickableDirection` | 滑动方向 | `Flickable.AutoFlickIfNeeded`、`HorizontalFlick`、`VerticalFlick` |
| `boundsBehavior` | 边界行为 | `Flickable.StopAtBounds`、`DragOverBounds`、`FlickOverBounds` |
| `boundsMovement` | 边界移动方式（Qt 6.7+） | `Flickable.FollowBoundsBehavior`、`StopAtBounds` |
| `interactive` | 是否可交互 | `true` / `false` |
| `maximumFlickVelocity` | 最大滑动速度 | `real` |
| `flickDeceleration` | 滑动减速度 | `real` |
| `pixelAligned` | 像素对齐 | `true` / `false` |
| `topMargin` / `bottomMargin` / `leftMargin` / `rightMargin` | 边距 | `real` |
| `moving` | 是否正在移动（只读） | — |
| `flicking` | 是否正在惯性滑动（只读） | — |
| `dragging` | 是否正在拖拽（只读） | — |

## 3.12 ListView

| 属性 | 说明 | 取值规范 |
|------|------|----------|
| `model` | 数据模型 | `ListModel`、整数、JS 数组 |
| `delegate` | 项代理 | `Component { ... }` |
| `orientation` | 方向 | `ListView.Vertical`、`ListView.Horizontal` |
| `spacing` | 项间距 | `real` |
| `currentIndex` | 当前项索引 | `int` |
| `currentItem` | 当前项（只读） | — |
| `contentX` / `contentY` | 内容偏移 | `real` |
| `contentWidth` / `contentHeight` | 内容尺寸（只读） | — |
| `header` / `footer` | 页眉/页脚组件 | `Component { ... }` |
| `headerPositioning` | 页眉定位 | `ListView.OverlayHeader`、`InlineHeader`、`PullBackHeader` |
| `footerPositioning` | 页脚定位 | 同上 |
| `snapMode` | 吸附模式 | `ListView.NoSnap`、`ListView.SnapToItem` |
| `cacheBuffer` | 缓存缓冲区大小 | `int` |
| `highlight` | 高亮项代理 | `Component { ... }` |
| `highlightRangeMode` | 高亮范围模式 | `ListView.NoHighlightRange`、`StrictlyEnforceRange`、`ApplyRange` |
| `highlightMoveDuration` | 高亮移动动画时长（ms） | `int` |
| `preferredHighlightBegin` / `End` | 高亮范围 | `real` |
| `flickableDirection` | 滑动方向 | `Flickable.AutoFlickIfNeeded`、`HorizontalFlick`、`VerticalFlick` |
| `boundsBehavior` | 边界行为 | `Flickable.StopAtBounds`、`DragOverBounds`、`FlickOverBounds` |
| `maximumFlickVelocity` | 最大滑动速度 | `real` |
| `flickDeceleration` | 滑动减速度 | `real` |
| `keyNavigationWraps` | 键盘循环 | `true` / `false` |
| `verticalLayoutDirection` | 垂直布局方向 | `ListView.TopToBottom`、`BottomToTop` |
| `add` / `remove` / `move` / `displaced` | 增删移动过渡动画 | `Transition { ... }` |

## 3.13 GridView

继承 `ListView` 的基础属性，额外增加：

| 属性 | 说明 | 取值规范 |
|------|------|----------|
| `cellWidth` / `cellHeight` | 单元格尺寸 | `real` |
| `flow` | 流动方向 | `GridView.LeftToRight`、`GridView.TopToBottom` |
| `flowing` | 是否流动布局（只读） | — |

## 3.14 PathView

| 属性 | 说明 | 取值规范 |
|------|------|----------|
| `path` | 路径定义 | `Path { ... }` |
| `model` | 数据模型 | `ListModel`、整数、JS 数组 |
| `delegate` | 项代理 | `Component { ... }` |
| `currentIndex` | 当前项索引 | `int` |
| `offset` | 偏移量 | `real` |
| `pathItemCount` | 可见项数量 | `int` |
| `highlightRangeMode` | 高亮范围模式 | `PathView.NoHighlightRange`、`StrictlyEnforceRange`、`ApplyRange` |
| `preferredHighlightBegin` / `End` | 高亮范围 | `real` |
| `dragMargin` | 拖拽边距 | `real` |
| `interactive` | 是否可交互 | `true` / `false` |
| `snapMode` | 吸附模式 | `PathView.NoSnap`、`SnapToItem` |

## 3.15 Timer

| 属性 | 说明 | 取值规范 |
|------|------|----------|
| `interval` | 间隔时间（毫秒） | `int` |
| `running` | 是否运行 | `true` / `false` |
| `repeat` | 是否重复 | `true` / `false` |
| `triggeredOnStart` | 启动时立即触发 | `true` / `false` |

## 3.16 Component

| 属性 | 说明 | 取值规范 |
|------|------|----------|
| `progress` | 加载进度（只读） | `real`，0.0~1.0 |
| `status` | 加载状态（只读） | `Component.Null`、`Component.Ready`、`Component.Loading`、`Component.Error` |
| `url` | 组件 URL | `url` |
| `creationContext` | 创建上下文（只读） | — |

## 3.17 QtObject

| 属性 | 说明 | 取值规范 |
|------|------|----------|
| `objectName` | 对象名称 | `string` |

`QtObject` 本身是 `QObject` 的直接子类，可以作为非可视数据的容器。

## 3.18 Connections

| 属性 | 说明 | 取值规范 |
|------|------|----------|
| `target` | 目标对象 | 通过 `id` 引用 |
| `ignoreUnknownSignals` | 是否忽略未知信号 | `true` / `false` |
| `enabled` | 是否启用 | `true` / `false` |

在 `Connections` 内部，通过 `on<Signal>` 格式声明目标对象的信号处理器。

## 3.19 Binding

| 属性 | 说明 | 取值规范 |
|------|------|----------|
| `target` | 目标对象 | 通过 `id` 引用 |
| `property` | 目标属性名 | `string` |
| `value` | 绑定的值 | `var` |
| `when` | 绑定生效条件 | `bool`，`true` 时生效 |

## 3.20 FontLoader

| 属性 | 说明 | 取值规范 |
|------|------|----------|
| `source` | 字体文件 URL | `url` |
| `name` | 加载的字体名称（只读） | `string` |
| `status` | 加载状态（只读） | `FontLoader.Null`、`FontLoader.Ready`、`FontLoader.Error` |

## 3.21 Window

| 属性 | 说明 | 取值规范 |
|------|------|----------|
| `title` | 窗口标题 | `string` |
| `visible` | 是否可见（默认 `false`） | `true` / `false` |
| `width` / `height` | 窗口尺寸 | `real` |
| `minimumWidth` / `minimumHeight` | 最小尺寸 | `int` |
| `maximumWidth` / `maximumHeight` | 最大尺寸 | `int` |
| `x` / `y` | 窗口位置 | `int` |
| `flags` | 窗口标志 | `Qt.Window`、`Qt.Dialog`、`Qt.Popup` 等 |
| `modality` | 模态 | `Qt.NonModal`、`Qt.WindowModal`、`Qt.ApplicationModal` |
| `opacity` | 不透明度 | `real`，0.0~1.0 |
| `color` | 背景色 | 颜色值 |
| `active` | 是否激活（只读） | — |
| `contentItem` | 内容项（只读） | — |
| `activeFocusItem` | 活动焦点项（只读） | — |


# 四、QtQuick 官方核心子模块专题详解

## 4.1 QtQuick.Controls

> 提供一组可用于在 Qt Quick 中构建完整界面的标准 UI 控件。

**导入语句**：`import QtQuick.Controls`

### 模块速览

**按钮控件**（继承自 `AbstractButton`）：
- `Button`：可点击执行命令的按钮
- `CheckBox`：复选框
- `RadioButton`：单选按钮
- `Switch`：开关控件
- `DelayButton`：长按延迟触发的按钮
- `RoundButton`：圆角按钮
- `ToolButton`：适合工具栏的按钮

**容器控件**：
- `ApplicationWindow`：支持页眉和页脚的样式顶层窗口
- `Frame`：逻辑控件组的视觉框架
- `GroupBox`：带标题的逻辑控件组
- `Page`：支持页眉和页脚的样式页面
- `Pane`：与主题匹配的背景容器
- `ScrollView`：可滚动视图
- `SplitView`：可拖拽分割面板
- `StackView`：堆栈导航模型
- `SwipeView`：横向滑动导航
- `TabBar`：标签栏
- `ToolBar`：工具栏

**输入控件**：
- `TextField`：单行文本输入
- `TextArea`：多行文本输入
- `ComboBox`：下拉选择列表
- `Dial`：旋转刻度盘
- `Slider`：滑块选择数值
- `RangeSlider`：双滑块选择范围
- `SpinBox`：预设值选择
- `Tumbler`：旋转滚轮选择

**菜单控件**：`Menu`、`MenuBar`、`MenuItem`、`MenuSeparator`

**指示器控件**：`BusyIndicator`、`PageIndicator`、`ProgressBar`、`ScrollBar`、`ScrollIndicator`

**弹出控件**：`Popup`、`Dialog`、`DialogButtonBox`、`ToolTip`

**委托控件**：`ItemDelegate`、`CheckDelegate`、`RadioDelegate`、`SwipeDelegate`、`SwitchDelegate`

### Control（所有控件的基类）

| 属性 | 说明 | 取值规范 |
|------|------|----------|
| `availableWidth` / `availableHeight` | 可用尺寸（只读） | — |
| `background` | 背景项 | 任意 `Item`，如 `Rectangle` |
| `contentItem` | 内容项 | 任意 `Item` |
| `font` | 字体 | 同 `Text.font` |
| `padding` | 统一内边距 | `real` |
| `topPadding` / `bottomPadding` / `leftPadding` / `rightPadding` | 各边内边距 | `real` |
| `horizontalPadding` | 水平内边距 | `real` |
| `topInset` / `bottomInset` / `leftInset` / `rightInset` | 嵌入 | `real` |
| `implicitBackgroundWidth` / `Height` | 隐式背景尺寸（只读） | — |
| `implicitContentWidth` / `Height` | 隐式内容尺寸（只读） | — |
| `hoverEnabled` | 启用悬停 | `true` / `false` |
| `hovered` | 是否悬停（只读） | — |
| `mirrored` | 是否镜像布局（只读） | — |
| `focusReason` | 焦点获取原因（只读） | — |
| `locale` | 区域设置 | `Qt.locale()` |

### AbstractButton（按钮基类）

| 属性 | 说明 | 取值规范 |
|------|------|----------|
| `text` | 按钮文本 | `string` |
| `icon.name` | 图标名称（主题） | `string` |
| `icon.source` | 图标 URL | `url` |
| `icon.width` / `icon.height` | 图标尺寸 | `int` |
| `icon.color` | 图标颜色 | 颜色值 |
| `flat` | 扁平按钮 | `true` / `false` |
| `highlighted` | 高亮 | `true` / `false` |
| `checkable` | 可选中 | `true` / `false` |
| `checked` | 是否选中 | `true` / `false` |
| `autoExclusive` | 自动互斥 | `true` / `false` |
| `display` | 图标与文本显示方式 | `AbstractButton.IconOnly`、`TextOnly`、`IconLeft`、`IconRight` |

**Button / CheckBox / RadioButton / Switch / ToolButton / RoundButton** 均继承上述属性，部分有特有属性（如 `DelayButton` 的 `delay`、`progress`；`RoundButton` 的 `radius`）。

### TextField / TextInput（单行文本输入）

| 属性 | 说明 | 取值规范 |
|------|------|----------|
| `text` | 文本内容 | `string` |
| `placeholderText` | 占位提示 | `string` |
| `echoMode` | 回显模式 | `TextInput.Normal`、`TextInput.Password`、`TextInput.NoEcho`、`TextInput.PasswordEchoOnEdit` |
| `inputMethodHints` | 输入法提示 | `Qt.ImhNone`、`Qt.ImhDigitsOnly`、`Qt.ImhNoAutoUppercase` 等（`\|` 组合） |
| `maximumLength` | 最大字符数 | `int` |
| `validator` | 输入验证器 | `IntValidator {}`、`DoubleValidator {}`、`RegExpValidator {}` |
| `acceptableInput` | 输入是否可接受（只读） | — |
| `displayText` | 显示文本（含掩码，只读） | — |
| `selectedText` | 选中文本（只读） | — |
| `selectionStart` / `selectionEnd` | 选择范围 | `int` |
| `cursorPosition` | 光标位置 | `int` |
| `cursorVisible` | 光标可见 | `true` / `false` |
| `cursorRectangle` | 光标矩形（只读） | — |
| `readOnly` | 只读 | `true` / `false` |
| `persistentSelection` | 保持选中 | `true` / `false` |
| `selectByMouse` | 鼠标选择 | `true` / `false` |
| `passwordCharacter` | 掩码字符 | `string`（默认 `"*"`） |
| `passwordMaskDelay` | 掩码延迟（毫秒） | `int` |
| `hovered` | 是否悬停（只读） | — |

**TextArea / TextEdit**（多行）继承上述属性，额外增加：
- `wrapMode`（enumeration）：同 `Text` 的换行模式
- `lineCount`（int，只读）

### ComboBox

| 属性 | 说明 | 取值规范 |
|------|------|----------|
| `model` | 数据模型 | `ListModel`、JS 数组、整数 |
| `currentIndex` | 当前选中索引 | `int` |
| `currentValue` | 当前选中值（只读） | — |
| `displayText` | 显示文本（只读） | — |
| `popup` | 弹出菜单 | `Popup` 实例 |
| `delegate` | 项代理 | `Component { ... }` |
| `textRole` | 文本角色名 | `string` |
| `valueRole` | 值角色名 | `string` |
| `flat` | 扁平 | `true` / `false` |
| `pressed` / `hovered` | 状态（只读） | — |
| `editable` | 可编辑 | `true` / `false` |
| `find` | 查找文本 | `string` |
| `inputMethodHints` | 输入法提示（可编辑时） | `Qt.InputMethodHints` |
| `validator` | 验证器（可编辑时） | `Validator` |

### Slider / RangeSlider

| 属性 | 说明 | 取值规范 |
|------|------|----------|
| `value` | 当前值 | `real` |
| `from` / `to` | 最小值/最大值 | `real` |
| `stepSize` | 步长 | `real` |
| `orientation` | 方向 | `Qt.Horizontal`、`Qt.Vertical` |
| `live` | 实时更新 | `true` / `false` |
| `snapMode` | 吸附模式 | `Slider.NoSnap`、`Slider.SnapOnRelease`、`Slider.SnapAlways` |
| `position` | 手柄位置 0~1（只读） | — |
| `visualPosition` | 可视化位置（只读） | — |
| `pressed` / `hovered` | 状态（只读） | — |

**RangeSlider** 额外拥有：
- `first.value`（real）：第一手柄值
- `second.value`（real）：第二手柄值

### ProgressBar

| 属性 | 说明 | 取值规范 |
|------|------|----------|
| `value` | 当前进度 | `real`（0~`to`） |
| `from` / `to` | 起始/结束值 | `real`（默认 0/1） |
| `indeterminate` | 不确定进度（循环动画） | `true` / `false` |

### SpinBox

| 属性 | 说明 | 取值规范 |
|------|------|----------|
| `value` | 当前数值 | `int` |
| `from` / `to` | 最小值/最大值 | `int` |
| `stepSize` | 步长 | `int` |
| `editable` | 可编辑 | `true` / `false` |
| `displayText` | 显示文本（只读） | — |
| `validator` | 验证器 | `IntValidator` 等 |
| `inputMethodHints` | 输入法提示 | `Qt.InputMethodHints` |

### Dialog

| 属性 | 说明 | 取值规范 |
|------|------|----------|
| `title` | 标题 | `string` |
| `standardButtons` | 标准按钮组合 | `Dialog.Ok` \| `Dialog.Cancel` \| `Dialog.Save` \| `Dialog.Discard` \| `Dialog.Apply` \| `Dialog.Reset` \| `Dialog.RestoreDefaults` \| `Dialog.Help` \| `Dialog.SaveAll` \| `Dialog.Yes` \| `Dialog.YesToAll` \| `Dialog.No` \| `Dialog.NoToAll` \| `Dialog.Abort` \| `Dialog.Retry` \| `Dialog.Ignore` \| `Dialog.Close` \| `Dialog.Open` |
| `buttons` | 自定义按钮列表 | `list<Item>` |
| `footer` / `header` | 底部/顶部内容 | `Item` |
| `modal` | 模态 | `true` / `false` |
| `dim` | 变暗背景 | `true` / `false` |
| `closePolicy` | 关闭策略 | `Popup.NoAutoClose`、`Popup.CloseOnEscape`、`Popup.CloseOnPressOutside` 组合 |
| `result` | 对话框结果（只读） | `Dialog.Rejected`、`Dialog.Accepted` 等 |

### Popup

| 属性 | 说明 | 取值规范 |
|------|------|----------|
| `x` / `y` | 弹出位置 | `real` |
| `width` / `height` | 弹出尺寸 | `real` |
| `contentItem` | 内容项 | `Item` |
| `background` | 背景项 | `Item` |
| `modal` | 模态 | `true` / `false` |
| `dim` | 变暗背景 | `true` / `false` |
| `closePolicy` | 关闭策略 | 同 `Dialog` |
| `opacity` | 不透明度 | `real`，0.0~1.0 |
| `overlay` | 覆盖层 | `Overlay` |
| `enter` / `exit` | 进入/退出过渡动画 | `Transition { ... }` |
| `visible` | 是否可见 | `true` / `false` |
| `parent` | 父元素 | 通过 `id` 引用 |

### Menu / MenuBar / MenuItem / MenuSeparator

| 类型 | 属性 | 说明 | 取值规范 |
|------|------|------|----------|
| `Menu` | `title` | 标题 | `string` |
| `Menu` | `enabled` | 启用 | `true` / `false` |
| `Menu` | `icon.name` / `icon.source` | 图标 | `string` / `url` |
| `Menu` | `font` | 字体 | 同 `Text.font` |
| `Menu` | `menu` | 子菜单 | `Menu` 实例 |
| `MenuItem` | `text` | 文本 | `string` |
| `MenuItem` | `icon` | 图标 | — |
| `MenuItem` | `checkable` / `checked` | 选中 | `true` / `false` |
| `MenuItem` | `separator` | 分隔符 | `true` / `false` |
| `MenuSeparator` | — | 分隔线 | — |

### Drawer

| 属性 | 说明 | 取值规范 |
|------|------|----------|
| `position` | 抽屉位置 0~1（只读） | — |
| `interactive` | 可交互拖拽 | `true` / `false` |
| `edge` | 边缘方向 | `Qt.LeftEdge`、`Qt.RightEdge`、`Qt.TopEdge`、`Qt.BottomEdge` |
| `dragMargin` | 拖拽触发边距 | `real` |

### 其他控件简要属性

| 控件 | 关键属性 | 取值规范 |
|------|----------|----------|
| `BusyIndicator` | `running` | `true` / `false` |
| `PageIndicator` | `count`、`currentIndex` | `int` |
| `ScrollBar` / `ScrollIndicator` | `orientation`、`policy`（`ScrollBar.AsNeeded`/`AlwaysOn`/`AlwaysOff`） | — |
| `TabBar` | `currentIndex`、`position`（`TabBar.Header`/`Footer`） | — |
| `StackView` | `initialItem`、`currentItem`、方法 `push()`/`pop()`/`replace()` | — |
| `SwipeView` | `currentIndex`、`interactive` | — |

---

## 4.2 QtQuick.Layouts

> 提供用于在用户界面中排列项目的布局类型。与定位器不同，布局会调整子项目的大小。

**导入语句**：`import QtQuick.Layouts`

### Layout 附加属性（用于布局子项）

| 属性 | 说明 | 取值规范 |
|------|------|----------|
| `Layout.alignment` | 对齐方式 | `Qt.AlignLeft` \| `Qt.AlignTop` 等 |
| `Layout.fillWidth` | 填满可用宽度 | `true` / `false` |
| `Layout.fillHeight` | 填满可用高度 | `true` / `false` |
| `Layout.minimumWidth` / `minimumHeight` | 最小尺寸 | `real` |
| `Layout.preferredWidth` / `preferredHeight` | 首选尺寸 | `real` |
| `Layout.maximumWidth` / `maximumHeight` | 最大尺寸 | `real` |
| `Layout.rowSpan` / `columnSpan` | 行/列跨度（GridLayout） | `int` |
| `Layout.row` / `column` | 网格坐标（GridLayout） | `int` |
| `Layout.margins` | 统一外边距 | `real` |
| `Layout.topMargin` / `bottomMargin` / `leftMargin` / `rightMargin` | 各边外边距 | `real` |

### 布局类型属性

| 类型 | 属性 | 说明 | 取值规范 |
|------|------|------|----------|
| `RowLayout` / `ColumnLayout` | `spacing` | 元素间距 | `real` |
| `RowLayout` / `ColumnLayout` | `layoutDirection` | 布局方向 | `Qt.LeftToRight`、`Qt.RightToLeft` |
| `GridLayout` | `spacing` | 统一间距 | `real` |
| `GridLayout` | `rowSpacing` / `columnSpacing` | 行/列间距 | `real` |
| `GridLayout` | `flow` | 流动方向 | `GridLayout.LeftToRight`、`TopToBottom` |
| `StackLayout` | `currentIndex` | 当前可见索引 | `int` |

---

## 4.3 QtQuick.Effects

> 提供对 Qt Quick 项目应用后处理效果的 QML 类型。`MultiEffect` 将多种效果合并到单个项目和着色器中，性能优于 Qt Graphical Effects 模块。

**导入语句**：`import QtQuick.Effects`

### 模块速览
- `MultiEffect`：核心类型，支持模糊、阴影、蒙版、着色、亮度、对比度和饱和度七种效果。
- `RectangularShadow`：矩形阴影效果

### MultiEffect 关键属性

| 属性 | 说明 | 取值规范 |
|------|------|----------|
| `source` | 输入源项 | 通过 `id` 引用 |
| `blurEnabled` | 启用模糊 | `true` / `false` |
| `blur` | 模糊程度 | `real`，0~1 |
| `blurMax` | 最大模糊半径 | `int` |
| `colorization` | 着色程度 | `real`，0~1 |
| `colorizationColor` | 着色颜色 | 颜色值 |
| `brightness` | 亮度 | `real`，-1~1，默认0 |
| `contrast` | 对比度 | `real`，0~2，默认1 |
| `saturation` | 饱和度 | `real`，0~2，默认1 |
| `shadowBlur` | 阴影模糊 | `real` |
| `shadowColor` | 阴影颜色 | 颜色值 |
| `shadowHorizontalOffset` / `shadowVerticalOffset` | 阴影偏移 | `real` |
| `maskEnabled` | 启用蒙版 | `true` / `false` |
| `maskSource` | 蒙版源项 | `Item` |
| `autoPaddingEnabled` | 自动内边距（Qt 6 后期版本默认 true） | `true` / `false` |

**RectangularShadow**：
- `source`（Item）
- `color`（color）
- `horizontalOffset` / `verticalOffset`（real）
- `blur`（real）

> 从 Qt 6.5 开始，`QtQuick3D.Effects` 中的独立效果被视为弃用，建议使用 `MultiEffect`。

---

## 4.4 QtQuick.Shapes

> 通过从 `QPainterPath` 三角化几何体来渲染路径。路径永远不会在软件中被光栅化，适合在屏幕大面积区域上创建形状。

**导入语句**：`import QtQuick.Shapes`

### 模块速览
- `Shape`：根容器，包含一个或多个 `ShapePath`
- `ShapePath`：定义形状的路径，包含填充和描边参数
- 路径元素：`PathMove`、`PathLine`、`PathQuad`、`PathCubic`、`PathArc`、`PathText`、`PathSvg`

### 关键属性

**Shape**：

| 属性 | 说明 | 取值规范 |
|------|------|----------|
| `data` | 路径列表 | `list<ShapePath>` |
| `preferredRendererType` | 渲染器类型 | `Shape.GeometryRenderer`、`Shape.CurveRenderer` |
| `asynchronous` | 异步加载 | `true` / `false` |
| `containsMode` | 包含模式 | `Shape.BoundingRectContains`、`Shape.FillContains` |

**ShapePath**：

| 属性 | 说明 | 取值规范 |
|------|------|----------|
| `path` | 路径数据 | `Path { ... }` |
| `fillColor` | 填充颜色 | 颜色值 |
| `fillGradient` | 渐变填充 | `Gradient { ... }` |
| `strokeColor` | 描边颜色 | 颜色值 |
| `strokeWidth` | 描边宽度 | `real` |
| `joinStyle` | 连接样式 | `ShapePath.MiterJoin`、`BevelJoin`、`RoundJoin` |
| `capStyle` | 端点样式 | `ShapePath.FlatCap`、`SquareCap`、`RoundCap` |
| `fillRule` | 填充规则 | `ShapePath.OddEvenFill`、`WindingFill` |
| `dashPattern` | 虚线模式 | `list<real>`，如 `[2, 4]` |
| `dashOffset` | 虚线偏移 | `real` |

---

## 4.5 QtQuick.Particles

> 提供 Qt Quick 的粒子系统。包含四种主要类型的 QML 类型：`ParticleSystem`、绘制器（Painters）、发射器（Emitters）和影响器（Affectors）。

**导入语句**：`import QtQuick.Particles`

### 模块速览
- `ParticleSystem`：粒子系统根，管理共享时间线
- **发射器**：`Emitter`（基本发射器）、`BurstEmitter`（爆发式发射器）
- **绘制器**：`ImageParticle`（使用图像绘制）、`ItemParticle`（使用委托绘制）
- **影响器**：`Age`、`Attractor`、`Friction`、`Gravity`、`Turbulence`、`Wander`

### 关键属性

| 类型 | 属性 | 说明 | 取值规范 |
|------|------|------|----------|
| `ParticleSystem` | `running` | 是否运行 | `true` / `false` |
| `Emitter` | `emitRate` | 每秒发射粒子数 | `int` |
| `Emitter` | `lifeSpan` | 粒子生命周期（毫秒） | `real` |
| `Emitter` | `lifeSpanVariation` | 生命周期变化量 | `real` |
| `Emitter` | `size` | 粒子大小 | `real` |
| `Emitter` | `velocity` | 初始速度方向 | `AngleDirection { ... }`、`PointDirection { ... }` 等 |
| `ImageParticle` | `source` | 图像源 | `url` |
| `ImageParticle` | `color` / `colorVariation` | 颜色及变化 | `color` / `real` |
| `ImageParticle` | `rotationVelocity` | 旋转速度 | `real` |
| `Age` | `lifeLeft` | 减少后的剩余生命 | `real` |
| `Attractor` | `pointX` / `pointY` | 吸引点坐标 | `real` |
| `Attractor` | `strength` | 吸引力强度 | `real` |
| `Friction` | `factor` / `threshold` | 摩擦系数/阈值 | `real` |
| `Gravity` | `angle` / `magnitude` | 角度/大小 | `real` |
| `Turbulence` | `strength` | 湍流强度 | `real` |
| `Wander` | `xVariance` / `yVariance` | 随机游走方差 | `real` |

---

## 4.6 QtQuick.LocalStorage

> 提供与 Web 浏览器类似的本地存储 API，将内容存储到系统特定位置的 SQLite 数据库中。

**导入语句**：`import QtQuick.LocalStorage`

### 核心 API

`LocalStorage` 是单例类型，提供 `openDatabaseSync()` 方法：

```qml
var db = LocalStorage.openDatabaseSync(identifier, version, description, estimated_size, callback)
```

| 参数 | 说明 | 取值规范 |
|------|------|----------|
| `identifier` | 数据库名称 | `string` |
| `version` | 版本号 | `string` |
| `description` | 描述 | `string` |
| `estimated_size` | 预估大小（字节） | `int` |
| `callback` | 回调函数（可选） | `function` |

**数据库对象方法**：
- `db.transaction(function(tx) { ... })`：创建事务
- `tx.executeSql(sql, params)`：执行 SQL 查询

---

## 4.7 QtTest

> QML 应用程序的单元测试框架。

**导入语句**：`import QtTest`

### 模块速览
- `TestCase`：测试用例容器，以 `test_` 开头的函数自动成为测试用例
- `SignalSpy`：监听信号发射

### 核心 API

**TestCase**：
- `compare(actual, expected)`：比较值
- `verify(condition)`：验证条件
- `wait(ms)`：等待指定毫秒
- `waitForSignal(target, signal, timeout)`：等待信号发射
- `tryCompare(actual, property, expected, timeout)`：尝试比较属性

**SignalSpy**：

| 属性 | 说明 | 取值规范 |
|------|------|----------|
| `target` | 目标对象 | 通过 `id` 引用 |
| `signalName` | 信号名称 | `string` |
| `count` | 信号发射次数（只读） | — |
| `valid` | 是否有效（只读） | — |

---

## 4.8 QtQuick.VectorImage

> 加载矢量图像文件（目前支持 SVG 格式）并将其显示为 Qt Quick 场景中的项目。

**导入语句**：`import QtQuick.VectorImage`（Qt 6.8+ 引入）

### 与 Image 的区别
- `Image`：在请求的尺寸上创建图像的光栅版本
- `VectorImage`：构建代表图像的 Qt Quick 场景，缩放/旋转不降质，内存占用更少

### 关键属性

| 属性 | 说明 | 取值规范 |
|------|------|----------|
| `source` | 矢量文件 URL | `url`（支持 SVG） |
| `fillMode` | 填充模式 | `VectorImage.NoResize`、`Stretch`、`PreserveAspectFit`、`PreserveAspectCrop` |
| `preferredRendererType` | 渲染器类型 | `VectorImage.GeometryRenderer`、`CurveRenderer` |
| `assumeTrustedSource` | 启用 Lottie 支持 | `true` / `false` |


# 五、Qt Quick 扩展模块

## 5.1 Qt Quick 3D 三维图形模块

> Qt Quick 3D 为 QML 提供了高性能的 3D 渲染能力，使开发者能够创建丰富的 3D 用户界面。

### 5.1.1 QtQuick3D 核心模块

**导入语句**：`import QtQuick3D`

**模块速览**：
- `Object3D`：所有 3D 类型的基类
- `Node`：3D 场景中的空间节点（相当于 2D 中的 `Item`）
- `View3D`：渲染 3D 场景的 2D 表面
- `Model`：加载和显示 3D 模型
- `Camera`：相机（`PerspectiveCamera`、`OrthographicCamera`）
- `Light`：光源（`DirectionalLight`、`PointLight`、`SpotLight`）
- `Material`：材质基类
- `PrincipledMaterial`：基于物理渲染（PBR）的材质
- `Texture`：纹理
- `Geometry`：自定义几何体

**子模块**：
- `QtQuick3D.Helpers`：辅助工具（轴线网格、胶囊/圆锥/长方体/圆柱/球体/环面等基础几何体、调试视图、挤出文本、LOD 管理器）
- `QtQuick3D.Particles3D`：3D 粒子系统
- `QtQuick3D.Xr`：XR/VR 应用支持（Qt 6.8 引入）

### 关键属性

| 类型 | 属性 | 说明 | 取值规范 |
|------|------|------|----------|
| `View3D` | `camera` | 场景相机 | 通过 `id` 引用 |
| `View3D` | `environment` | 场景环境 | `SceneEnvironment { ... }` |
| `View3D` | `importScene` | 导入 3D 场景文件 | `url` |
| `Node` | `position` | 3D 位置 | `Qt.vector3d(x, y, z)` |
| `Node` | `rotation` | 旋转（四元数） | `Qt.quaternion()` |
| `Node` | `eulerRotation` | 旋转（欧拉角） | `Qt.vector3d(x, y, z)` |
| `Node` | `scale` | 缩放 | `Qt.vector3d(x, y, z)` |
| `Node` | `opacity` | 不透明度 | `real`，0.0~1.0 |
| `Node` | `visible` | 是否可见 | `true` / `false` |
| `Model` | `source` | 模型文件 URL | `url`（支持 `.mesh`、`.gltf` 等） |
| `Model` | `materials` | 材质列表 | `[Material { ... }]` |
| `Model` | `geometry` | 几何体 | `Geometry` 实例 |
| `PerspectiveCamera` | `fieldOfView` | 视场角 | `real` |
| `PerspectiveCamera` | `clipNear` / `clipFar` | 近/远裁剪面 | `real` |
| `OrthographicCamera` | `horizontalMagnification` / `verticalMagnification` | 放大倍数 | `real` |
| `DirectionalLight` | `color` / `brightness` | 颜色/亮度 | 颜色值 / `real` |
| `PointLight` | `constantFade` / `linearFade` / `quadraticFade` | 衰减系数 | `real` |
| `PrincipledMaterial` | `baseColor` | 基础颜色 | 颜色值 |
| `PrincipledMaterial` | `metalness` | 金属度 | `real`，0~1 |
| `PrincipledMaterial` | `roughness` | 粗糙度 | `real`，0~1 |

### 5.1.2 QtQuick3D.Physics 物理模块

**导入语句**：`import QtQuick3D.Physics`（从 Qt 6.5 起不再处于技术预览阶段）

**模块速览**：
- `PhysicsWorld`：物理世界
- `StaticRigidBody`：静态刚体
- `DynamicRigidBody`：动态刚体
- `CharacterController`：角色控制器
- 碰撞体：`BoxCollisionShape`、`SphereCollisionShape`、`PlaneCollisionShape`、`MeshCollisionShape`、`HeightMapCollisionShape`
- 关节：`FixedJoint`、`DistanceJoint`、`PrismaticJoint`、`RevoluteJoint`、`SphericalJoint`
- `PhysicsMaterial`：物理材质
- `TriggerVolume`：触发体积

### 关键属性

| 类型 | 属性 | 说明 | 取值规范 |
|------|------|------|----------|
| `PhysicsWorld` | `gravity` | 重力 | `Qt.vector3d(x, y, z)` |
| `PhysicsWorld` | `enabled` | 启用物理 | `true` / `false` |
| `DynamicRigidBody` | `mass` | 质量 | `real` |
| `DynamicRigidBody` | `linearVelocity` / `angularVelocity` | 速度 | `Qt.vector3d` |
| `PhysicsMaterial` | `staticFriction` / `dynamicFriction` | 静/动摩擦系数 | `real` |
| `PhysicsMaterial` | `restitution` | 回弹系数 | `real`，0~1 |
| `BoxCollisionShape` | `extents` | 尺寸 | `Qt.vector3d` |
| `SphereCollisionShape` | `radius` | 半径 | `real` |
| `TriggerVolume` | `onEntered` / `onExited` | 进入/退出信号 | — |

---

## 5.2 Qt Quick Timeline 关键帧动画模块

> 支持基于关键帧的动画和参数化控制，由 Qt Design Studio 和 Qt Quick Designer 直接支持。

**导入语句**：`import QtQuick.Timeline`

### 模块速览

**核心概念**：
- `Timeline`：时间轴容器，包含关键帧组
- `KeyframeGroup`：关键帧组，包含特定对象和属性的关键帧列表
- `Keyframe`：关键帧，定义特定帧位置的属性值
- `TimelineAnimation`：附加到时间轴的数值动画

### 关键属性

| 类型 | 属性 | 说明 | 取值规范 |
|------|------|------|----------|
| `Timeline` | `currentFrame` | 当前帧位置 | `real` |
| `Timeline` | `startFrame` / `endFrame` | 起止帧 | `real` |
| `Timeline` | `enabled` | 是否启用 | `true` / `false` |
| `Timeline` | `keyframes` | 关键帧组列表 | `[KeyframeGroup { ... }]` |
| `Timeline` | `animations` | 附加动画列表 | `[TimelineAnimation { ... }]` |
| `KeyframeGroup` | `target` | 目标对象 | 通过 `id` 引用 |
| `KeyframeGroup` | `property` | 目标属性名 | `string` |
| `Keyframe` | `frame` | 帧位置 | `real` |
| `Keyframe` | `value` | 属性值 | 必须匹配目标属性的数据类型 |
| `Keyframe` | `easing` | 缓动曲线 | 缓动类型 |
| `TimelineAnimation` | `from` / `to` | 起止帧 | `real` |
| `TimelineAnimation` | `duration` | 时长（毫秒） | `int` |
| `TimelineAnimation` | `easing` | 缓动曲线 | — |

### BlendTrees 混合树子模块（Qt 6.7+）

`import QtQuick.Timeline.BlendTrees`

- `BlendAnimationNode`：混合树节点，在两个动画源之间混合
- `TimelineAnimationNode`：播放时间轴动画的源节点
- `BlendTreeNode`：所有混合树节点的基类


# 六、属性值取值规范（完整）

> QML 属性值的赋值遵循统一的语法规则：`属性名: 值`。冒号右侧的“值”可以是以下形式之一。

## 6.1 字面量

最基本的取值形式，直接写出值的字面表示。

**数值字面量（int / real / double）**：
```qml
width: 100          // int，整数
opacity: 0.75       // real，浮点数
scale: 3.14         // real
```
- 整数：`0`、`10`、`-20`
- 浮点数：`3.14`、`-0.5`、`.25`

**布尔字面量（bool）**：
```qml
visible: true
enabled: false
clip: true
```
- 只能是 `true` 或 `false`（小写）

**字符串字面量（string）**：
```qml
text: "Hello World"
title: "我的应用"
```
- 使用双引号 `" "` 包裹，支持 Unicode 字符

**URL 字面量（url）**：
```qml
source: "image.png"
source: "https://example.com/logo.jpg"
```
- 本质是字符串，使用双引号包裹
- 可以是本地相对路径、绝对路径或网络 URL

## 6.2 属性绑定

属性值可以是一个 **JavaScript 表达式**，当表达式中引用的任何依赖属性发生变化时，该属性会自动重新求值并更新。

```qml
width: parent.width / 2
height: Math.min(parent.width, parent.height)
color: condition ? "red" : "blue"
x: {
    if (parent.width > 200)
        return 50
    else
        return 10
}
```

**绑定表达式可以包含**：
- 属性引用（`parent.width`、`otherItem.height`）
- 算术运算（`+`、`-`、`*`、`/`）
- 逻辑运算（`&&`、`||`、`!`）
- 比较运算（`>`、`<`、`==`、`!=`）
- 三元条件（`? :`）
- 函数调用（`Math.min()`、自定义方法）
- 内置 JavaScript 对象（`Date`、`Math`）

> **重要规则**：`属性: 表达式` 建立的是**永久绑定**。如果在 JavaScript 代码块中使用 `属性 = 值` 赋值，则会**破坏绑定**，转为静态值。

## 6.3 枚举值

枚举值使用 `<类型名>.<枚举值>` 的格式引用。

```qml
horizontalAlignment: Text.AlignRight
echoMode: TextInput.Password
fillMode: Image.PreserveAspectFit
snapMode: Slider.SnapOnRelease
```
- 枚举值是其所处类型的属性，不是独立类型
- 在 QML 中，枚举值以 `Number` 或 `double` 类型存储

## 6.4 颜色值

颜色属性接受多种格式：

```qml
color: "red"                    // SVG 颜色名称
color: "#FF0000"               // 十六进制 RGB
color: "#FF0000FF"             // 十六进制 ARGB（Qt 6+）
color: Qt.rgba(1, 0, 0, 0.5)   // Qt.rgba() 函数
color: Qt.hsva(0, 1, 1, 1)     // Qt.hsva() 函数
color: "transparent"           // 透明
```

**支持的颜色指定方式**：
- SVG 颜色名称：`"red"`、`"green"`、`"lightsteelblue"` 等
- 十六进制：`"#RRGGBB"` 或 `"#AARRGGBB"`
- Qt 全局对象函数：`Qt.rgba()`、`Qt.hsva()`、`Qt.hsla()`、`Qt.darker()`、`Qt.lighter()`、`Qt.tint()`

## 6.5 字体值

`font` 是一个**分组属性**，包含多个子属性，通过 `font.` 前缀访问：

```qml
font.family: "Arial"
font.pixelSize: 14
font.bold: true
font.italic: false
font.underline: true
font.capitalization: Font.AllUppercase
```

`font` 类型属性的默认值为应用程序的默认字体。从 C++ 传入的 `QFont` 值会自动转换为 QML 的 `font` 值。

## 6.6 矩形值

`rect` 值类型包含 `x`、`y`、`width`、`height` 四个属性：

```qml
cursorRectangle: Qt.rect(0, 0, 20, 20)
sourceClipRect: "0, 0, 100 x 100"    // 字符串格式（不推荐）
```
- 默认值为 `Qt.rect(0, 0, 0, 0)`

## 6.7 尺寸值

```qml
sourceSize: Qt.size(100, 200)
```

## 6.8 点值

```qml
somePoint: Qt.point(50, 100)
```

## 6.9 对象实例

属性值可以是一个 QML 对象的实例或引用：

```qml
parent: rootItem
background: rectBg
target: animationTarget
contentItem: myCustomContent
```
- 对象的 `id` 可以在同一文档中作为值引用
- 属性类型必须与赋值对象类型兼容

## 6.10 列表值

`list` 类型使用方括号 `[ ]` 语法，元素用逗号分隔：

```qml
states: [
    State { name: "normal" },
    State { name: "pressed" }
]
transitions: [
    Transition { from: "normal"; to: "pressed" }
]
children: [ rect1, rect2, rect3 ]
```
- `length` 属性返回列表项数量
- 使用 `[index]` 语法访问列表值
- 可使用 `push()` 方法添加条目

## 6.11 var 类型

`var` 属性可以容纳**任何类型的值**：

```qml
property var anything: 42
property var message: "Hello"
property var flag: true
property var data: { name: "John", age: 30 }
property var empty: null
```

**特殊注意事项**：
- 右侧的 `{}` 表示**绑定赋值**，而非空对象
- 若要初始化 `var` 属性为空对象，必须用括号包裹：`property var emptyObject: ({})`
- 如果花括号被解释为表达式块，可能导致意外行为

## 6.12 空值 / undefined

某些属性可以使用特殊值：

```qml
PropertyChanges {
    target: myText
    width: undefined   // 重置为默认/隐式宽度
}
```

## 6.13 附加属性值

附加属性的值遵循 `<附加类型>.<属性名>` 的格式：

```qml
ListView.isCurrentItem: true
Layout.fillWidth: true
Layout.alignment: Qt.AlignCenter
Keys.onPressed: { /* 处理键盘事件 */ }
```

## 6.14 取值规范速查总表

| 属性类型 | 取值示例 | 说明 |
|----------|----------|------|
| `int` | `42`、`-10`、`0` | 整数，32位有符号 |
| `real` / `double` | `3.14`、`-0.5`、`.25` | 浮点数 |
| `bool` | `true`、`false` | 布尔值 |
| `string` | `"Hello"`、`"文本"` | 双引号字符串 |
| `url` | `"image.png"` | 字符串形式的 URL |
| `color` | `"red"`、`"#FF0000"`、`Qt.rgba(1,0,0,1)` | SVG名称/十六进制/Qt函数 |
| `font` | `font.family: "Arial"` | 分组属性 |
| `rect` | `Qt.rect(0,0,100,100)` | Qt.rect() 构造 |
| `size` | `Qt.size(100,200)` | Qt.size() 构造 |
| `point` | `Qt.point(10,20)` | Qt.point() 构造 |
| `list` | `[item1, item2]` | 方括号，逗号分隔 |
| `var` | 任意 JS 值 | 通用类型 |
| `enumeration` | `Text.AlignRight` | `<类型名>.<枚举值>` |
| 对象引用 | `otherItem.id` | 通过 id 引用 |
| 绑定表达式 | `parent.width / 2` | JavaScript 表达式 |
| `undefined` | `undefined` | 重置属性值 |

## 6.15 取值规范核心要点

1. **字面量**：直接写出值（数字、字符串、布尔、颜色名称等）
2. **属性绑定**：使用 JavaScript 表达式，自动追踪依赖并更新
3. **枚举值**：`<类型名>.<枚举值>` 格式
4. **对象引用**：通过 `id` 引用同一文档中的其他对象
5. **列表**：方括号 `[ ]` 语法，逗号分隔
6. **`var` 类型**：可容纳任意值，注意 `{}` 的二义性
7. **`undefined`**：可用于重置属性到默认值


# 七、QML 值类型一览表

| 值类型 | 说明 | 构造语法 |
|------|------|----------|
| `bool` | 布尔值 | `true` / `false` |
| `int` | 整数 | `42` |
| `real` | 浮点数 | `3.14` |
| `double` | 双精度浮点数 | `3.14159` |
| `string` | 字符串 | `"Hello"` |
| `url` | URL | `"https://..."` |
| `color` | 颜色 | `"red"` / `"#FF0000"` / `Qt.rgba(1,0,0,1)` |
| `font` | 字体 | `Qt.font({family:"Arial", pixelSize:12})` |
| `rect` | 矩形（x, y, width, height） | `Qt.rect(0, 0, 100, 100)` |
| `point` | 点（x, y） | `Qt.point(10, 20)` |
| `size` | 尺寸（width, height） | `Qt.size(100, 200)` |
| `vector2d` / `vector3d` / `vector4d` | 向量 | `Qt.vector2d(1, 2)` |
| `quaternion` | 四元数 | `Qt.quaternion(1, 0, 0, 0)` |
| `matrix4x4` | 4x4 矩阵 | `Qt.matrix4x4()` |
| `list` | 列表 | `[item1, item2, item3]` |
| `var` | 任意类型（通用） | 任意值 |
| `enumeration` | 枚举值 | `Qt.AlignCenter` |

**list 类型的特殊语法**：
- `length` 属性提供列表项数量
- 使用 `[index]` 语法访问列表值
- 使用 `push()` 方法添加条目
- 可设置 `length` 属性来截断或扩展列表


# 八、常用组件对照速查表

| 功能需求 | QML 方案 | HTML 方案 |
|----------|----------|-----------|
| 块级容器 | `Item` / `Rectangle` | `<div>` |
| 文本显示 | `Text` / `Label` | `<span>` / `<p>` |
| 图片显示 | `Image` | `<img>` |
| 按钮 | `Button` | `<button>` |
| 单行输入 | `TextInput` / `TextField` | `<input type="text">` |
| 多行输入 | `TextEdit` / `TextArea` | `<textarea>` |
| 复选框 | `CheckBox` | `<input type="checkbox">` |
| 单选按钮 | `RadioButton` | `<input type="radio">` |
| 下拉选择 | `ComboBox` | `<select>` |
| 滑块 | `Slider` | `<input type="range">` |
| 进度条 | `ProgressBar` | `<progress>` |
| 列表 | `ListView` | 动态 `<ul>` / `<ol>` |
| 网格 | `GridView` | 动态 CSS Grid |
| 表格 | `TableView` | `<table>` |
| 对话框 | `Dialog` | `<dialog>` |
| 菜单 | `Menu` | `<menu>` |
| 鼠标事件 | `MouseArea` | `onclick` / `onmouseover` |
| 动画 | `PropertyAnimation` | CSS `transition` / `@keyframes` |
| 画布 | `Canvas` | `<canvas>` |
| 定时器 | `Timer` | `setTimeout` / `setInterval` |
| 顶层窗口 | `Window` / `ApplicationWindow` | — |


> **结束语**：本文档完整整合了 Qt 6 QML 及 Qt Quick 框架的所有核心内容，涵盖语言规范、所有核心组件属性、8 大子模块、3D 与 Timeline 扩展模块、完整的取值规范、值类型一览表及常用对照速查表，适合作为开发过程中的完整参考手册，而非简易速查。参考自 Qt 6 官方文档（doc.qt.io）。