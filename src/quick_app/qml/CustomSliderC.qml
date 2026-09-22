import QtQuick
import QtQuick.Controls
import "./"

Slider {
    orientation: Qt.Vertical;
    from: 100;
    to: 0;
    stepSize: 1;
    value: 0;
    property real handleRatio: 0.15;
    background: Rectangle {
        x: parent.leftPadding+(parent.availableWidth-width)/2;
        y: parent.topPadding;
        width: 4;
        height: parent.availableHeight;
        radius: 2;
        color: Define.nocolor;
    }
    handle: Rectangle {
        x: parent.leftPadding+(parent.availableWidth-width)/2;
        y: parent.topPadding+((parent.value-parent.to)/(parent.from-parent.to))*(parent.availableHeight-height);
        width: 4;
        height: parent.height*parent.handleRatio;
        radius: 2;
        color: Define.subGrey;
        HoverHandler {
            cursorShape: Qt.PointingHandCursor;
        }
    }
}