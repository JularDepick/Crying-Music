import QtQuick
import QtQuick.Controls
import "./"

Slider {
    width: 200;
    from: 0;
    to: maxStamp;
    stepSize: 1;
    value: 0;
    property int maxStamp: 100;
    background: Rectangle {
        x: parent.leftPadding;
        y: parent.topPadding+(parent.availableHeight-height)/2;
        width: parent.availableWidth;
        height: 4;
        radius: 2;
        color: Define.hoverDarkColor;
        border.color: Define.hoverDarkColor;
        border.width: 0.5;
        Rectangle {
            width: parent.parent.visualPosition*parent.width;
            height: parent.height;
            radius: parent.radius;
            color: Define.btnIconColor;
            border.color: Define.btnIconColor;
            border.width: 0.5;
        }
    }
    handle: Rectangle {
           x: parent.leftPadding+parent.visualPosition*parent.availableWidth-width/2;
           y: parent.topPadding+(parent.availableHeight-height)/2;
           width: 12;
           height: 12;
           radius: 6;
           color: Define.btnIconColor;
           border.color: "white";
           border.width: 1;
           visible: parent.hovered || parent.pressed;
    }
}