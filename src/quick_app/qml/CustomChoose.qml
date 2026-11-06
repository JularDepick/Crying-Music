import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic

import "./"

/* 复用换挡控件: 一组原生单选按钮, 自带与应用一致的样式;
 * options 支持 [{label,value}] 或字符串数组(字符串数组的值即字符串本身);
 * currentValue 由使用方持有, 选择后发出 chosen(value,index), 使用方写回自己的状态 */
Item {
    id: root;
    /* 选项数组 */
    property var options: [];
    /* 当前选中的值: 与任何选项都不相等时全部不选中 */
    property var currentValue: "";
    /* 当前选中的下标, 未命中任何选项时为 -1 */
    readonly property int currentIndex: indexOfValue(currentValue);
    /* 选择一个选项时发出 */
    signal chosen(var value, int index);
    implicitWidth: optionsRow.width;
    implicitHeight: (optionsRow.height>0? optionsRow.height:24);
    /* 原生单选组: 互斥由它负责, 外部改值时由 syncChecks 回推 */
    ButtonGroup {
        id: group;
        exclusive: true;
    }
    Row {
        id: optionsRow;
        spacing: 22;
        Repeater {
            id: optionsRepeater;
            model: root.options;
            delegate: RadioButton {
                id: optionItem;
                text: root.labelOf(index);
                font.pixelSize: 14;
                font.weight: 400;
                spacing: 6;
                padding: 0;
                topPadding: 0;
                bottomPadding: 0;
                ButtonGroup.group: group;
                contentItem: Text {
                    text: optionItem.text;
                    font: optionItem.font;
                    color: ((optionItem.checked||optionItem.hovered)? Define.choseCyanColor:Define.textColor);
                    verticalAlignment: Text.AlignVCenter;
                    leftPadding: optionItem.indicator.width+optionItem.spacing;
                }
                indicator: Rectangle {
                    implicitWidth: 16;
                    implicitHeight: 16;
                    x: optionItem.leftPadding;
                    y: optionItem.height/2-height/2;
                    radius: width/2;
                    border.width: 1.2;
                    border.color: (optionItem.checked? Define.choseCyanColor:Define.subGrey);
                    color: Define.nocolor;
                    Rectangle {
                        anchors.centerIn: parent;
                        width: parent.width*0.5;
                        height: parent.height*0.5;
                        radius: width/2;
                        color: Define.choseCyanColor;
                        visible: optionItem.checked;
                    }
                }
                onClicked: {
                    root.chosen(root.valueOf(index), index);
                }
            }
        }
    }
    /* 选项数量 */
    function optionCount() {
        return (Array.isArray(options)? options.length:0);
    }
    /* 第 i 个选项的显示文字 */
    function labelOf(i) {
        var o=options[i];
        if(o===undefined || o===null) {
            return "";
        }
        return (typeof o==="object"? String(o["label"]):String(o));
    }
    /* 第 i 个选项的值 */
    function valueOf(i) {
        var o=options[i];
        if(o===undefined || o===null) {
            return "";
        }
        return (typeof o==="object"? o["value"]:o);
    }
    /* 值对应的下标, 未命中返回 -1 */
    function indexOfValue(v) {
        var n=optionCount();
        for(var i=0;i<n;i++) {
            if(String(valueOf(i))===String(v)) {
                return i;
            }
        }
        return -1;
    }
    /* 把勾选状态同步到 currentValue: 原生单选组只负责点击互斥, 外部改值后要回推 */
    function syncChecks() {
        var target=indexOfValue(root.currentValue);
        var n=optionsRepeater.count;
        for(var i=0;i<n;i++) {
            var it=optionsRepeater.itemAt(i);
            if(it!==null) {
                var want=(i===target);
                if(it.checked!==want) {
                    it.checked=want;
                }
            }
        }
    }
    onCurrentValueChanged: syncChecks();
    onOptionsChanged: syncChecks();
    Component.onCompleted: syncChecks();
}
