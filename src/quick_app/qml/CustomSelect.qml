import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic

import "./"

/* 复用下拉选择: 触发按钮只显示当前值, 点开后在浮层里列出全部候选;
 * 按钮宽度跟随当前选项的文字宽度(有上下限), 因此选中短名字不会留一大片空白;
 * 候选可能上百条(系统字体清单), 列表固定高度, 右侧用与列表页同一款 4px 细滚动条承接快速滚动;
 * 控件与列表的文本一律水平居中 */
Item {
    id: root;
    /* 候选: [{label,value}] */
    property var options: [];
    /* 当前选中的值 */
    property var currentValue: "";
    /* 触发按钮的宽度上下限, 控件高度, 下拉列表的最大高度 */
    property int minWidth: 88;
    property int maxWidth: 260;
    property int controlHeight: 32;
    property int listMaxHeight: 280;
    /* 当前值对应的下标, 未命中为 -1 */
    readonly property int currentIndex: indexOfValue(currentValue);
    /* 触发按钮宽度: 跟随当前文案, 受上下限约束 */
    readonly property real triggerWidth: Math.min(maxWidth,
                                                  Math.max(minWidth,labelMetrics.advanceWidth+28));
    /* 下拉列表宽度: 至少与触发按钮同宽, 但不小于一个便于阅读的最小值 */
    readonly property real popupWidth: Math.max(triggerWidth,Math.min(maxWidth,200));
    /* 选择一个候选时发出 */
    signal chosen(var value, int index);
    implicitWidth: triggerWidth;
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

    /* 当前文案的宽度: 触发按钮按它自适应 */
    TextMetrics {
        id: labelMetrics;
        font.pixelSize: 13;
        text: root.currentLabel();
    }

    Rectangle {
        id: box;
        width: root.triggerWidth;
        height: root.controlHeight;
        radius: 8;
        color: (boxHover.hovered? Define.choseDarkColor:Define.hoverDarkColor);
        Text {
            anchors.centerIn: parent;
            width: parent.width-16;
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
        width: root.popupWidth;
        height: Math.min(root.listMaxHeight,list.contentHeight+8);
        padding: 4;
        closePolicy: Popup.CloseOnPressOutside|Popup.CloseOnEscape;
        background: Rectangle {
            radius: 8;
            color: Define.mainAreaColor;
            border.width: 0.5;
            border.color: Define.subGrey;
        }
        contentItem: Item {
            ListView {
                id: list;
                anchors.fill: parent;
                anchors.rightMargin: 8;
                clip: true;
                model: root.options;
                boundsBehavior: Flickable.StopAtBounds;
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
            /* 与列表页同一款细滚动条: 拖动与滚轮同源, 内容不超出时隐藏 */
            CustomSliderC {
                id: listBar;
                anchors {top:list.top; bottom:list.bottom; right:parent.right;}
                width: 4;
                visible: (list.contentHeight>list.height);
                handleRatio: Math.max(0.1,list.height/Math.max(1,list.contentHeight));
                hoverHandlerEnabled: false;
                value: from*(list.contentY/Math.max(1,list.contentHeight-list.height));
                onMoved: {
                    list.contentY=(value/from)*Math.max(0,list.contentHeight-list.height);
                    value=Qt.binding(function() {
                        return from*(list.contentY/Math.max(1,list.contentHeight-list.height));
                    });
                }
            }
        }
        onOpened: {
            list.positionViewAtIndex(Math.max(0,root.currentIndex),ListView.Center);
        }
    }
}
