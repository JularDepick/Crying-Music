import QtQuick
import QtQuick.Controls
import "./"

Slider {
    id: root;
    orientation: Qt.Vertical;
    width: 4;
    from: 100;
    to: 0;
    stepSize: 1;
    value: 0;
    padding: 0;
    property real handleRatio: 0.15;
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