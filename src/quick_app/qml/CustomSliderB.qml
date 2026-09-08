import QtQuick
import QtQuick.Controls
import "./"

Slider {
    orientation: Qt.Vertical;
    width: 30;
    height: parent.height-20;
    from: 0;
    to: 100;
    stepSize: 1;
    value: 0;
    background: Rectangle {
        x: parent.leftPadding+(parent.availableWidth-width)/2;
        y: parent.topPadding;
        width: 4;
        height: parent.availableHeight;
        radius: 2;
        color: Define.hoverDarkColor;
        Rectangle {
            width: parent.width;
            height: (parent.parent.value/parent.parent.to)*parent.height;
            y: parent.height-height;
            radius: parent.radius;
            color: Define.btnIconColor;
        }
    }
    handle: Rectangle {
        x: parent.leftPadding+(parent.availableWidth-width)/2;
        y: parent.topPadding+(1-parent.value/parent.to)*parent.availableHeight-height/2;
        width: 14;
        height: 14;
        radius: 7;
        color: Define.btnIconColor;
        border.color: "white";
        border.width: 1;
    }
}