import QtQuick
import QtQuick.Controls
import "./"

/* 竖向细滚动条: from/to 取 100 -> 0 使滑块随数值增大而向下, 使用方按内容比例换算 value */
Slider {
    id: root;
    orientation: Qt.Vertical;
    width: 4;
    from: 100;
    to: 0;
    stepSize: 1;
    value: 0;
    padding: 0;
    /* 滑块高度占控件高度的比例, 由使用方按可视比例设置 */
    property real handleRatio: 0.15;
    /* 是否启用指针手型光标 */
    property bool hoverHandlerEnabled: true;
    background: Rectangle {
        x: 0;
        y: 0;
        width: root.width;
        height: root.height;
        radius: 2;
        color: Define.mainAreaColor;
    }
    handle: Rectangle {
        x: 0;
        y: ((root.value-root.to)/(root.from-root.to))*(root.height-height);
        width: root.width;
        height: root.height*root.handleRatio;
        radius: 2;
        color: (hovered||pressed? Define.choseDarkColor:Define.subGrey);
        HoverHandler {
            enabled: (root.enabled && root.hoverHandlerEnabled);
            cursorShape: Qt.PointingHandCursor;
        }
    }
}