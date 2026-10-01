import QtQuick
import QtQuick.Controls
import QtQuick.Controls.impl
import QtQuick.Dialogs

import AppHelpers 1.0

import "./"

MainAreaFatherPage {
    id: mainArea_LocalPage;
    visible: false;
    Column {
        id: headColum;
        z: mainViewArea.z+1;
        y: Math.min(0,mainListView.contentY>=titleText.height? (-titleText.height):(-mainListView.contentY));
        anchors {left:parent.left; right:parent.right;}
        leftPadding: 40;
        rightPadding: 40;
        bottomPadding: 10;
        Text {
            id: titleText;
            text: "本地和下载";
            font.pixelSize: 32;
            font.weight: 700;
        }
        Row {
            id: headRow;
            topPadding: 5;
            spacing: 0;
            property string curr: "localSongs";
            function jump2(which) {
                console.log("curr=",curr," jump2->",which);
                if(which!==curr) {
                    curr=which;
                }
            }
            Repeater {
                model: ListModel {
                    ListElement {tabname:"本地歌曲"; btnID:"localSongs";}
                    ListElement {tabname:"下载歌曲"; btnID:"downloadedSongs";}
                    ListElement {tabname:"正在下载"; btnID:"downloadingSongs";}
                }
                delegate: CustomButtonA {
                    height: 24;
                    width: 96;
                    transEnabled: false;
                    property bool selected: (headRow.curr===btnID);
                    onClicked: {
                        headRow.jump2(btnID);
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
        Row {
            id: functionBox;
            anchors {left:parent.left; right:parent.right;}
            anchors.leftMargin: 40;
            anchors.rightMargin: 40;
            topPadding: 20;
            spacing: 20;
            CustomButtonA {
                id: playList;
                width: 80;
                height: 30;
                onClicked: {
                    ;
                }
                transEnabled: false;
                background: Rectangle {
                    anchors.fill: parent;
                    radius: 15;
                    color: (parent.hovered? Define.choseDarkColor:Define.hoverDarkColor);
                    Row {
                        anchors.centerIn: parent;
                        spacing: 5;
                        ColorImage {
                            anchors.verticalCenter: parent.verticalCenter;
                            width: 15;
                            height: 15;
                            source: `qrc:/assets/iconfont/playerbar/play.svg`;
                            color: Define.btnIconColor;
                        }
                        Text {
                            text: "播放";
                        }
                    }
                }
            }
            CustomButtonA {
                id: addSong;
                width: 80;
                height: 30;
                onClicked: {
                    addSongSubTab.updateP();
                    addSongSubTab.tshow();
                }
                transEnabled: false;
                background: Rectangle {
                    anchors.fill: parent;
                    radius: 15;
                    color: (parent.hovered? Define.choseDarkColor:Define.hoverDarkColor);
                    Row {
                        anchors.centerIn: parent;
                        spacing: 5;
                        ColorImage {
                            anchors.verticalCenter: parent.verticalCenter;
                            width: 15;
                            height: 15;
                            source: `qrc:/assets/iconfont/function/addbtn.svg`;
                            color: Define.btnIconColor;
                        }
                        Text {
                            text: "添加";
                        }
                    }
                }
            }
            CustomButtonA {
                id: batchOp;
                width: 80;
                height: 30;
                onClicked: {
                    ;
                }
                transEnabled: false;
                background: Rectangle {
                    anchors.fill: parent;
                    radius: 15;
                    color: (parent.hovered? Define.choseDarkColor:Define.hoverDarkColor);
                    Row {
                        anchors.centerIn: parent;
                        spacing: 5;
                        ColorImage {
                            anchors.verticalCenter: parent.verticalCenter;
                            width: 15;
                            height: 15;
                            source: `qrc:/assets/iconfont/function/batch.svg`;
                            color: Define.btnIconColor;
                        }
                        Text {
                            text: "批量";
                        }
                    }
                }
            }
        }
    }
    Rectangle {
        id: addSongSubTab;
        z: mainViewArea.z+2;
        radius: 8;
        width: 120;
        height: 65;
        color: Define.mainAreaColor;
        visible: false;
        border.color: Define.subGrey;
        border.width: 0.5;
        function updateP() {
            var p=addSong.mapToItem(mainArea_LocalPage,0,0);
            x=p.x+(addSong.width-width)/2;
            y=p.y+addSong.height+5;
        }
        function show() {
            visible=true;
        }
        function hide() {
            visible=false;
        }
        function tshow() {
            visible=!visible;
        }
        Column {
            anchors {fill:parent;}
            padding: 2;
            spacing: 2;
            CustomButtonA {
                width: parent.width-4;
                height: 30;
                transEnabled: false;
                hoverColorEnabled: false;
                onClicked: {
                    songFileDialog.open();
                    addSongSubTab.hide();
                }
                background: Rectangle {
                    anchors.fill: parent;
                    color: (parent.hovered? Define.hoverDarkColor:Define.mainAreaColor);
                    radius: 5;
                    Row {
                        anchors.verticalCenter: parent.verticalCenter;
                        spacing: 5;
                        leftPadding: 10;
                        ColorImage {
                            anchors.verticalCenter: parent.verticalCenter;
                            width: 15;
                            height: 15;
                            source: "qrc:/assets/iconfont/function/addfiles.svg";
                            color: Define.btnIconColor;
                        }
                        Text {
                            text: "手动添加歌曲";
                        }
                    }
                }
                FileDialog {
                    id: songFileDialog;
                    title: "请选择需要导入的音频文件(可多选)";
                    acceptLabel: "导入";
                    fileMode: FileDialog.OpenFiles;
                    nameFilters: [
                        "音频文件 (*.mp3 *.m4a)"
                    ];
                    currentFolder: AppPathHelper.getAppPath();
                    onAccepted: {
                        console.log(selectedFiles);
                    }
                }
            }
            CustomButtonA {
                width: parent.width-4;
                height: 30;
                transEnabled: false;
                hoverColorEnabled: false;
                onClicked: {
                    addSongDirSubTab.open();
                    addSongSubTab.hide();
                }
                background: Rectangle {
                    anchors.fill: parent;
                    color: (parent.hovered? Define.hoverDarkColor:Define.mainAreaColor);
                    radius: 5;
                    Row {
                        anchors.verticalCenter: parent.verticalCenter;
                        spacing: 5;
                        leftPadding: 10;
                        ColorImage {
                            anchors.verticalCenter: parent.verticalCenter;
                            width: 15;
                            height: 15;
                            source: "qrc:/assets/iconfont/function/add4dir.svg";
                            color: Define.btnIconColor;
                        }
                        Text {
                            text: "自动扫描歌曲";
                        }
                    }
                }
            }
        }
    }
    Row {
        id: sortHead;
        anchors {left:parent.left; right:parent.right; top:headColum.bottom;}
        anchors.leftMargin: 40;
        anchors.rightMargin: 40;
        height: 20;
        Rectangle {
            anchors {top:parent.top; bottom:parent.bottom;}
            width: parent.width*0.8;
            color: Define.nocolor;
            Button {
                anchors {verticalCenter:parent.verticalCenter; left:parent.left;}
                onClicked: {
                    console.log("歌名");
                }
                background: Row {
                    Text {
                        text: "歌名";
                    }
                    ColorImage {
                        anchors.verticalCenter: parent.verticalCenter;
                        width: 10;
                        height: 10;
                        source: "qrc:/assets/iconfont/listview/justsort.svg";
                        color: Define.btnIconColor;
                    }
                }
            }
        }
        Rectangle {
            anchors {top:parent.top; bottom:parent.bottom;}
            width: parent.width*0.1;
            color: Define.nocolor;
            Button {
                anchors {verticalCenter:parent.verticalCenter; left:parent.left;}
                onClicked: {
                    console.log("大小");
                }
                background: Row {
                    Text {
                        text: "大小";
                    }
                    ColorImage {
                        anchors.verticalCenter: parent.verticalCenter;
                        width: 10;
                        height: 10;
                        source: "qrc:/assets/iconfont/listview/justsort.svg";
                        color: Define.btnIconColor;
                    }
                }
            }
        }
        Rectangle {
            anchors {top:parent.top; bottom:parent.bottom;}
            width: parent.width*0.1;
            color: Define.nocolor;
            Button {
                anchors {verticalCenter:parent.verticalCenter; left:parent.left;}
                onClicked: {
                    console.log("时长");
                }
                background: Row {
                    Text {
                        text: "时长";
                    }
                    ColorImage {
                        anchors.verticalCenter: parent.verticalCenter;
                        width: 10;
                        height: 10;
                        source: "qrc:/assets/iconfont/listview/justsort.svg";
                        color: Define.btnIconColor;
                    }
                }
            }
        }
    }
    property var mainListViewModel: ([{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{}
    ]);
    Rectangle {
        id: mainViewArea;
        anchors {left:parent.left; right:parent.right; top:sortHead.bottom; bottom:parent.bottom}
        color: Define.nocolor;
        ListView {
            id: mainListView;
            anchors.fill: parent;
            spacing: 10;
            clip: true;
            boundsBehavior: Flickable.StopAtBounds;
            model: mainArea_LocalPage.mainListViewModel;
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
    Popup {
        id: addSongDirSubTab;
        parent: Overlay.overlay;
        modal: true;
        dim: false;
        focus: true;
        closePolicy: Popup.CloseOnEscape;
        width: parent.width;
        height: parent.height;
        padding: 0;
        background: Rectangle {
            color: Define.nocolor;
        }
        onOpened: {
            addSongDirSubTabArea.x=(width-addSongDirSubTabArea.width)/2;
            addSongDirSubTabArea.y=(height-addSongDirSubTabArea.height)/2;
        }
        function confirm() {
        }
        Rectangle {
            id: addSongDirSubTabArea;
            width: 640;
            height: 480;
            radius: Define.windowRadius;
            color: "white";
            border.color: Define.subGrey;
            border.width: 1;
            MouseArea {
                anchors.fill: parent;
                acceptedButtons: Qt.LeftButton;
                drag.target: addSongDirSubTabArea;
                drag.axis: Drag.XAndYAxis;
                drag.minimumX: Define.windowPadding;
                drag.maximumX: addSongDirSubTab.width-addSongDirSubTabArea.width-Define.windowPadding;
                drag.minimumY: Define.windowPadding;
                drag.maximumY: addSongDirSubTab.height-addSongDirSubTabArea.height-Define.windowPadding;
            }
            CustomButtonA {
                anchors {top:parent.top; right:parent.right; topMargin:10; rightMargin:10;}
                width: 30;
                height: 30;
                icon.source: "qrc:/assets/iconfont/function/close.svg";
                icon.color: (hovered? Define.mainAreaColor:Define.btnIconColor);
                icon.width: 15;
                icon.height: 15;
                transEnabled: false;
                background: Rectangle {
                    anchors.fill: parent;
                    color: (parent.hovered? Define.warnRed:Define.nocolor);
                }
                onClicked: {
                    addSongDirSubTab.close();
                }
            }
            Column {
                anchors.fill: parent;
                padding: 20;
                spacing: 10;
                Text {
                    text: "自动扫描歌曲";
                    font.pixelSize: 18;
                    font.weight: 500;
                }
                Rectangle {
                    anchors {left:parent.left; right:parent.right;}
                    height: 2;
                    radius: 1;
                    color: Define.subGrey;
                }
                Rectangle {
                    width: parent.width-parent.padding*2;
                    height: 30;
                    color: Define.nocolor;
                    Text {
                        anchors.verticalCenter: parent.verticalCenter;
                        text: "勾选自动扫描的文件夹(文件增删实时同步)";
                        font.pixelSize: 15;
                        font.weight: 400;
                    }
                    CustomButtonA {
                        anchors.right: parent.right;
                        transEnabled: false;
                        width: 80;
                        height: 25;
                        background: Rectangle {
                            anchors.fill: parent;
                            radius: 5;
                            color: (parent.hovered? Define.mainAreaColor:"white");
                            border.color: Define.subGrey;
                            border.width: 1;
                            Text {
                                anchors.centerIn: parent;
                                text: "添加文件夹";
                            }
                        }
                        onClicked: {
                            songDirDialog.open();
                        }
                    }
                }
                Rectangle {
                    id: addSongDirListArea;
                    width: parent.width-parent.padding*2;
                    height: parent.height*0.4;
                    color: Define.mainAreaColor;
                    property var dirListViewModel: ([{},{},{},{}]);
                    ListView {
                        id: addSongDirListView;
                        anchors.fill: parent;
                        spacing: 4;
                        clip: true;
                        boundsBehavior: Flickable.StopAtBounds;
                        model: addSongDirListArea.dirListViewModel;
                        delegate: Item {
                            width: ListView.view.width;
                            height: 30;
                            Rectangle {
                                anchors.fill: parent;
                                color: "red";
                            }
                        }
                    }
                }
                Text {
                    text: "扫描规则";
                    font.pixelSize: 15;
                    font.weight: 400;
                }
                Row {
                    Text {
                        text: "文件时长";
                        font.pixelSize: 14;
                        font.weight: 400;
                    }
                }
                Row {
                    Text {
                        text: "文件格式";
                        font.pixelSize: 14;
                        font.weight: 400;
                    }
                }
            }
            CustomButtonA {
                anchors {bottom:parent.bottom; right:parent.right; bottomMargin:20; rightMargin:20;}
                transEnabled: false;
                width: 80;
                height: 30;
                background: Rectangle {
                    anchors.fill: parent;
                    radius: 5;
                    color: (parent.hovered? Define.choseCyanColor:Define.btnHoverColor);
                    border.color: Define.subGrey;
                    border.width: 1;
                    Text {
                        anchors.centerIn: parent;
                        text: "确认";
                        color: "white";
                        font.pixelSize: 14;
                        font.weight: 500;
                    }
                }
                onClicked: {
                    addSongDirSubTab.close();
                    addSongDirSubTab.confirm();
                }
            }
        }
        FolderDialog {
            id: songDirDialog;
            title: "请选择需要添加的文件夹(仅单选)";
            acceptLabel: "添加";
            currentFolder: AppPathHelper.getAppPath();
            options: FolderDialog.ReadOnly;
            onAccepted: {
                console.log(selectedFolder);
            }
        }
    }
    function subsHide(scenePos) {
        if(Assist.hitItem(addSong, scenePos) || Assist.hitItem(addSongSubTab, scenePos)) {
            return;
        }
        addSongSubTab.hide();
    }
    function refresh() {
        console.log(mainListView.contentY);
    }
    function jump2list() {
        ;
    }
}