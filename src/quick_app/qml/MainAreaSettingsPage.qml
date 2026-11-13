import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic
import QtQuick.Dialogs

import AppHelper 1.0

import "./"

/* 设置页: 顶部按分类 tab 分成播放与下载, 歌词与缓存, 按键绑定, 关于与许可四组子页;
 * 每个子页的正文放在可滚动区域里, 窗口变矮时由右侧细滚动条与滚轮承接;
 * 偏好都写成界面状态, 重启后保持; 换挡统一用 CustomChoose, 开关统一用 CustomSwitch */
MainAreaFatherPage {
    id: mainArea_SettingsPage;
    visible: false;
    /* 当前分类: play 为播放与下载, cache 为歌词与缓存, keys 为按键绑定, about 为关于与许可 */
    property string tabId: "play";
    /* 分类候选 */
    property var tabOptions: [
        {"id":"play","label":"播放与下载"},
        {"id":"cache","label":"歌词与缓存"},
        {"id":"keys","label":"按键绑定"},
        {"id":"about","label":"关于与许可"}
    ];
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
    /* 字体候选: 首项是跟随系统, 其余取 Qt 向系统枚举到的字体族 */
    property var fontOptions: buildFontOptions();
    function buildFontOptions() {
        var res=[{"label":"跟随系统","value":""}];
        var fams=Qt.fontFamilies();
        for(var i=0;i<fams.length;i++) {
            res.push({"label":String(fams[i]),"value":String(fams[i])});
        }
        return res;
    }
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
    /* 关于与许可的许可文本区固定高度与内边距走设计常量 Define.licenseTextAreaHeight
     * 与 Define.licenseTextAreaPadding: 文本区不随文本长度撑开, 超出的部分交给它自己的细滚动条 */
    /* 许可文本的切换候选: 文件名与界面简称一一对应, 文件名与 GlobalFileStorage.licenseFileNames 同源 */
    property var licenseOptions: [
        {"label":"AGPL-3.0","value":"LICENSE"},
        {"label":"Qt LGPLv3","value":"LICENSE.Qt"},
        {"label":"FDL","value":"LICENSE.FDL"},
        {"label":"版权声明","value":"COPYRIGHT"}
    ];
    /* 当前选中的许可文件名与它的全文: 全文为空字符串表示读取失败 */
    property string licenseFileId: "LICENSE";
    property string licenseText: "";
    /* 版权行: 取 COPYRIGHT 的首个非空行, 取不到时用中性文案 */
    property string copyrightLine: "";
    /* 取不到许可文本时文本区显示的中性提示 */
    property string licenseEmptyTip: "该文件不存在或无法读取";
    /* 许可文本所在目录: 存储目录未确定时返回空字符串 */
    function licensesPath() {
        var d=String(GlobalFileStorage.storageDirPath);
        return (d===""? "":d+"/"+GlobalFileStorage.licensesDirName);
    }
    /* 读一份许可文本: 许可文本是 UTF-8, 必须显式指定编码, 读取失败返回空字符串 */
    function readLicenseText(name) {
        var dir=licensesPath();
        if(dir==="") {
            return "";
        }
        var txt=AppFileHelper.readFile(dir+"/"+String(name),"UTF-8");
        return (txt===undefined || txt===null? "":String(txt));
    }
    /* 版权行: 取 COPYRIGHT 的首个非空行, 取不到返回空字符串 */
    function readCopyrightLine() {
        var lines=readLicenseText("COPYRIGHT").split("\n");
        var n=lines.length;
        for(var i=0;i<n;i++) {
            var one=String(lines[i]).trim();
            if(one!=="") {
                return one;
            }
        }
        return "";
    }
    /* 刷新关于与许可: 版权行与当前许可全文都按当前存储目录重读 */
    function refreshAbout() {
        copyrightLine=readCopyrightLine();
        licenseText=readLicenseText(licenseFileId);
        Assist.dlog("界面","关于与许可: ",licenseFileId," 字数 ",licenseText.length);
    }
    /* 切换许可文本: 换挡后重读选中项, 文本区回到顶部 */
    function setLicenseFile(id) {
        licenseFileId=String(id===undefined? "":id);
        licenseText=readLicenseText(licenseFileId);
        if(licenseFlick!==null) {
            licenseFlick.contentY=0;
        }
        Assist.dlog("界面","关于与许可: 选中 ",licenseFileId," 字数 ",licenseText.length);
    }
    /* 按键绑定: 正在录制的动作 id, 空串表示没有在录制; 预览与提示只在录制过程中出现 */
    property string capturingAction: "";
    property string capturePreview: "";
    property string captureTip: "";
    property bool captureTipOk: true;
    /* 动作 id 对应的中文名, 只在提示文案里用 */
    function shortcutLabelOf(actionId) {
        var id=String(actionId===undefined || actionId===null? "":actionId);
        var list=Define.shortcutActions;
        for(var i=0;i<list.length;i++) {
            if(String(list[i]["id"])===id) {
                return String(list[i]["label"]);
            }
        }
        return id;
    }
    function captureLabel() {
        return shortcutLabelOf(capturingAction);
    }
    /* 开始录制: 覆盖层随 capturingAction 出现, 焦点交给收键的那一项 */
    function startCapture(actionId) {
        capturingAction=String(actionId===undefined || actionId===null? "":actionId);
        capturePreview="";
        captureTip="";
        captureTipOk=true;
        if(captureKeys!==null && captureKeys!==undefined) {
            captureKeys.forceActiveFocus();
        }
        Assist.dlog("界面","按键绑定: 开始录制 ",capturingAction);
    }
    /* 取消录制: 切分类, 页面隐藏与 Esc 都走这里 */
    function cancelCapture() {
        if(capturingAction==="") {
            return false;
        }
        Assist.dlog("界面","按键绑定: 取消录制 ",capturingAction);
        capturingAction="";
        capturePreview="";
        captureTip="";
        captureTipOk=true;
        return true;
    }
    /* 按键码转按键序列里的写法: 只认常用的键, 认不出的直接拒绝 */
    function keyNameOf(code) {
        var map={0x20:"Space",0x2C:",",0x2E:".",0x2D:"-",0x3D:"=",0x2F:"/",
                 0x3B:";",0x27:"'",0x5B:"[",0x5D:"]",0x5C:"\\",0x60:"`",
                 0x01000001:"Tab",0x01000003:"Backspace",0x01000004:"Return",
                 0x01000005:"Enter",0x01000007:"Delete",
                 0x12:"Left",0x13:"Up",0x14:"Right",0x15:"Down",
                 0x01000010:"Home",0x01000011:"End",0x01000015:"PageUp",0x01000016:"PageDown"};
        if(map[code]!==undefined) {
            return map[code];
        }
        if(code>=0x41 && code<=0x5A) {
            return String.fromCharCode(code);
        }
        if(code>=0x30 && code<=0x39) {
            return String.fromCharCode(code);
        }
        if(code>=0x01000030 && code<=0x0100003B) {
            return "F"+String(code-0x01000030+1);
        }
        return "";
    }
    /* 按键事件转序列: 修饰键按 Ctrl, Alt, Shift, Meta 的顺序拼; 只按修饰键时返回空串 */
    function sequenceOfEvent(event) {
        var name=keyNameOf(event.key);
        if(name==="") {
            return "";
        }
        var parts=[];
        var m=event.modifiers;
        if(m & 0x04000000) {
            parts.push("Ctrl");
        }
        if(m & 0x08000000) {
            parts.push("Alt");
        }
        if(m & 0x02000000) {
            parts.push("Shift");
        }
        if(m & 0x10000000) {
            parts.push("Meta");
        }
        parts.push(name);
        return parts.join("+");
    }
    /* 录制中的一个按键: Esc 取消, 只按修饰键时继续等, 其余先查冲突再写入 */
    function handleCapture(event) {
        if(event.key===0x01000000) {
            cancelCapture();
            return true;
        }
        var seq=sequenceOfEvent(event);
        if(seq==="") {
            capturePreview="";
            captureTip="再按一个非修饰键, Esc 取消";
            captureTipOk=true;
            return false;
        }
        capturePreview=seq;
        var owner=GlobalFileStorage.shortcutOwnerOf(seq);
        if(owner!=="" && owner!==capturingAction) {
            captureTip=("这个组合已用于 "+shortcutLabelOf(owner));
            captureTipOk=false;
            return false;
        }
        var ok=GlobalFileStorage.setShortcutKey(capturingAction,seq);
        if(ok!==true) {
            captureTip="写入失败, 请查看控制台日志";
            captureTipOk=false;
            return false;
        }
        Assist.dlog("界面","按键绑定: ",capturingAction," -> ",seq);
        cancelCapture();
        return true;
    }
    /* 单个动作恢复默认键位 */
    function resetShortcut(actionId) {
        var ok=GlobalFileStorage.resetShortcutKey(actionId);
        Assist.dlog("界面","按键绑定恢复默认: ",actionId," 结果 ",ok);
        return ok;
    }
    /* 切换分类: 同时把滚动位置复位, 新的一页从顶部开始 */
    function setTab(id) {
        var next=String(id===undefined? "":id);
        if(next===tabId) {
            return false;
        }
        cancelCapture();
        tabId=next;
        settingsFlick.contentY=0;
        if(tabId==="about") {
            refreshAbout();
            if(licenseFlick!==null) {
                licenseFlick.contentY=0;
            }
        }
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
    /* 立即清理在线缓存: 封面与歌词一并删除, 只删本地缓存文件, 不动任何数据与偏好 */
    function clearCoverCache() {
        var ok=(Server.clearCoverCache()===true && Server.clearLyricsCache()===true);
        Assist.dlog("界面","清理封面与歌词缓存: ",ok);
    }
    /* 立即清理音频缓存: 只删本地缓存文件, 不动下载记录与播放数据 */
    function clearAudioCache() {
        var ok=(Server.clearAudioCache()===true);
        Assist.dlog("界面","清理音频缓存: ",ok);
    }
    /* 选择下载目录: 走系统文件夹选择框, 不允许直接改路径文本 */
    function chooseDownloadsDir() {
        downloadDirDialog.open();
    }
    /* 复制下载目录到剪贴板: 显示用的是正斜杠, 复制出去按 Windows 习惯换成反斜杠 */
    function copyDownloadsDir() {
        var d=GlobalFileStorage.downloadsDir();
        if(d==="") {
            return false;
        }
        clipboardHelper.text=String(d).replace(/\//g,"\\");
        clipboardHelper.selectAll();
        clipboardHelper.copy();
        Assist.dlog("界面","复制下载目录: ",clipboardHelper.text);
        return true;
    }
    /* 恢复默认下载目录 */
    function resetDownloadsDir() {
        var ok=GlobalFileStorage.resetDownloadsDir();
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
        contentWidth: width;
        contentHeight: ((mainArea_SettingsPage.tabId==="play"? playTab.height
                        :(mainArea_SettingsPage.tabId==="cache"? cacheTab.height
                          :(mainArea_SettingsPage.tabId==="keys"? keysTab.height:aboutTab.height)))+48);
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
                    /* 点路径即复制: 不放提示文本, 只用指针形状提示可点 */
                    TapHandler {
                        cursorShape: Qt.PointingHandCursor;
                        onSingleTapped: {
                            mainArea_SettingsPage.copyDownloadsDir();
                        }
                    }
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
            /* 界面字体: 窗口内所有文本按这一项取字体族, 歌词页与悬浮歌词各用自己那一项 */
            Text {
                color: Define.textColor;
                text: "界面字体";
                font.pixelSize: 15;
                font.weight: 400;
            }
            CustomSelect {
                id: uiFontSelect;
                options: mainArea_SettingsPage.fontOptions;
                currentValue: GlobalFileStorage.uiFontFamily();
                onChosen: (value, index)=> {
                    GlobalFileStorage.setUiFontFamily(value);
                    Define.uiFontFamily=GlobalFileStorage.uiFontFamily();
                    AppFontHelper.applyUiFamily(Define.uiFontFamilyResolved);
                    Assist.dlog("界面","界面字体: ",Define.uiFontFamilyResolved);
                }
            }
        }
        /* 歌词与缓存 */
        Column {
            id: cacheTab;
            visible: (mainArea_SettingsPage.tabId==="cache");
            x: 40;
            width: settingsFlick.width-80;
            spacing: 10;
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
            /* 歌词页歌词字体: 只作用于歌词页里的歌词行, 不影响界面与悬浮歌词 */
            Text {
                color: Define.textColor;
                text: "歌词页歌词字体";
                font.pixelSize: 15;
                font.weight: 400;
            }
            CustomSelect {
                id: lyricsFontSelect;
                options: mainArea_SettingsPage.fontOptions;
                currentValue: GlobalFileStorage.lyricsFontFamily();
                onChosen: (value, index)=> {
                    GlobalFileStorage.setLyricsFontFamily(value);
                    Define.lyricsFontFamily=GlobalFileStorage.lyricsFontFamily();
                    Assist.dlog("界面","歌词字体: ",Define.lyricsFontFamilyResolved);
                }
            }
            /* 桌面悬浮歌词字体 */
            Text {
                color: Define.textColor;
                text: "悬浮歌词字体";
                font.pixelSize: 15;
                font.weight: 400;
            }
            CustomSelect {
                id: desktopLyricsFontSelect;
                options: mainArea_SettingsPage.fontOptions;
                currentValue: GlobalFileStorage.desktopLyricsFontFamily();
                onChosen: (value, index)=> {
                    GlobalFileStorage.setDesktopLyricsFontFamily(value);
                    Define.desktopLyricsFontFamily=GlobalFileStorage.desktopLyricsFontFamily();
                    Assist.dlog("界面","悬浮歌词字体: ",Define.desktopLyricsFontFamilyResolved);
                }
            }
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
                /* 二次确认落在按钮上: 首击进入确认态, 三秒内再击才清理, 超时回归 */
                ConfirmButton {
                    id: clearCacheBtn;
                    width: 100;
                    height: 30;
                    label: "立即清理";
                    confirmLabel: "确认清理";
                    onConfirmed: {
                        mainArea_SettingsPage.clearCoverCache();
                        clearCacheBtn.reset();
                    }
                }
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
                /* 二次确认落在按钮上: 首击进入确认态, 三秒内再击才清理, 超时回归 */
                ConfirmButton {
                    id: audioClearBtn;
                    width: 100;
                    height: 30;
                    label: "立即清理";
                    confirmLabel: "确认清理";
                    onConfirmed: {
                        mainArea_SettingsPage.clearAudioCache();
                        audioClearBtn.reset();
                    }
                }
            }
        }
        /* 关于与许可: 应用名, 版本号, 版权行, 以及四份随包许可文本的全文 */
        Column {
            id: aboutTab;
            visible: (mainArea_SettingsPage.tabId==="about");
            x: 40;
            width: settingsFlick.width-80;
            spacing: 10;
            /* 应用名与版本号: 版本号取自 main.cpp 的 setApplicationVersion */
            Text {
                color: Define.textColor;
                text: Define.initTitle;
                font.pixelSize: 20;
                font.weight: 600;
            }
            Text {
                color: Define.btnIconColor;
                text: ("版本 "+Qt.application.version);
                font.pixelSize: 13;
            }
            /* 版权行: 取许可目录下 COPYRIGHT 的首个非空行 */
            Text {
                color: Define.btnIconColor;
                text: (mainArea_SettingsPage.copyrightLine===""? "版权信息见随包许可文本"
                                                              :mainArea_SettingsPage.copyrightLine);
                font.pixelSize: 13;
            }
            /* 许可文本的切换入口与只读全文 */
            Text {
                color: Define.textColor;
                text: "许可文本";
                font.pixelSize: 15;
                font.weight: 400;
            }
            CustomChoose {
                id: licenseChoose;
                options: mainArea_SettingsPage.licenseOptions;
                currentValue: mainArea_SettingsPage.licenseFileId;
                onChosen: (value, index)=> {
                    mainArea_SettingsPage.setLicenseFile(value);
                }
            }
            Text {
                color: Define.btnIconColor;
                text: ("licenses/"+mainArea_SettingsPage.licenseFileId);
                font.pixelSize: 13;
            }
            /* 文本区: 固定高度, 只读, 超出部分由它自己的细滚动条与滚轮承接 */
            Rectangle {
                id: licenseTextArea;
                width: parent.width;
                height: Define.licenseTextAreaHeight;
                radius: 4;
                color: Define.canvasColor;
                border.width: 1;
                border.color: Define.subGrey;
                clip: true;
                Flickable {
                    id: licenseFlick;
                    anchors {left:parent.left; right:parent.right; top:parent.top; bottom:parent.bottom;}
                    anchors.leftMargin: Define.licenseTextAreaPadding;
                    anchors.topMargin: Define.licenseTextAreaPadding;
                    anchors.bottomMargin: Define.licenseTextAreaPadding;
                    anchors.rightMargin: (Define.licenseTextAreaPadding+10);
                    clip: true;
                    boundsBehavior: Flickable.StopAtBounds;
                    contentWidth: width;
                    contentHeight: licenseBodyText.height;
                    Text {
                        id: licenseBodyText;
                        width: licenseFlick.width;
                        text: (mainArea_SettingsPage.licenseText===""? mainArea_SettingsPage.licenseEmptyTip
                                                                    :mainArea_SettingsPage.licenseText);
                        color: Define.textColor;
                        font.pixelSize: 13;
                        wrapMode: Text.Wrap;
                    }
                }
                CustomSliderC {
                    id: licenseScrollBar;
                    anchors {top:licenseFlick.top; bottom:licenseFlick.bottom; right:licenseTextArea.right;}
                    anchors.rightMargin: 4;
                    width: 4;
                    visible: (licenseFlick.contentHeight>licenseFlick.height);
                    handleRatio: Math.max(0.1,licenseFlick.height/Math.max(1,licenseFlick.contentHeight));
                    hoverHandlerEnabled: false;
                    value: from*(licenseFlick.contentY/Math.max(1,licenseFlick.contentHeight-licenseFlick.height));
                    onMoved: {
                        licenseFlick.contentY=(value/from)*Math.max(0,licenseFlick.contentHeight-licenseFlick.height);
                        value=Qt.binding(function() {
                            return from*(licenseFlick.contentY/Math.max(1,licenseFlick.contentHeight-licenseFlick.height));
                        });
                    }
                }
            }
            /* 其余第三方组件的许可只在随包文件里给出, 界面只做指引, 不在此处塞入全文 */
            Text {
                width: parent.width;
                color: Define.btnIconColor;
                text: "其余第三方组件的许可见随包 THIRD-PARTY-NOTICES.md 与 LICENSE.FFmpeg";
                font.pixelSize: 13;
                wrapMode: Text.Wrap;
            }
        }
        /* 按键绑定: 每个动作一行, 右侧是当前组合与修改入口; 点修改后由录制层收下一次按键 */
        Column {
            id: keysTab;
            visible: (mainArea_SettingsPage.tabId==="keys");
            x: 40;
            width: settingsFlick.width-80;
            spacing: 10;
            Text {
                color: Define.textColor;
                text: "按键绑定";
                font.pixelSize: 15;
                font.weight: 400;
            }
            Repeater {
                model: Define.shortcutActions;
                delegate: Row {
                    width: keysTab.width;
                    spacing: 10;
                    Text {
                        anchors.verticalCenter: parent.verticalCenter;
                        width: 120;
                        text: String(modelData["label"]);
                        font.pixelSize: 14;
                        color: Define.textColor;
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter;
                        width: 150;
                        text: GlobalFileStorage.shortcutKeyOf(modelData["id"]);
                        font.pixelSize: 13;
                        color: (GlobalFileStorage.shortcutIsCustom(modelData["id"])
                                ? Define.choseCyanColor:Define.btnIconColor);
                        elide: Text.ElideRight;
                        wrapMode: Text.NoWrap;
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter;
                        text: (GlobalFileStorage.shortcutIsCustom(modelData["id"])? "(自定义)":"(默认)");
                        font.pixelSize: 13;
                        color: Define.btnIconColor;
                    }
                    CustomButtonA {
                        width: 80;
                        height: 30;
                        transEnabled: false;
                        background: Rectangle {
                            anchors.fill: parent;
                            radius: 15;
                            color: (parent.hovered? Define.choseDarkColor:Define.hoverDarkColor);
                            Text {
                                anchors.centerIn: parent;
                                text: "修改";
                                color: Define.textColor;
                            }
                        }
                        onClicked: {
                            mainArea_SettingsPage.startCapture(modelData["id"]);
                        }
                    }
                    CustomButtonA {
                        width: 100;
                        height: 30;
                        transEnabled: false;
                        enabled: GlobalFileStorage.shortcutIsCustom(modelData["id"]);
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
                            mainArea_SettingsPage.resetShortcut(modelData["id"]);
                        }
                    }
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
    /* 按键录制层: 覆盖整页, 抢到焦点后由 Keys 收键; 点空白处或按 Esc 取消 */
    Rectangle {
        id: captureLayer;
        anchors.fill: parent;
        visible: (mainArea_SettingsPage.capturingAction!=="");
        color: Qt.rgba(0,0,0,0.35);
        topLeftRadius: Define.windowRadius;
        topRightRadius: Define.windowRadius;
        bottomLeftRadius: Define.windowRadius;
        bottomRightRadius: Define.windowRadius;
        /* 点卡片之外的地方取消录制; 声明在卡片之前, 卡片压在上面 */
        MouseArea {
            anchors.fill: parent;
            acceptedButtons: Qt.LeftButton;
            onClicked: {
                mainArea_SettingsPage.cancelCapture();
            }
        }
        Rectangle {
            anchors.centerIn: parent;
            width: 440;
            height: 150;
            radius: 10;
            color: Define.mainAreaColor;
            border.width: 1;
            border.color: Define.subGrey;
            Column {
                anchors.centerIn: parent;
                spacing: 12;
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter;
                    text: ("为 " + mainArea_SettingsPage.captureLabel() + " 设置快捷键");
                    font.pixelSize: 15;
                    color: Define.textColor;
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter;
                    text: (mainArea_SettingsPage.capturePreview===""? "请按下新的组合键"
                                                                    :mainArea_SettingsPage.capturePreview);
                    font.pixelSize: 20;
                    font.weight: 600;
                    color: Define.choseCyanColor;
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter;
                    text: (mainArea_SettingsPage.captureTip===""? "Esc 取消"
                                                                :mainArea_SettingsPage.captureTip);
                    font.pixelSize: 13;
                    color: (mainArea_SettingsPage.captureTipOk? Define.btnIconColor:Define.btnIconRed);
                }
            }
            /* 键盘捕获: 卡片本身不抢焦点, 由这个铺满卡片的不可见项统一收键 */
            Item {
                id: captureKeys;
                anchors.fill: parent;
                focus: (captureLayer.visible===true);
                Keys.onPressed: (event)=> {
                    mainArea_SettingsPage.handleCapture(event);
                    event.accepted=true;
                }
                Keys.onReleased: (event)=> {
                    event.accepted=true;
                }
            }
        }
    }
    /* 剪贴板载体: QML 没有直接的剪贴板接口, 用隐藏的 TextEdit 选中后复制 */
    TextEdit {
        id: clipboardHelper;
        visible: false;
        width: 0;
        height: 0;
    }
    /* 系统文件夹选择框: 选中后写入界面状态, 目录不可写时保留原值 */
    FolderDialog {
        id: downloadDirDialog;
        title: "选择下载目录";
        currentFolder: (GlobalFileStorage.downloadsDir()===""? "":GlobalFileStorage.downloadsDir());
        onAccepted: {
            var p=AppFileHelper.formatPath(String(selectedFolder));
            var ok=GlobalFileStorage.setDownloadsDir(p);
            Assist.dlog("界面","选择下载目录: ",p,", 结果 ",ok);
        }
        onRejected: {
            Assist.dlog("界面","取消选择下载目录");
        }
    }
    function refresh() {
        normalizeNameTemplate();
    }
    /* 页面隐藏时收掉录制层, 免得回来时还在等按键 */
    onVisibleChanged: {
        if(visible!==true) {
            cancelCapture();
        }
    }
    Component.onCompleted: {
        normalizeNameTemplate();
        refreshAbout();
    }
}
