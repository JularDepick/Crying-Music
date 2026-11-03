import QtQuick
import QtQuick.Effects

/* 圆角封面图: 图片本体用 MultiEffect 的遮罩裁成圆角, 与左侧栏头像同一套做法;
 * 直接用 clip 只能裁矩形, 圆角对图片不生效, 因此所有音乐封面都走这一份实现。
 * 遮罩里的矩形给出圆角与描边, 遮罩本身不可见, 只作为纹理供 MultiEffect 取用 */
Image {
    id: coverImageRoot;
    /* 圆角半径: 0 表示不裁切 */
    property real cornerRadius: 10;
    /* 遮罩描边宽度: 0 表示不描边 */
    property real outlineWidth: 1;
    property color outlineColor: Define.subGrey;
    fillMode: Image.PreserveAspectCrop;
    layer.enabled: (cornerRadius>0);
    layer.effect: MultiEffect {
        maskEnabled: true;
        maskSource: coverImageMasker;
    }
    Item {
        id: coverImageMasker;
        anchors.fill: parent;
        visible: false;
        layer.enabled: true;
        Rectangle {
            anchors.fill: parent;
            radius: coverImageRoot.cornerRadius;
            border.width: coverImageRoot.outlineWidth;
            border.color: coverImageRoot.outlineColor;
        }
    }
}
