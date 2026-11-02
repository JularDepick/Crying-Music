pragma Singleton
import QtQuick

/* 预设主题单例: 只储存预设主题与配色, 是换肤的唯一数据源, 任何代码都不修改这里的值;
 * 换肤的唯一形式是把某套预设的配色写进 Define 的同名颜色属性(见 Define.applyTheme) */
Item {
    /* 参与换肤的颜色键: 与 Define 的同名颜色属性一一对应, 顺序即写入顺序 */
    readonly property var colorKeys: [
        "windowBorderColor",
        "canvasColor",
        "leftSidebarColor",
        "leftSidebarHeaderColor",
        "mainAreaColor",
        "topNavBarColor",
        "textColor",
        "btnIconColor",
        "btnHoverColor",
        "hoverDarkColor",
        "choseDarkColor",
        "choseCyanColor",
        "forbdDarkColor",
        "subGrey"
    ];
    /* 默认主题的 id: 偏好缺失或非法时回退到它 */
    readonly property string defaultId: "lime";
    /* 预设主题: id 用于落盘, label 用于界面显示, colors 必须覆盖 colorKeys 的全部键 */
    readonly property var presets: [
        ({
            "id": "lime",
            "label": "青柠",
            "colors": ({
                "windowBorderColor": "#aaaaaa",
                "canvasColor": "#f0f0f0",
                "leftSidebarColor": "#f0f0f0",
                "leftSidebarHeaderColor": "#f0f0f0",
                "mainAreaColor": "#f6f6f6",
                "topNavBarColor": "#f6f6f6",
                "textColor": "#1a1a1a",
                "btnIconColor": "#434343",
                "btnHoverColor": "#00eb81",
                "hoverDarkColor": "#e8e8e8",
                "choseDarkColor": "#d8d8d8",
                "choseCyanColor": "#00cc65",
                "forbdDarkColor": "#bcbcbc",
                "subGrey": "#e0e0e0"
            })
        }),
        ({
            "id": "ocean",
            "label": "海蓝",
            "colors": ({
                "windowBorderColor": "#9fb0c2",
                "canvasColor": "#e9eef5",
                "leftSidebarColor": "#e9eef5",
                "leftSidebarHeaderColor": "#e9eef5",
                "mainAreaColor": "#f4f8fc",
                "topNavBarColor": "#f4f8fc",
                "textColor": "#1a1a1a",
                "btnIconColor": "#3a4a5c",
                "btnHoverColor": "#2f9cf4",
                "hoverDarkColor": "#dfe7f0",
                "choseDarkColor": "#cfdae6",
                "choseCyanColor": "#1f8ad9",
                "forbdDarkColor": "#b5c1cd",
                "subGrey": "#dbe3ec"
            })
        }),
        ({
            "id": "sakura",
            "label": "樱粉",
            "colors": ({
                "windowBorderColor": "#cfb2ba",
                "canvasColor": "#f7edf0",
                "leftSidebarColor": "#f7edf0",
                "leftSidebarHeaderColor": "#f7edf0",
                "mainAreaColor": "#fdf7f8",
                "topNavBarColor": "#fdf7f8",
                "textColor": "#1a1a1a",
                "btnIconColor": "#4a3a3f",
                "btnHoverColor": "#ff7fa8",
                "hoverDarkColor": "#f1e1e5",
                "choseDarkColor": "#e7d1d7",
                "choseCyanColor": "#e2568a",
                "forbdDarkColor": "#cbb4ba",
                "subGrey": "#efdfe3"
            })
        }),
        ({
            "id": "wheat",
            "label": "麦田",
            "colors": ({
                "windowBorderColor": "#c2b39c",
                "canvasColor": "#f4efe6",
                "leftSidebarColor": "#f4efe6",
                "leftSidebarHeaderColor": "#f4efe6",
                "mainAreaColor": "#fbf7f0",
                "topNavBarColor": "#fbf7f0",
                "textColor": "#1a1a1a",
                "btnIconColor": "#4a4034",
                "btnHoverColor": "#e0a33c",
                "hoverDarkColor": "#ebe2d4",
                "choseDarkColor": "#ddd2bf",
                "choseCyanColor": "#c98a2e",
                "forbdDarkColor": "#bfb2a0",
                "subGrey": "#ece3d5"
            })
        }),
        ({
            "id": "ink",
            "label": "墨黑",
            "colors": ({
                "windowBorderColor": "#3a3a3a",
                "canvasColor": "#1e1e1e",
                "leftSidebarColor": "#1e1e1e",
                "leftSidebarHeaderColor": "#1e1e1e",
                "mainAreaColor": "#252525",
                "topNavBarColor": "#252525",
                "textColor": "#e6e6e6",
                "btnIconColor": "#dcdcdc",
                "btnHoverColor": "#00eb81",
                "hoverDarkColor": "#333333",
                "choseDarkColor": "#3d3d3d",
                "choseCyanColor": "#00cc65",
                "forbdDarkColor": "#7a7a7a",
                "subGrey": "#3a3a3a"
            })
        }),
        ({
            "id": "midnight",
            "label": "夜蓝",
            "colors": ({
                "windowBorderColor": "#31404f",
                "canvasColor": "#161c22",
                "leftSidebarColor": "#161c22",
                "leftSidebarHeaderColor": "#161c22",
                "mainAreaColor": "#1c242c",
                "topNavBarColor": "#1c242c",
                "textColor": "#dde6ef",
                "btnIconColor": "#c6d2dd",
                "btnHoverColor": "#2f9cf4",
                "hoverDarkColor": "#26313b",
                "choseDarkColor": "#31404d",
                "choseCyanColor": "#1f8ad9",
                "forbdDarkColor": "#6d7d8c",
                "subGrey": "#2b3742"
            })
        })
    ];
    /* 预设总数 */
    function count() {
        return presets.length;
    }
    /* 按 id 取预设, 未命中返回 null */
    function presetById(id) {
        var s=String(id===undefined || id===null? "":id);
        for(var i=0;i<presets.length;i++) {
            if(String(presets[i]["id"])===s) {
                return presets[i];
            }
        }
        return null;
    }
    /* 按 id 取配色, 未命中时回退到默认主题的配色 */
    function colorsOf(id) {
        var t=presetById(id);
        if(t===null) {
            t=presetById(defaultId);
        }
        return (t===null? ({}):t["colors"]);
    }
    /* 从一套配色里取某个颜色键的值, 缺失时返回空字符串 */
    function colorOf(colors,key) {
        if(colors===undefined || colors===null) {
            return "";
        }
        var c=colors[key];
        return (c===undefined || c===null? "":String(c));
    }
}
