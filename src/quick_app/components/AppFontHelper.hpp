#pragma once

#include <QFont>
#include <QGuiApplication>
#include <QObject>
#include <QQuickItem>
#include <QQuickWindow>
#include <QVariant>
#include <QWindow>

/* 界面字体: Qt Quick 的文本只在创建时取应用字体, 运行期改应用字体不会刷新已经建好的文本.
 * 因此换字体分两步: 先改应用字体(此后新建的文本自动跟随), 再遍历各窗口里已有的带 font 属性的
 * 条目, 只替换字体族. 歌词页与桌面悬浮歌词显式指定自己的字体族, 它们所在的子树标了
 * uiFontExempt, 遍历时整棵跳过 */
class AppFontHelper : public QObject
{
    Q_OBJECT
public:
    explicit AppFontHelper(QObject *parent = nullptr) : QObject(parent)
    {
        /* 构造时应用字体还没有被改过, 此刻取到的就是系统默认字体族 */
        m_systemFamily = QGuiApplication::font().family();
    }
    /* 系统默认字体族: "跟随系统"的解析基准 */
    Q_INVOKABLE QString systemFamily() const
    {
        return m_systemFamily;
    }
    /* 切换界面字体: 空串表示跟随系统; 只替换字体族, 字号与字重不动 */
    Q_INVOKABLE bool applyUiFamily(const QString &family)
    {
        const QString one = family.trimmed();
        QFont font = QGuiApplication::font();
        font.setFamily(one.isEmpty() ? m_systemFamily : one);
        QGuiApplication::setFont(font);
        const QWindowList windows = QGuiApplication::topLevelWindows();
        for (QWindow *window : windows) {
            auto *quick = qobject_cast<QQuickWindow *>(window);
            if (quick != nullptr) {
                applyToItem(quick->contentItem(), font);
            }
        }
        return true;
    }

private:
    /* 递归替换字体族: 没有 font 属性的条目只继续向下找, 标了 uiFontExempt 的整棵跳过 */
    static void applyToItem(QQuickItem *item, const QFont &font)
    {
        if (item == nullptr) {
            return;
        }
        if (item->property("uiFontExempt").toBool()) {
            return;
        }
        const QVariant current = item->property("font");
        if (current.isValid() && current.canConvert<QFont>()) {
            QFont one = current.value<QFont>();
            if (one.family() != font.family()) {
                one.setFamily(font.family());
                item->setProperty("font", one);
            }
        }
        const QList<QQuickItem *> children = item->childItems();
        for (QQuickItem *child : children) {
            applyToItem(child, font);
        }
    }

    QString m_systemFamily;
};
