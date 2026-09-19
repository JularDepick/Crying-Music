import QtQuick
import QtQuick.Controls
import "./"

MainAreaFatherPage {
    id: mainArea_LocalPage;
    visible: false;
    Column {
        anchors.fill: parent;
        leftPadding: 30;
        rightPadding: 30;
        Text {
            text: "本地和下载";
            font.pixelSize: 32;
            font.weight: 700;
        }
        Row {
            topPadding: 20;
            spacing: 0;
            Repeater {
                model: ListModel {
                    ListElement {tabname:"本地歌曲";}
                    ListElement {tabname:"下载歌曲";}
                    ListElement {tabname:"正在下载";}
                }
                delegate: CustomButtonA {
                    height: 24;
                    width: 96;
                    transEnabled: false;
                    property bool selected: false;
                    onClicked: {
                    }
                    background: Rectangle {
                        anchors.fill: parent;
                        color: Define.nocolor;
                        property bool selected: parent.selected;
                        Text {
                            anchors.centerIn: parent;
                            text: tabname;
                            font.pixelSize: 14;
                            color: (parent.selected||parent.parent.hovered? Define.choseCyanColor:"black");
                            transform: Translate {
                                x: (parent.pressed? 2:0);
                                y: (parent.pressed? 2:0);
                            }
                        }
                    }
                    Rectangle {
                        anchors.top: parent.bottom;
                        anchors.topMargin: 5;
                        anchors.horizontalCenter: parent.horizontalCenter;
                        height: 2;
                        width: 25;
                        radius: 1;
                        color: (parent.selected? Define.choseCyanColor:Define.nocolor);
                    }
                }
            }
        }
    }
    function refresh() {
    }
}