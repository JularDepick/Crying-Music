import QtQuick
import QtQuick.Controls
import "./"

MainAreaFatherPage {
    id: mainArea_ProfilePage;
    visible: false;
    Text {
        color: Define.textColor;
        text: "This is mainArea_ProfilePage";
    }
    function subsHide(scenePos) {
    }
    function refresh() {
    }
}