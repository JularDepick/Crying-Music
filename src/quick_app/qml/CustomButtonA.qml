import QtQuick
import QtQuick.Controls
import "./"

Button {
    width: Define.btnSize;
    height: Define.btnSize;
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
    icon.color: (hovered? Define.btnHoverColor:Define.btnIconColor);
    transform: Translate {
        x: (pressed? 0.25:0);
        y: (pressed? 0.25:0);
    }
}
