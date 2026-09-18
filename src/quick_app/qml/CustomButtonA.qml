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
    property bool hoverColorEnabled: true;
    icon.color: (hovered&&hoverColorEnabled? Define.btnHoverColor:Define.btnIconColor);
    property bool transEnabled: true;
    transform: Translate {
        x: ((pressed&&transEnabled)? 0.5:0);
        y: ((pressed&&transEnabled)? 0.5:0);
    }
    property bool hoverHandlerEnabled: true;
    HoverHandler {
        enabled: (parent.enabled && hoverHandlerEnabled);
        cursorShape: Qt.PointingHandCursor;
    }
}
