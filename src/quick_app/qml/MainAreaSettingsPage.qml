import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic
import QtQuick.Dialogs

import AppHelper 1.0

import "./"

/* 设置页: 顶部按分类 tab 分成播放与下载, 歌词与缓存两组子页;
 * 每个子页的正文放在可滚动区域里, 窗口变矮时由右侧细滚动条与滚轮承接;
 * 偏好都写成界面状态, 重启后保持; 换挡统一用 CustomChoose, 开关统一用 CustomSwitch */
MainAreaFatherPage {
    id: mainArea_SettingsPage;
    visible: false;
    /* 当前分类: play 为播放与下载, cache 为歌词与缓存 */
    property string tabId: "play";
    /* 分类候选 */
    property var tabOptions: [
        {"id":"play","label":"播放与下载"},
        {"id":"cache","label":"歌词与缓存"}
    ];
    /* 下载目录操作的即时提示: 空字符串表示不显示 */
    property string dirTip: "";
    property bool dirTipOk: true;
    /* 封面缓存操作的即时提示: 空字符串表示不显示 */
    property string cacheTip: "";
    property bool cacheTipOk: true;
    /* 封面缓存生命周期候选: 值即天数, 档位来自设计常量 */
    property var ttlOptions: buildTtlOptions();
    function buildTtlOptions() {
        var src=Define.coverCacheTtlDayOptions;
        var res=[];
        for(var i=0;i<src.length;i++) {
            res.push({"label":String(src[i])+" 天","value":src[i]});
        }
        return res;
    }
    /* 音频缓存上限候选: 值即 MB, 档位来自设计常量 */
    property var audioCapOptions: buildAudioCapOptions();
    function buildAudioCapOptions() {
        var src=Define.audioCacheCapMbOptions;
        var res=[];
        for(var i=0;i<src.length;i++) {
            var mb=src[i];
            var text=(mb>=1024? String(mb/1024)+" GB":String(mb)+" MB");
            res.push({"label":text,"value":mb});
        }
        return res;
    }
    /* 播放策略候选 */
    property var playOptions: [
        {"label":"不下载","value":Define.playStrategyNoDownload},
        {"label":"边播放边下载","value":Define.playStrategyDownloadWhilePlaying}
    ];
    /* 下载文件命名候选: 值就是落盘的命名模板; 换挡只影响之后下载的文件, 已有的文件不改名 */
    property var nameOptions: [
        {"label":"歌名-歌手","value":Define.downloadNameTemplates[0]},
        {"label":"歌手-歌名","value":Define.downloadNameTemplates[1]}
    ];
    /* 切换分类: 同时把滚动位置复位, 新的一页从顶部开始 */
    function setTab(id) {
        var next=String(id===undefined? "":id);
        if(next===tabId) {
            return false;
        }
        tabId=next;
        settingsFlick.contentY=0;
        Assist.dlog("界面","设置分类: ",tabId);
        return true;
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
    /* 在线缓存概况文本: 封面与歌词各自的已缓存数量与清单条目数 */
    function cacheStatsText() {
        var s=Server.coverCacheStats();
        var l=Server.lyricsCacheStats();
        return ("已缓存 "+s["cached"]+" 个封面与 "+l["cached"]+" 份歌词, 清单共 "+s["total"]+" 首");
    }
    /* 立即清理在线缓存: 封面与歌词一并删除, 只删本地缓存文件, 不动任何数据与偏好 */
    function clearCoverCache() {
        var ok=(Server.clearCoverCache()===true && Server.clearLyricsCache()===true);
        mainArea_SettingsPage.cacheTipOk=ok;
        mainArea_SettingsPage.cacheTip=(ok? "已清理封面与歌词缓存, 会在需要时重新缓存"
                                          :"清理失败, 请查看控制台日志");
        Assist.dlog("界面","清理封面与歌词缓存: ",ok);
    }
    /* 音频缓存概况文本: 已缓存份数与占用大小 */
    function audioCacheStatsText() {
        var s=Server.audioCacheStats();
        var mb=Math.round(s["bytes"]/1048576);
        var capMb=Math.round(s["cap"]/1048576);
        return ("已缓存 "+s["cached"]+" 首音频, 占用约 "+mb+" MB, 上限 "+capMb+" MB");
    }
    /* 立即清理音频缓存: 只删本地缓存文件, 不动下载记录与播放数据 */
    function clearAudioCache() {
        var ok=(Server.clearAudioCache()===true);
        mainArea_SettingsPage.cacheTipOk=ok;
        mainArea_SettingsPage.cacheTip=(ok? "已清理音频缓存, 会在再次播放时重新缓存"
                                          :"清理失败, 请查看控制台日志");
        Assist.dlog("界面","清理音频缓存: ",ok);
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
    /* 页头: 标题与分类 tab, 固定不随正文滚动; 内边距与子 tab 沿用兄弟页面的列表页写法 */
    Column {
        id: pageHeader;
        anchors {left:parent.left; right:parent.right; top:parent.top;}
        leftPadding: 40;
        rightPadding: 40;
        bottomPadding: 10;
        Text {
            color: Define.textColor;
            text: "设置";
            font.pixelSize: 32;
            font.weight: 700;
        }
        Row {
            id: tabBar;
            topPadding: 5;
            spacing: 0;
            Repeater {
                id: tabRepeater;
                model: mainArea_SettingsPage.tabOptions;
                delegate: CustomButtonA {
                    height: 24;
                    width: 96;
                    transEnabled: false;
                    property bool selected: (mainArea_SettingsPage.tabId===modelData["id"]);
                    onClicked: {
                        mainArea_SettingsPage.setTab(modelData["id"]);
                    }
                    background: Rectangle {
                        anchors.fill: parent;
                        color: Define.nocolor;
                        property bool selected: parent.selected;
                        Text {
                            anchors.centerIn: parent;
                            text: (modelData===undefined || modelData===null? "":String(modelData["label"]));
                            font.pixelSize: 14;
                            color: (parent.selected||parent.parent.hovered? Define.choseCyanColor:Define.textColor);
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
    /* 正文: 可滚动区域, 两组子页各自一列, 同一时刻只显示当前分类那一列 */
    Flickable {
        id: settingsFlick;
        anchors {left:parent.left; right:parent.right; top:pageHeader.bottom; bottom:parent.bottom;}
        anchors.topMargin: 5;
        clip: true;
        boundsBehavior: Flickable.StopAtBounds;
        DragHandler {
            acceptedDevices: PointerDevice.Mouse;
            target: null;
        }
        contentWidth: width;
        contentHeight: ((mainArea_SettingsPage.tabId==="play"? playTab.height:cacheTab.height)+48);
        /* 播放与下载 */
        Column {
            id: playTab;
            visible: (mainArea_SettingsPage.tabId==="play");
            x: 40;
            width: settingsFlick.width-80;
            spacing: 10;
            /* 在线播放策略 */
            Text {
                color: Define.textColor;
                text: "在线播放策略";
                font.pixelSize: 15;
                font.weight: 400;
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
                height: 2;
                radius: 1;
                color: Define.subGrey;
            }
            /* 下载文件命名 */
            Text {
                color: Define.textColor;
                text: "下载文件命名";
                font.pixelSize: 15;
                font.weight: 400;
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
            Rectangle {
                width: parent.width;
                height: 2;
                radius: 1;
                color: Define.subGrey;
            }
            /* 下载目录 */
            Text {
                color: Define.textColor;
                text: "下载目录";
                font.pixelSize: 15;
                font.weight: 400;
            }
            /* 下载目录: 路径单行显示并限制在可用宽度内, 超出即截断, 悬停用提示展示完整路径 */
            Row {
                id: dirTextRow;
                width: parent.width;
                spacing: 8;
                Text {
                    id: dirPathText;
                    width: Math.min(implicitWidth,
                                    Math.min(Define.settingsPathMaxWidth,
                                             Math.max(0,dirTextRow.width-dirTagText.implicitWidth-dirTextRow.spacing)));
                    text: mainArea_SettingsPage.downloadsDirText();
                    font.pixelSize: 13;
                    color: Define.btnIconColor;
                    elide: Text.ElideRight;
                    wrapMode: Text.NoWrap;
                    HoverHandler {
                        id: dirPathHh;
                    }
                    ToolTip.visible: dirPathHh.hovered&&truncated;
                    ToolTip.text: text;
                    ToolTip.delay: 500;
                }
                Text {
                    id: dirTagText;
                    anchors.verticalCenter: dirPathText.verticalCenter;
                    text: (mainArea_SettingsPage.downloadsDirIsCustom()? "(自定义)":"(默认)");
                    font.pixelSize: 13;
                    color: Define.btnIconColor;
                }
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
                            color: Define.textColor;
                            anchors.centerIn: parent;
                            text: "选择目录";
                        }
                    }
                    onClicked: {
                        mainArea_SettingsPage.chooseDownloadsDir();
                    }
                }
                CustomButtonA {
                    id: resetDirBtn;
                    width: 100;
                    height: 30;
                    transEnabled: false;
                    enabled: mainArea_SettingsPage.downloadsDirIsCustom();
                    /* 禁用时整体降透明, 底色与字色不另换一套, 与兄弟页面的按钮一致 */
                    opacity: (enabled? 1:0.5);
                    background: Rectangle {
                        anchors.fill: parent;
                        radius: 15;
                        color: (parent.hovered? Define.choseDarkColor:Define.hoverDarkColor);
                        Text {
                            anchors.centerIn: parent;
                            text: "恢复默认";
                            color: Define.textColor;
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
        /* 歌词与缓存 */
        Column {
            id: cacheTab;
            visible: (mainArea_SettingsPage.tabId==="cache");
            x: 40;
            width: settingsFlick.width-80;
            spacing: 10;
            /* 封面缓存 */
            Text {
                color: Define.textColor;
                text: "封面缓存";
                font.pixelSize: 15;
                font.weight: 400;
            }
            CustomChoose {
                id: ttlChoose;
                options: mainArea_SettingsPage.ttlOptions;
                currentValue: GlobalFileStorage.coverCacheTtlDays();
                onChosen: (value, index)=> {
                    GlobalFileStorage.setCoverCacheTtlDays(value);
                    Assist.dlog("界面","封面缓存生命周期: ",value," 天");
                }
            }
            Row {
                spacing: 10;
                CustomButtonA {
                    id: clearCacheBtn;
                    width: 100;
                    height: 30;
                    transEnabled: false;
                    background: Rectangle {
                        anchors.fill: parent;
                        radius: 15;
                        color: (parent.hovered? Define.choseDarkColor:Define.hoverDarkColor);
                        Text {
                            color: Define.textColor;
                            anchors.centerIn: parent;
                            text: "立即清理";
                        }
                    }
                    onClicked: {
                        mainArea_SettingsPage.clearCoverCache();
                    }
                    HoverHandler {
                        id: clearCacheHh;
                    }
                    ToolTip.visible: clearCacheHh.hovered;
                    ToolTip.text: mainArea_SettingsPage.cacheStatsText();
                    ToolTip.delay: 600;
                }
            }
            Text {
                visible: (mainArea_SettingsPage.cacheTip!=="");
                text: mainArea_SettingsPage.cacheTip;
                font.pixelSize: 13;
                color: (mainArea_SettingsPage.cacheTipOk? Define.choseCyanColor:Define.btnIconRed);
            }
            Rectangle {
                width: parent.width;
                height: 2;
                radius: 1;
                color: Define.subGrey;
            }
            /* 音频缓存: 播放时后台落盘, 超出上限按最近使用时间淘汰 */
            Text {
                color: Define.textColor;
                text: "音频缓存上限";
                font.pixelSize: 15;
                font.weight: 400;
            }
            CustomChoose {
                id: audioCapChoose;
                options: mainArea_SettingsPage.audioCapOptions;
                currentValue: GlobalFileStorage.audioCacheCapMb();
                onChosen: (value, index)=> {
                    GlobalFileStorage.setAudioCacheCapMb(value);
                    Server.trimAudioCache();
                    Assist.dlog("界面","音频缓存上限: ",value," MB");
                }
            }
            Row {
                spacing: 10;
                CustomButtonA {
                    width: 100;
                    height: 30;
                    transEnabled: false;
                    background: Rectangle {
                        anchors.fill: parent;
                        radius: 15;
                        color: (parent.hovered? Define.choseDarkColor:Define.hoverDarkColor);
                        Text {
                            color: Define.textColor;
                            anchors.centerIn: parent;
                            text: "立即清理";
                        }
                    }
                    onClicked: {
                        mainArea_SettingsPage.clearAudioCache();
                    }
                    HoverHandler {
                        id: audioClearHh;
                    }
                    ToolTip.visible: audioClearHh.hovered;
                    ToolTip.text: mainArea_SettingsPage.audioCacheStatsText();
                    ToolTip.delay: 600;
                }
            }
            Rectangle {
                width: parent.width;
                height: 2;
                radius: 1;
                color: Define.subGrey;
            }
            /* 歌词增强 */
            Text {
                color: Define.textColor;
                text: "歌词增强";
                font.pixelSize: 15;
                font.weight: 400;
            }
            CustomSwitch {
                id: lyricsEnhancedSwitch;
                checked: GlobalFileStorage.lyricsEnhanced();
                onToggled: (on)=> {
                    GlobalFileStorage.setLyricsEnhanced(on);
                    Assist.dlog("界面","歌词增强: ",on);
                }
            }
        }
    }
    /* 正文的细滚动条: 与其它列表共用同一个组件, 内容不超出时自动隐藏 */
    CustomSliderC {
        id: settingsScrollBar;
        anchors {top:settingsFlick.top; bottom:settingsFlick.bottom; right:settingsFlick.right;}
        width: 4;
        visible: (settingsFlick.contentHeight>settingsFlick.height);
        handleRatio: Math.max(0.1,settingsFlick.height/Math.max(1,settingsFlick.contentHeight));
        hoverHandlerEnabled: false;
        value: from*(settingsFlick.contentY/Math.max(1,settingsFlick.contentHeight-settingsFlick.height));
        onMoved: {
            settingsFlick.contentY=(value/from)*Math.max(0,settingsFlick.contentHeight-settingsFlick.height);
            value=Qt.binding(function() {
                return from*(settingsFlick.contentY/Math.max(1,settingsFlick.contentHeight-settingsFlick.height));
            });
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
