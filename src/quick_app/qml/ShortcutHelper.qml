import QtQuick

import "./"

/* 全局快捷键: 播放与换曲三组动作集中在这里, 键位表仍在 Define.shortcutKeys.
 * 动作一律调播放器对外的接口(与播放栏按钮同一套调用), 因此边播边下策略, 最近播放,
 * 播放状态落盘, 托盘菜单与桌面歌词的同步这些连带行为都会照常发生, 快捷键不直接改内部状态.
 * 生效判定由注入的 guard 决定: 焦点落在输入框里时三组都不响应, 避免吞掉打字.
 * 换曲只绑 Alt 组合键, 不占用裸方向键, 免得与滑块等控件抢键 */
Item {
    id: root;
    /* 注入: 被操控的播放器, 与播放栏拿到的是同一个对象 */
    property var thePlayer: null;
    /* 注入: 主窗口, 音量快捷键走它那条与滑块同源的落盘路径 */
    property var theWindow: null;
    /* 注入: 生效判定, 返回 false 时三组快捷键都不响应; 为空时始终生效 */
    property var guard: null;
    readonly property bool allowed: ((typeof root.guard!=="function") || root.guard()===true);
    /* 键位一律经 GlobalFileStorage 取值: 用户在设置页改过就用改过的, 否则用设计默认值 */
    /* 播放与暂停 */
    Shortcut {
        sequence: GlobalFileStorage.shortcutKeyOf("playPause");
        enabled: root.allowed;
        onActivated: {
            root.togglePlayPause();
        }
    }
    /* 停止 */
    Shortcut {
        sequence: GlobalFileStorage.shortcutKeyOf("stopPlay");
        enabled: root.allowed;
        onActivated: {
            root.stopPlayback();
        }
    }
    /* 上一曲 */
    Shortcut {
        sequence: GlobalFileStorage.shortcutKeyOf("prevSong");
        enabled: root.allowed;
        onActivated: {
            root.prevSong();
        }
    }
    /* 下一曲 */
    Shortcut {
        sequence: GlobalFileStorage.shortcutKeyOf("nextSong");
        enabled: root.allowed;
        onActivated: {
            root.nextSong();
        }
    }
    /* 音量加减 */
    Shortcut {
        sequence: GlobalFileStorage.shortcutKeyOf("volumeUp");
        enabled: root.allowed;
        onActivated: {
            root.changeVolume(Define.volumeStep);
        }
    }
    Shortcut {
        sequence: GlobalFileStorage.shortcutKeyOf("volumeDown");
        enabled: root.allowed;
        onActivated: {
            root.changeVolume(-Define.volumeStep);
        }
    }
    /* 播放器可用性: 三组动作共用同一处判定 */
    function playerReady() {
        if(root.thePlayer===null || root.thePlayer===undefined) {
            Assist.dwarn("播放","快捷键: 播放器不可用");
            return false;
        }
        return true;
    }
    /* 播放与暂停: 与播放栏按钮同一套判断与调用 */
    function togglePlayPause() {
        if(root.playerReady()!==true) {
            return false;
        }
        if(root.thePlayer.playing===true) {
            root.thePlayer.pause();
        } else {
            root.thePlayer.play();
        }
        Assist.dlog("播放","快捷键: 播放暂停");
        return true;
    }
    /* 上一曲: 走播放器对外的换曲接口, 队列, 播放顺序与策略钩子都由它处理 */
    function prevSong() {
        if(root.playerReady()!==true) {
            return false;
        }
        var ok=root.thePlayer.playPrev();
        Assist.dlog("播放","快捷键: 上一曲, 结果 ",ok);
        return ok;
    }
    /* 下一曲: auto 为假表示手动切换, 与播放栏的下一曲按钮一致 */
    function nextSong() {
        if(root.playerReady()!==true) {
            return false;
        }
        var ok=root.thePlayer.playNext(false);
        Assist.dlog("播放","快捷键: 下一曲, 结果 ",ok);
        return ok;
    }
    /* 停止: 与快捷键之外的入口同一个函数, 队列与当前播放项保留 */
    function stopPlayback() {
        if(root.playerReady()!==true) {
            return false;
        }
        var ok=root.thePlayer.stopPlayback();
        Assist.dlog("播放","快捷键: 停止, 结果 ",ok);
        return ok;
    }
    /* 音量: 走主窗口那条路径, 与音量滑块共用同一份落盘与夹取逻辑 */
    function changeVolume(delta) {
        if(root.theWindow===null || root.theWindow===undefined) {
            Assist.dwarn("播放","快捷键: 主窗口不可用, 音量未改");
            return false;
        }
        root.theWindow.changeVolume(Number(delta));
        return true;
    }
}
