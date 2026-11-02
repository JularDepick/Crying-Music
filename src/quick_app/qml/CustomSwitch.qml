import QtQuick

import "./"

/* 复用开关控件: 一条圆角轨道加一个滑动的圆点, 点击即切换;
 * checked 由使用方持有并绑定, 切换后只发出 toggled(checked), 使用方写回自己的状态;
 * 本控件不自行改写 checked, 避免破坏使用方在 checked 上的绑定 */
Item {
    id: root;
    /* 当前开关状态 */
    property bool checked: false;
    /* 切换时发出: 参数是切换后的状态 */
    signal toggled(bool checked);
    implicitWidth: 44;
    implicitHeight: 24;
    Rectangle {
        id: track;
        anchors.fill: parent;
        radius: height/2;
        color: (root.checked? Define.choseCyanColor:Define.forbdDarkColor);
        Behavior on color {
            ColorAnimation { duration: 120; }
        }
        Rectangle {
            id: knob;
            width: parent.height-4;
            height: parent.height-4;
            radius: width/2;
            y: 2;
            x: (root.checked? track.width-width-2:2);
            color: "white";
            Behavior on x {
                NumberAnimation { duration: 120; }
            }
        }
    }
    MouseArea {
        anchors.fill: parent;
        cursorShape: Qt.PointingHandCursor;
        onClicked: {
            root.toggled(!root.checked);
        }
    }
}
