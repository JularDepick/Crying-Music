pragma Singleton
import QtQuick

Item {
    /* OSS信息获取流程:
     * 依次尝试在多个备用地址 oss.meta_file_url[i] 和 oss.manifest_file_url[i] ,拿到即止
     * 将获取到的JSON文件内容分别覆盖存进同结构的JSON对象 oss.meta 和 oss.manifest
    */
    property var oss:
    ({
        "meta_file_url": [
            "https://raw.githubusercontent.com/JularDepick/Crying-Music/main/oss/meta.json",
            "https://JularDepick.github.io/Crying-Music/oss/meta.json"
        ],
        "manifest_file_url": [
            "https://raw.githubusercontent.com/JularDepick/Crying-Music/main/audio/manifest.json",
            "https://JularDepick.github.io/Crying-Music/audio/manifest.json"
        ],
        "meta": ({ "audio_obj_base_url":"<被覆盖为获取到的audio_obj_base_url>" }),
        "manifest": ([{ "filename":"完整文件名称","icon":"图标文件名称","songname":"歌曲名称","singers":["歌手1"] }]),
        "icon_file_base_url": [
            "https://raw.githubusercontent.com/JularDepick/Crying-Music/main/audio/icon/",
            "https://JularDepick.github.io/Crying-Music/audio/icon/"
        ]
    });
}