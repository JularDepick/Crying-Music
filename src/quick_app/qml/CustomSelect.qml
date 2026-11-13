import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic

import "./"

/* 复用下拉选择: 控件本身只显示当前值, 点开后在浮层里列出全部候选;
 * 候选可能上百条(系统字体清单), 因此列表固定高度并可滚动;
 * 文本一律水平居中, 与其它控件的文字对齐口径一致 */
Item {
    id: root;
    /* 候选: [{label,value}] */
    property var options: [];
    /* 当前选中的值 */
    property var currentValue: "";
    /* 控件尺寸与下拉列表的最大高度 */
    property int controlWidth: 260;
    property int controlHeight: 32;
    property int listMaxHeight: 280;
    /* 当前值对应的下标, 未命中为 -1 */
    readonly property int currentIndex: indexOfValue(currentValue);
    /* 选择一个候选时发出 */
    signal chosen(var value, int index);
    implicitWidth: controlWidth;
    implicitHeight: controlHeight;

    function optionCount() {
        return (Array.isArray(options)? options.length:0);
    }
    function labelOf(i) {
        var o=options[i];
        if(o===undefined || o===null) {
            return "";
        }
        return (typeof o==="object"? String(o["label"]):String(o));
    }
    function valueOf(i) {
        var o=options[i];
        if(o===undefined || o===null) {
            return "";
        }
        return (typeof o==="object"? o["value"]:o);
    }
    function indexOfValue(v) {
        var n=optionCount();
        for(var i=0;i<n;i++) {
            if(String(valueOf(i))===String(v)) {
                return i;
            }
        }
        return -1;
    }
    /* 控件上显示的文字: 值不在候选里时原样显示, 免得看起来像没设置 */
    function currentLabel() {
        var i=currentIndex;
        if(i>=0) {
            return labelOf(i);
        }
        return String(currentValue===undefined || currentValue===null? "":currentValue);
    }

    Rectangle {
        id: box;
        width: root.controlWidth;
        height: root.controlHeight;
        radius: 8;
        color: (boxHover.hovered? Define.choseDarkColor:Define.hoverDarkColor);
        Text {
            anchors.centerIn: parent;
            width: parent.width-20;
            horizontalAlignment: Text.AlignHCenter;
            elide: Text.ElideRight;
            text: root.currentLabel();
            font.pixelSize: 13;
            color: Define.textColor;
        }
        HoverHandler {
            id: boxHover;
        }
        TapHandler {
            onSingleTapped: {
                pop.open();
            }
        }
    }
    Popup {
        id: pop;
        x: 0;
        y: box.height+4;
        width: root.controlWidth;
        height: Math.min(root.listMaxHeight,list.contentHeight+8);
        padding: 4;
        closePolicy: Popup.CloseOnPressOutside|Popup.CloseOnEscape;
        background: Rectangle {
            radius: 8;
            color: Define.mainAreaColor;
            border.width: 0.5;
            border.color: Define.subGrey;
        }
        contentItem: ListView {
            id: list;
            clip: true;
            model: root.options;
            boundsBehavior: Flickable.StopAtBounds;
            ScrollBar.vertical: ScrollBar {
                width: 4;
                policy: ScrollBar.AsNeeded;
            }
            delegate: Item {
                width: list.width;
                height: 28;
                Rectangle {
                    anchors.fill: parent;
                    anchors.margins: 1;
                    radius: 6;
                    color: (rowHover.hovered? Define.hoverDarkColor:Define.nocolor);
                }
                Text {
                    anchors.centerIn: parent;
                    width: parent.width-16;
                    horizontalAlignment: Text.AlignHCenter;
                    elide: Text.ElideRight;
                    text: root.labelOf(index);
                    font.pixelSize: 13;
                    color: (index===root.currentIndex? Define.choseCyanColor:Define.textColor);
                }
                HoverHandler {
                    id: rowHover;
                }
                TapHandler {
                    onSingleTapped: {
                        root.chosen(root.valueOf(index),index);
                        pop.close();
                    }
                }
            }
        }
        onOpened: {
            list.positionViewAtIndex(Math.max(0,root.currentIndex),ListView.Center);
        }
    }
}
