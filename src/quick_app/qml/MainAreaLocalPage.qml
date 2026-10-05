import QtQuick
import QtQuick.Controls
import QtQuick.Controls.impl
import QtQuick.Effects
import QtQuick.Dialogs

import AppHelper 1.0

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
    property var mainListViewModel: ([
        {"songname":"心做し 心理作用", "singer":"双笙-陈元汐", "absfpath":"file:///C:/Users/liwenfang/GitHub/JularDepick/Crying-Music/src/quick_app/心做し_心理作用_双笙_陈元汐_.mp3", "absipath":""}
    ]);
    Rectangle {
        id: mainViewArea;
        anchors {left:parent.left; right:parent.right; top:sortHead.bottom; bottom:parent.bottom}
        color: Define.nocolor;
        ListView {
            id: mainListView;
            anchors.fill: parent;
            anchors.topMargin: 5;
            spacing: 1;
            clip: true;
            DragHandler {
                acceptedDevices: PointerDevice.Mouse;
                target: null;
            }
            boundsBehavior: Flickable.StopAtBounds;
            property string selectedWhich: "";
            model: mainArea_LocalPage.mainListViewModel;
            delegate: Item {
                width: ListView.view.width;
                height: 60;
                Rectangle {
                    id: box;
                    anchors.fill: parent;
                    anchors.leftMargin: 40;
                    anchors.rightMargin: 40;
                    radius: 10;
                    color: (mainListView.selectedWhich===modelData["absfpath"]? Define.choseDarkColor:(boxClick.containsMouse||songAvatarBtn.hovered? Define.hoverDarkColor:(index%2===1? Define.canvasColor:Define.mainAreaColor)));
                    MouseArea {
                        id: boxClick;
                        anchors.fill: parent;
                        hoverEnabled: true;
                        onClicked: {
                            mainListView.selectedWhich=modelData["absfpath"];
                            console.log("单击: ",mainListView.selectedWhich);
                        }
                        onDoubleClicked: {
                            console.log("双击: ",modelData["absfpath"]);
                            if(thePlayer.playingWhich===modelData["absfpath"]) {
                                return;
                            }
                            if(thePlayer.insert(modelData)===true) {
                                thePlayer.play();
                            }
                        }
                    }
                    Row {
                        anchors.fill: parent;
                        leftPadding: 10;
                        rightPadding: 10;
                        spacing: 10;
                        CustomButtonA {
                            id: songAvatarBtn;
                            anchors.verticalCenter: parent.verticalCenter;
                            height: 40;
                            width: height;
                            transEnabled: false;
                            hoverHandlerEnabled: false;
                            icon.source: (boxClick.containsMouse||hovered? "qrc:/assets/iconfont/playerbar/play.svg":"");
                            icon.color: (hovered? Define.btnHoverColor:Define.mainAreaColor);
                            icon.width: 17;
                            icon.height: 17;
                            onClicked: {
                                if(thePlayer.playingWhich===modelData["absfpath"]) {
                                    return;
                                }
                                if(thePlayer.insert(modelData)===true) {
                                    thePlayer.play();
                                }
                            }
                            background: Item {
                                anchors.fill: parent;
                                Image {
                                    id: songAvatarImage;
                                    anchors.fill: parent;
                                    source: (modelData["absipath"]&&modelData["absipath"]!==""? modelData["absipath"]:"qrc:/favicon.jpg");
                                    fillMode: Image.PreserveAspectCrop;
                                    layer.enabled: true;
                                    layer.effect: MultiEffect {
                                        maskEnabled: true;
                                        maskSource: songAvatarMasker;
                                    }
                                    Item {
                                        id: songAvatarMasker;
                                        anchors.fill: parent;
                                        visible: false;
                                        layer.enabled: true;
                                        Rectangle {
                                            anchors.fill: parent;
                                            radius: 10;
                                            border.color: Define.subGrey;
                                            border.width: 1;
                                        }
                                    }
                                }
                                Rectangle {
                                    anchors.fill: parent;
                                    radius: 10;
                                    color: (songAvatarBtn.hovered||boxClick.containsMouse? Qt.rgba(0,0,0,0.3):Define.nocolor);
                                }
                            }
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter;
                            spacing: 5;
                            width: 120;
                            Text {
                                text: modelData["songname"];
                                font.pixelSize: 14;
                                font.weight: 400;
                            }
                            Text {
                                text: modelData["singer"];
                                font.pixelSize: 13;
                                font.weight: 400;
                            }
                        }
                        CustomButtonA {
                            anchors.verticalCenter: parent.verticalCenter;
                            height: 20;
                            width: 20;
                            icon.source: "qrc:/assets/iconfont/function/like.svg";
                            icon.color: (hovered? Define.btnIconRed:Define.btnIconColor);
                            transEnabled: false;
                            property bool liked: false;
                            onClicked: {
                                if(liked) {
                                    icon.source="qrc:/assets/iconfont/function/like.svg";
                                } else {
                                    icon.source="qrc:/assets/iconfont/function/liked.svg";
                                }
                                liked=!liked;
                            }
                        }
                    }
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
        width: 4;
        visible: (mainListView.contentHeight > mainListView.height);
        handleRatio: Math.max(0.1,mainListView.height/mainListView.contentHeight);
        hoverHandlerEnabled: false;
        value: from*(mainListView.contentY/Math.max(1,mainListView.contentHeight-mainListView.height));
        onMoved: {
            mainListView.contentY=(value/from)*Math.max(0,mainListView.contentHeight-mainListView.height);
            value=Qt.binding(function() {
                return from*(mainListView.contentY/Math.max(1,mainListView.contentHeight-mainListView.height));
            });
        }
    }
    property var addSongDirViewModel: ([]);
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
                    property var dirListViewModel: mainArea_LocalPage.addSongDirViewModel;
                    ListView {
                        id: addSongDirListView;
                        anchors.fill: parent;
                        spacing: 0;
                        clip: true;
                        boundsBehavior: Flickable.StopAtBounds;
                        model: addSongDirListArea.dirListViewModel;
                        DragHandler {
                            acceptedDevices: PointerDevice.Mouse;
                            target: null;
                        }
                        delegate: Item {
                            width: ListView.view.width;
                            height: 40;
                            Rectangle {
                                anchors.fill: parent;
                                color: Define.nocolor;
                                Row {
                                    anchors.fill: parent;
                                    spacing: 10;
                                    leftPadding: 20;
                                    CustomButtonA {
                                        anchors.verticalCenter: parent.verticalCenter;
                                        transEnabled: false;
                                        hoverHandlerEnabled: false;
                                        width: 16;
                                        height: 16;
                                        icon.source: "qrc:/assets/iconfont/function/checked_stark.svg";
                                        icon.width: 8;
                                        icon.height: 8;
                                        icon.color: Define.mainAreaColor;
                                        property bool selected: true;
                                        onClicked: {
                                            selected=!selected;
                                            var v=mainArea_LocalPage.addSongDirViewModel.slice();
                                            v[index]["included"]=selected;
                                            mainArea_LocalPage.addSongDirViewModel=v;
                                        }
                                        background: Rectangle {
                                            anchors.fill: parent;
                                            radius: parent.width/2;
                                            border.width: 1.5;
                                            border.color: (parent.selected? Define.choseCyanColor:Define.btnIconColor);
                                            color: (parent.selected? Define.choseCyanColor:Define.nocolor);
                                        }
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter;
                                        width: parent.width*0.7;
                                        elide: Text.ElideRight;
                                        wrapMode: Text.NoWrap;
                                        font.pixelSize: 14;
                                        font.weight: 400;
                                        text: modelData["absdpath"];
                                        HoverHandler {
                                            id: texthh1;
                                        }
                                        ToolTip.visible: texthh1.hovered&&truncated;
                                        ToolTip.text: text;
                                        ToolTip.delay: 500;
                                    }
                                }
                                CustomButtonA {
                                    anchors.verticalCenter: parent.verticalCenter;
                                    anchors.right: parent.right;
                                    anchors.rightMargin: 20;
                                    width: 12;
                                    height: 12;
                                    icon.source: "qrc:/assets/iconfont/function/close.svg";
                                    icon.color: Define.btnIconColor;
                                    transEnabled: false;
                                    onClicked: {
                                        var mlvm=mainArea_LocalPage.addSongDirViewModel;
                                        var l=mlvm.length;
                                        var v=[];
                                        for(var i=0;i<l;i++) {
                                            if(mlvm[i]["absdpath"]===modelData["absdpath"]) {
                                                continue;
                                            }
                                            v.push(mlvm[i]);
                                        }
                                        mainArea_LocalPage.addSongDirViewModel=v;
                                    }
                                }
                                Rectangle {
                                    anchors {bottom:parent.bottom; left:parent.left; right:parent.right;}
                                    anchors.leftMargin: 15;
                                    anchors.rightMargin: 15;
                                    height: 1;
                                    color: Define.subGrey;
                                }
                            }
                        }
                    }
                    CustomSliderC {
                        id: addSongDirListViewScrollBar;
                        anchors {top:parent.top; bottom:parent.bottom; right:parent.right;}
                        visible: (addSongDirListView.contentHeight > addSongDirListView.height);
                        handleRatio: Math.max(0.1,addSongDirListView.height/addSongDirListView.contentHeight);
                        hoverHandlerEnabled: false;
                        value: from*(addSongDirListView.contentY/Math.max(1,addSongDirListView.contentHeight-addSongDirListView.height));
                        onMoved: {
                            addSongDirListView.contentY=(value/from)*Math.max(0,addSongDirListView.contentHeight-addSongDirListView.height);
                            value=Qt.binding(function() {
                                return from*(addSongDirListView.contentY/Math.max(1,addSongDirListView.contentHeight-addSongDirListView.height));
                            });
                        }
                    }
                }
                Text {
                    text: "扫描规则";
                    font.pixelSize: 15;
                    font.weight: 400;
                }
                Row {
                    spacing: 10;
                    Text {
                        anchors.verticalCenter: parent.verticalCenter;
                        text: "文件时长";
                        font.pixelSize: 14;
                        font.weight: 400;
                    }
                    ButtonGroup { id: durationGroup1; }
                    Repeater {
                        id: durationRepeater1;
                        model: ListModel {
                            ListElement { radioText:"1分钟及以上"; radioMin:60; isChecked:true; }
                            ListElement { radioText:"30秒及以上"; radioMin:30; isChecked:false; }
                            ListElement { radioText:"全部时长"; radioMin:0; isChecked:false; }
                        }
                        delegate: RadioButton {
                            id: durationRadio1;
                            text: radioText;
                            checked: isChecked;
                            spacing: 6;
                            font.pixelSize: 14;
                            font.weight: 400;
                            ButtonGroup.group: durationGroup1;
                            property int minSecond: radioMin;
                            indicator: Rectangle {
                                implicitWidth: 16;
                                implicitHeight: 16;
                                x: durationRadio1.leftPadding;
                                y: durationRadio1.height/2-height/2;
                                radius: width/2;
                                border.width: 1.2;
                                border.color: (durationRadio1.checked? Define.choseCyanColor:Define.subGrey);
                                color: Define.nocolor;
                                Rectangle {
                                    anchors.centerIn: parent;
                                    width: parent.width*0.5;
                                    height: parent.height*0.5;
                                    radius: width/2;
                                    color: Define.choseCyanColor;
                                    visible: durationRadio1.checked;
                                }
                            }
                            contentItem: Text {
                                text: durationRadio1.text;
                                font: durationRadio1.font;
                                color: "black";
                                verticalAlignment: Text.AlignVCenter;
                                leftPadding: durationRadio1.indicator.width+durationRadio1.spacing;
                            }
                        }
                    }
                }
                Row {
                    spacing: 10;
                    Text {
                        anchors.verticalCenter: parent.verticalCenter;
                        text: "文件格式";
                        font.pixelSize: 14;
                        font.weight: 400;
                    }
                    Item {
                        id: formatCheckRoot1;
                        property var fmts: ([]);
                    }
                    Repeater {
                        id: formatCheckRepeater1;
                        model: ListModel {
                            ListElement { checkText:".mp4"; isChecked:true; }
                            ListElement { checkText:".m4a"; isChecked:true; }
                        }
                        delegate: CheckBox {
                            id: formatCheck;
                            text: checkText;
                            checked: isChecked;
                            spacing: 6;
                            font.pixelSize: 14;
                            font.weight: 400;
                            onCheckedChanged: {
                                if(checked) {
                                    var had=false;
                                    var la=formatCheckRoot1.fmts.length;
                                    var va=formatCheckRoot1.fmts.slice();
                                    for(var ia=0;ia<la;ia++) {
                                        if(va[ia]===checkText) {
                                            had=true;
                                            break;
                                        }
                                    }
                                    if(!had) {
                                        va.push(checkText);
                                        formatCheckRoot1.fmts=va;
                                    }
                                } else {
                                    var lb=formatCheckRoot1.fmts.length;
                                    var vb=[];
                                    for(var ib=0;ib<lb;ib++) {
                                        var one=formatCheckRoot1.fmts[ib];
                                        if(one!==checkText) {
                                            vb.push(one);
                                        }
                                    }
                                    formatCheckRoot1.fmts=vb;
                                }
                            }
                            indicator: Rectangle {
                                implicitWidth: 16;
                                implicitHeight: 16;
                                x: formatCheck.leftPadding;
                                y: formatCheck.height/2-height/2;
                                radius: 2;
                                border.width: 1.2;
                                border.color: (formatCheck.checked? Define.choseCyanColor:Define.subGrey);
                                color: Define.nocolor;
                                Rectangle {
                                    anchors.centerIn: parent;
                                    width: parent.width*0.5;
                                    height: parent.height*0.5;
                                    radius: parent.radius*0.6;
                                    color: Define.choseCyanColor;
                                    visible: formatCheck.checked;
                                }
                            }
                            contentItem: Text {
                                text: formatCheck.text;
                                font: formatCheck.font;
                                color: "black";
                                verticalAlignment: Text.AlignVCenter;
                                leftPadding: formatCheck.indicator.width+formatCheck.spacing;
                            }
                        }
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
            function toggleDuration2(which) {
                var l=durationRepeater1.count;
                for(var i=0;i<l;i++) {
                    var it=durationRepeater1.itemAt(i);
                    if(it && it.minSecond===which) {
                        it.checked=true;
                        return true;
                    }
                }
                return false;
            }
            function toggleFormat(which,what) {
                if(what!==true && what!==false) {
                    return false;
                }
                var l=formatCheckRepeater1.count;
                for(var i=0;i<l;i++) {
                    var it=formatCheckRepeater1.itemAt(i);
                    if(it && it.text===which) {
                        it.checked=what;
                        return true;
                    }
                }
                return false;
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
                var v=mainArea_LocalPage.addSongDirViewModel.slice();
                v.push({"absdpath":selectedFolder,"included":true});
                mainArea_LocalPage.addSongDirViewModel=v;
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