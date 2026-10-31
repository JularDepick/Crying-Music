#ifndef APPROXMATCH_H
#define APPROXMATCH_H

#include <QVector>
#include <QtGlobal>

/* 近似匹配的底层算子: 带上限的编辑距离与带长度约束的近似子串窗口搜索 */
namespace ApproxMatch {

/* 一次窗口搜索的结果: 编辑距离, 窗口长度, 窗口起点与相似度;
 * distance 为负表示没有找到任何满足距离上限的窗口 */
struct WindowHit {
    int distance=-1;
    int windowLen=0;
    int position=-1;
    double sim=0.0;
};

/* 带上限的编辑距离: 带宽外的格子按超限处理, 整行超限时提前返回;
 * prev 与 cur 为调用方提供的临时缓冲, 长度至少为 lb+1 */
inline int distanceBounded(const uint *a,int la,const uint *b,int lb,int maxDistance,
                           int *prev,int *cur) {
    const int over=maxDistance+1;
    if (qAbs(la-lb)>maxDistance) {
        return over;
    }
    if (la<=0) {
        return (lb<=maxDistance? lb:over);
    }
    for (int j=0;j<=lb;++j) {
        prev[j]=j;
    }
    for (int i=1;i<=la;++i) {
        const int lo=qMax(1,i-maxDistance);
        const int hi=qMin(lb,i+maxDistance);
        cur[0]=i;
        if (lo>1) {
            cur[lo-1]=over;
        }
        int rowMin=over;
        for (int j=lo;j<=hi;++j) {
            const int cost=(a[i-1]==b[j-1]? 0:1);
            int v=prev[j-1]+cost;
            const int del=prev[j]+1;
            if (del<v) {
                v=del;
            }
            const int ins=cur[j-1]+1;
            if (ins<v) {
                v=ins;
            }
            if (v>over) {
                v=over;
            }
            cur[j]=v;
            if (v<rowMin) {
                rowMin=v;
            }
        }
        if (hi<lb) {
            cur[hi+1]=over;
        }
        if (rowMin>maxDistance) {
            return over;
        }
        int *swap=prev;
        prev=cur;
        cur=swap;
    }
    return prev[lb];
}

/* 编辑距离的便捷版本: 自备临时缓冲, 供单点比对与自检使用 */
inline int distance(const QVector<uint> &a,const QVector<uint> &b,int maxDistance) {
    QVector<int> prev(qMax(a.size(),b.size())+2);
    QVector<int> cur(qMax(a.size(),b.size())+2);
    return distanceBounded(a.constData(),int(a.size()),b.constData(),int(b.size()),
                           maxDistance,prev.data(),cur.data());
}

/* 近似子串搜索: 逐段枚举长度在 [查询长度-上限, 查询长度+上限] 的窗口,
 * 取编辑距离最小的窗口; 距离相同时取相似度更高的窗口, 相似度相同则取更靠前的窗口;
 * 相似度按 1 - 编辑距离/max(查询长度, 窗口长度) 计算 */
inline WindowHit bestWindow(const QVector<uint> &text,const QVector<uint> &query,int maxDistance) {
    WindowHit best;
    const int ql=int(query.size());
    const int tl=int(text.size());
    if (ql<=0 || tl<=0 || maxDistance<0) {
        return best;
    }
    const int minLen=qMax(1,ql-maxDistance);
    const int maxLen=ql+maxDistance;
    if (minLen>tl) {
        return best;
    }
    QVector<int> prev(maxLen+2);
    QVector<int> cur(maxLen+2);
    for (int len=minLen;len<=maxLen && len<=tl;++len) {
        for (int start=0;start+len<=tl;++start) {
            const int d=distanceBounded(query.constData(),ql,text.constData()+start,len,
                                        maxDistance,prev.data(),cur.data());
            if (d>maxDistance) {
                continue;
            }
            const double sim=1.0-static_cast<double>(d)/static_cast<double>(qMax(ql,len));
            const bool better=(best.distance<0 || d<best.distance
                               || (d==best.distance && sim>best.sim));
            if (better==false) {
                continue;
            }
            best.distance=d;
            best.windowLen=len;
            best.position=start;
            best.sim=sim;
            if (d==0 && sim>=1.0) {
                return best;
            }
        }
    }
    return best;
}

}
#endif
