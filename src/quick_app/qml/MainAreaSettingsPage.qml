import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic
import QtQuick.Dialogs

import AppHelper 1.0

import "./"

/* 设置页: 在线播放策略, 下载文件命名与下载目录;
 * 三组偏好都写成界面状态, 重启后保持; 换挡统一用可复用的 CustomChoose */
MainAreaFatherPage {
    id: mainArea_SettingsPage;
    visible: false;
    /* 下载目录操作的即时提示: 空字符串表示不显示 */
    property string dirTip: "";
    property bool dirTipOk: true;
    /* 播放策略候选 */
    property var playOptions: [
        {"label":"不下载","value":Define.playStrategyNoDownload},
        {"label":"边播放边下载","value":Define.playStrategyDownloadWhilePlaying}
    ];
    /* 下载文件命名候选: 值就是落盘的命名模板 */
    property var nameOptions: [
        {"label":"歌名-歌手","value":Define.downloadNameTemplates[0]},
        {"label":"歌手-歌名","value":Define.downloadNameTemplates[1]},
        {"label":"歌名","value":Define.downloadNameTemplates[2]}
    ];
    /* 用清单里的第一首做示例, 清单未就绪时用占位示例 */
    function previewName() {
        var rows=Server.manifestRows();
        var loaded=(Server.loadState===2 && rows.length>0);
        var song=(loaded? String(rows[0]["songname"]):"示例歌曲");
        var singer=(loaded? Server.singersText(rows[0]["singers"]):"示例歌手");
        var ext=".mp3";
        var id="demo.mp3";
        if(loaded) {
            id=String(rows[0]["filename"]);
            var dot=id.lastIndexOf(".");
            if(dot>0) {
                ext=id.substring(dot);
                id="demo"+ext;
            }
        }
        return Assist.composeDownloadName(GlobalFileStorage.downloadNameTemplate(),song,singer,id);
    }
    /* 落盘的命名模板不在候选里时(例如更早版本手填过)回到默认候选 */
    function normalizeNameTemplate() {
        var cur=GlobalFileStorage.downloadNameTemplate();
        var n=nameOptions.length;
        for(var i=0;i<n;i++) {
            if(String(nameOptions[i]["value"])===cur) {
                return true;
            }
        }
        Assist.dlog("界面","命名模板不在换挡候选内, 回到默认: ",cur);
        return (GlobalFileStorage.setDownloadNameTemplate(Define.downloadNameTemplate)===true);
    }
    /* 下载目录的本地路径文本: 存储目录未确定时给出提示 */
    function downloadsDirText() {
        var d=GlobalFileStorage.downloadsDir();
        return (d===""? "(存储目录未确定)":AppFileHelper.clearPath(d));
    }
    /* 下载目录是否有用户指定 */
    function downloadsDirIsCustom() {
        return (GlobalFileStorage.downloadsDirOverride()!=="");
    }
    /* 选择下载目录: 走系统文件夹选择框, 不允许直接改路径文本 */
    function chooseDownloadsDir() {
        downloadDirDialog.open();
    }
    /* 恢复默认下载目录 */
    function resetDownloadsDir() {
        var ok=GlobalFileStorage.resetDownloadsDir();
        mainArea_SettingsPage.dirTipOk=(ok===true);
        mainArea_SettingsPage.dirTip=(ok===true? "已恢复默认下载目录":"恢复失败, 请查看控制台日志");
        Assist.dlog("界面","恢复默认下载目录: ",ok);
    }
    Column {
        anchors {left:parent.left; right:parent.right; top:parent.top;}
        anchors.leftMargin: 40;
        anchors.rightMargin: 40;
        topPadding: 40;
        spacing: 14;
        Text {
            text: "设置";
            font.pixelSize: 32;
            font.weight: 700;
        }
        Rectangle {
            width: parent.width;
            height: 1;
            color: Define.subGrey;
        }
        /* 在线播放策略 */
        Text {
            text: "在线播放策略";
            font.pixelSize: 15;
            font.weight: 500;
        }
        Text {
            text: "选择边播放边下载时, 播放尚未下载的在线歌曲会顺带把它加入下载队列; 选择不下载时只做流式播放";
            font.pixelSize: 13;
            color: Define.btnIconColor;
            wrapMode: Text.WordWrap;
            width: parent.width;
        }
        CustomChoose {
            id: playChoose;
            options: mainArea_SettingsPage.playOptions;
            currentValue: GlobalFileStorage.onlinePlayStrategy();
            onChosen: (value, index)=> {
                GlobalFileStorage.setOnlinePlayStrategy(value);
                Assist.dlog("界面","在线播放策略: ",value);
            }
        }
        Rectangle {
            width: parent.width;
            height: 1;
            color: Define.subGrey;
        }
        /* 下载文件命名 */
        Text {
            text: "下载文件命名";
            font.pixelSize: 15;
            font.weight: 500;
        }
        Text {
            text: "下载在线歌曲时按该换挡生成文件名; 非法字符会自动替换为下划线, 重名时追加序号";
            font.pixelSize: 13;
            color: Define.btnIconColor;
            wrapMode: Text.WordWrap;
            width: parent.width;
        }
        CustomChoose {
            id: nameChoose;
            options: mainArea_SettingsPage.nameOptions;
            currentValue: GlobalFileStorage.downloadNameTemplate();
            onChosen: (value, index)=> {
                GlobalFileStorage.setDownloadNameTemplate(value);
                Assist.dlog("界面","下载文件命名: ",value);
            }
        }
        Text {
            text: "示例: "+mainArea_SettingsPage.previewName();
            font.pixelSize: 13;
            color: Define.btnIconColor;
        }
        Rectangle {
            width: parent.width;
            height: 1;
            color: Define.subGrey;
        }
        /* 下载目录 */
        Text {
            text: "下载目录";
            font.pixelSize: 15;
            font.weight: 500;
        }
        Text {
            text: mainArea_SettingsPage.downloadsDirText()
                  +(mainArea_SettingsPage.downloadsDirIsCustom()? "  (自定义)":"  (默认)");
            font.pixelSize: 13;
            color: Define.btnIconColor;
            wrapMode: Text.WordWrap;
            width: parent.width;
        }
        Row {
            id: dirButtons;
            spacing: 10;
            CustomButtonA {
                id: chooseDirBtn;
                width: 100;
                height: 30;
                transEnabled: false;
                background: Rectangle {
                    anchors.fill: parent;
                    radius: 15;
                    color: (parent.hovered? Define.choseDarkColor:Define.hoverDarkColor);
                    Text {
                        anchors.centerIn: parent;
                        text: "选择目录";
                        font.pixelSize: 13;
                    }
                }
                onClicked: {
                    mainArea_SettingsPage.chooseDownloadsDir();
                }
            }
            CustomButtonA {
                id: resetDirBtn;
                width: 90;
                height: 30;
                transEnabled: false;
                enabled: mainArea_SettingsPage.downloadsDirIsCustom();
                background: Rectangle {
                    anchors.fill: parent;
                    radius: 15;
                    color: (!resetDirBtn.enabled? Define.nocolor
                            :(parent.hovered? Define.choseDarkColor:Define.hoverDarkColor));
                    Text {
                        anchors.centerIn: parent;
                        text: "恢复默认";
                        font.pixelSize: 13;
                        color: (resetDirBtn.enabled? "black":Define.forbdDarkColor);
                    }
                }
                onClicked: {
                    mainArea_SettingsPage.resetDownloadsDir();
                }
            }
        }
        Text {
            visible: (mainArea_SettingsPage.dirTip!=="");
            text: mainArea_SettingsPage.dirTip;
            font.pixelSize: 13;
            color: (mainArea_SettingsPage.dirTipOk? Define.choseCyanColor:Define.btnIconRed);
        }
    }
    /* 系统文件夹选择框: 选中后写入界面状态, 目录不可写时保留原值 */
    FolderDialog {
        id: downloadDirDialog;
        title: "选择下载目录";
        currentFolder: (GlobalFileStorage.downloadsDir()===""? "":GlobalFileStorage.downloadsDir());
        onAccepted: {
            var p=AppFileHelper.formatPath(String(selectedFolder));
            var ok=GlobalFileStorage.setDownloadsDir(p);
            mainArea_SettingsPage.dirTipOk=(ok===true);
            mainArea_SettingsPage.dirTip=(ok===true? "已切换下载目录":"目录不可写, 未切换");
            Assist.dlog("界面","选择下载目录: ",p,", 结果 ",ok);
        }
        onRejected: {
            Assist.dlog("界面","取消选择下载目录");
        }
    }
    function subsHide(scenePos) {
    }
    function refresh() {
        normalizeNameTemplate();
    }
    Component.onCompleted: {
        normalizeNameTemplate();
    }
}
