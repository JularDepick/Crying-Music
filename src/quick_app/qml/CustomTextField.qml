import QtQuick
import QtQuick.Controls.Basic

import "./"

/* 单行输入框: 表单里通用的一档样式, 底色与按钮常态同为一档亮灰,
 * 聚焦时只换描边颜色, 不换底色; 圆角与按钮同一半径 */
TextField {
    id: root;
    height: 36;
    font.pixelSize: 14;
    color: Define.textColor;
    placeholderTextColor: Define.btnIconColor;
    selectByMouse: true;
    leftPadding: 12;
    rightPadding: 12;
    selectionColor: Define.choseCyanColor;
    selectedTextColor: "white";
    background: Rectangle {
        anchors.fill: parent;
        radius: 8;
        color: Define.hoverDarkColor;
        border.width: 1;
        border.color: (root.activeFocus? Define.choseCyanColor:Define.subGrey);
    }
}
