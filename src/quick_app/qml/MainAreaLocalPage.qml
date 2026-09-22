import QtQuick
import QtQuick.Controls
import "./"

MainAreaFatherPage {
    id: mainArea_LocalPage;
    visible: false;
    Column {
        id: headColum;
        y: Math.min(0,mainListView.contentY>=titleText.height? (-titleText.height):(-mainListView.contentY));
        anchors {left:parent.left; right:parent.right;}
        leftPadding: 40;
        rightPadding: 40;
        Text {
            id: titleText;
            text: "本地和下载";
            font.pixelSize: 32;
            font.weight: 700;
        }
        Row {
            id: headRow;
            topPadding: 10;
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
        Rectangle {
            id: functionBox;
            anchors {left:parent.left; right:parent.right;}
            anchors.leftMargin: 40;
            anchors.rightMargin: 40;
            height: 50;
            color: "yellow";
        }
        Row {
            id: sortRow;
            anchors {left:parent.left; right:parent.right;}
            anchors.leftMargin: 40;
            anchors.rightMargin: 40;
            anchors.bottomMargin: 10;
            Button {
                background: Item {
                    Text {
                        text: "歌手";
                    }
                    Image {
                        width: 5;
                        height: 5;
                        source: "qrc:/assets/iconfont/listview/justsort.svg";
                    }
                }
            }
        }
    }
    Rectangle {
        id: mainViewArea;
        anchors {left:parent.left; right:parent.right; top:headColum.bottom; bottom:parent.bottom}
        color: Define.nocolor;
        ListView {
            anchors.fill: parent;
            id: mainListView;
            spacing: 10;
            clip: true;
            boundsBehavior: Flickable.StopAtBounds;
            model: ListModel {
                ListElement {}
                ListElement {}
                ListElement {}
                ListElement {}
                ListElement {}
                ListElement {}
                ListElement {}
            }
            delegate: Item {
                width: ListView.view.width;
                height: 60;
                Rectangle {
                    anchors.fill: parent;
                    anchors.leftMargin: 40;
                    anchors.rightMargin: 40;
                    color: "red";
                }
            }
            CustomButtonA {
                id: jump2TopBtn;
                anchors {bottom:parent.bottom; right:parent.right; bottomMargin:15; rightMargin:15;}
                width: 30;
                height: 30;
                icon.source: "qrc:/assets/iconfont/function/jump2top.svg";
                icon.color: (hovered? Define.btnHoverColor:Define.subGrey);
                icon.width: 20;
                icon.height: 20;
                transEnabled: false;
                visible: (mainListView.contentY>=titleText.height);
                background: Rectangle {
                    anchors.fill: parent;
                    color: Qt.rgba(246,246,246,0.8);
                    border.width: 1.25;
                    border.color: (jump2TopBtn.hovered? Define.btnHoverColor:Define.subGrey);
                }
                onClicked: {
                    mainListView.contentY=0;
                }
            }
        }
    }
    CustomSliderC {
        id: mainListViewScrollBar;
        anchors {top:parent.top; bottom:parent.bottom; right:parent.right;}
        visible: (mainListView.contentHeight > mainListView.height);
        handleRatio: Math.max(0.1,mainListView.height/mainListView.contentHeight);
        value: from*(mainListView.contentY/Math.max(1,mainListView.contentHeight-mainListView.height));
        onMoved: {
            mainListView.contentY=(value/from)*Math.max(0,mainListView.contentHeight-mainListView.height);
            console.log(value);
        }
    }

    function refresh() {
        console.log(mainListView.contentY);
    }
    function jump2list() {
        ;
    }
}