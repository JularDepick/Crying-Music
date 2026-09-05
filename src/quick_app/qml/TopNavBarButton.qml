import QtQuick
import QtQuick.Controls
import "./"

Button {
    width: define.btnSize;
    height: define.btnSize;
    anchors.verticalCenter: parent.verticalCenter;
    display: Button.IconOnly;
    padding: 0;
    topPadding: 0;
    bottomPadding: 0;
    leftPadding: 0;
    rightPadding: 0;
    spacing: 0;
    icon.width: width;
    icon.height: height;
    background: Item {}
    icon.color: {
        if(hovered) {
            return define.btnHoverColor;
        } else {
            return define.btnIconColor;
        }
    }
    transform: Translate {
            x: (parent.pressed ? 2:0);
            y: (parent.pressed ? 2:0);
    }
}
