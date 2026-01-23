# -*- coding: utf-8 -*-
"""
从小时级数据中识别“上三交易机会”，并生成交易快照。

数据源：
    Data/split_by_year/EURUSD_2024.csv （无表头，列顺序：Date, Time, Open, High, Low, Close, Volume...）

输出：
    - 控制台打印发现的机会（起始时间/结束时间）
    - 图片快照保存到 Data/pattern_snapshots/upper_three_*.png
    - 结果汇总保存到 Data/pattern_snapshots/upper_three_summary.csv

规则（简化版，对应图 4-12 上三交易机会）：
    1) 释放段：向上，幅度 >= min_release_pips，角度 >= min_release_angle，阳盛阴衰
    2) 回撤段：回撤幅度 <= 释放幅度的 1/2
    3) 累积段（三角形）：至少 3 个高低点交替（高-低-高-低-高），高点递降/低点递升
    4) 时间比：累积时间 >= 释放时间 * min_time_ratio
"""

import os
import math
from pathlib import Path
from typing import List, Tuple

import matplotlib.pyplot as plt
import mplfinance as mpf
import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "Data" / "split_by_year" / "EURUSD_2024.csv"
OUT_DIR = ROOT / "Data" / "pattern_snapshots"
OUT_DIR.mkdir(parents=True, exist_ok=True)


def load_h1(csv_path: Path) -> pd.DataFrame:
    """读取无表头 CSV，转为 H1 K 线"""
    df = pd.read_csv(
        csv_path,
        header=None,
        names=["Date", "Clock", "Open", "High", "Low", "Close", "Volume", "Volume2", "Extra"],
    )
    df["Time"] = pd.to_datetime(df["Date"].astype(str) + " " + df["Clock"].astype(str), errors="coerce")
    df = df.dropna(subset=["Time"]).set_index("Time")
    df = df[["Open", "High", "Low", "Close", "Volume"]]
    # 重采样到 H1
    h1 = df.resample("1H").agg(
        {
            "Open": "first",
            "High": "max",
            "Low": "min",
            "Close": "last",
            "Volume": "sum",
        }
    ).dropna()
    return h1


def zigzag(df: pd.DataFrame, pct: float = 0.003) -> List[Tuple[pd.Timestamp, float, int]]:
    """简单的 ZigZag，返回 (时间, 价格, 类型)，类型 1=高点，-1=低点"""
    prices = df["Close"]
    pivots = []
    last_pivot_idx = prices.index[0]
    last_pivot_price = prices.iloc[0]
    last_type = 0

    for t, p in prices.iloc[1:].items():
        move = (p - last_pivot_price) / last_pivot_price
        if last_type >= 0 and move >= pct:
            # 新高点
            pivots.append((last_pivot_idx, last_pivot_price, -1 if last_type == -1 else 0))
            pivots.append((t, p, 1))
            last_pivot_idx, last_pivot_price, last_type = t, p, 1
        elif last_type <= 0 and move <= -pct:
            # 新低点
            pivots.append((last_pivot_idx, last_pivot_price, 1 if last_type == 1 else 0))
            pivots.append((t, p, -1))
            last_pivot_idx, last_pivot_price, last_type = t, p, -1
        else:
            # 更新当前极值
            if last_type >= 0 and p > last_pivot_price:
                last_pivot_idx, last_pivot_price = t, p
            if last_type <= 0 and p < last_pivot_price:
                last_pivot_idx, last_pivot_price = t, p
    # 清理类型标记，重新标注高低点交替
    cleaned = []
    for i, (t, p, _) in enumerate(pivots):
        if i == 0:
            tp = 1 if (len(pivots) > 1 and pivots[1][1] < p) else -1
        else:
            tp = -cleaned[-1][2]
        cleaned.append((t, p, tp))
    return cleaned


def angle_deg(p1: float, p2: float, bars: int) -> float:
    """估算角度：使用价格涨幅/价格 * 100 与时间的斜率，arctan 转角度"""
    if bars <= 0:
        return 90.0
    slope = ((p2 - p1) / p1) * 100 / bars * 2
    return abs(math.degrees(math.atan(slope)))


def find_patterns(
    df: pd.DataFrame,
    pivots: List[Tuple[pd.Timestamp, float, int]],
    min_release_pips: float = 80,   # 最小释放幅度（点）
    min_release_angle: float = 45,  # 最小释放角度
    max_retrace_ratio: float = 0.5, # 回撤不超过释放的 1/2
    min_time_ratio: float = 2.0,    # 累积时间 >= 释放时间 * 2
) -> List[dict]:
    results = []
    for i in range(len(pivots) - 5):
        t1, p1, tp1 = pivots[i]
        t2, p2, tp2 = pivots[i + 1]
        t3, p3, tp3 = pivots[i + 2]
        t4, p4, tp4 = pivots[i + 3]
        t5, p5, tp5 = pivots[i + 4]
        t6, p6, tp6 = pivots[i + 5]

        # 需要 低-高-低-高-低-高 的结构
        if not (tp1 == -1 and tp2 == 1 and tp3 == -1 and tp4 == 1 and tp5 == -1 and tp6 == 1):
            continue

        # 释放段：t1->t2 上涨
        release_pips = (p2 - p1) * 10000
        release_bars = int((t2 - t1).total_seconds() / 3600)
        if release_pips < min_release_pips or release_bars <= 0:
            continue
        ang = angle_deg(p1, p2, release_bars)
        if ang < min_release_angle:
            continue

        # 回撤幅度
        retrace_pips = (p2 - p3) * 10000
        if retrace_pips < 0 or retrace_pips > release_pips * max_retrace_ratio:
            continue

        # 三角形高点递降，低点递升
        if not (p4 < p2 and p6 < p2 and p4 < p6):
            continue
        if not (p3 < p5 < p2):
            continue

        # 累积时间
        acc_bars = int((t6 - t2).total_seconds() / 3600)
        if acc_bars < release_bars * min_time_ratio:
            continue

        results.append(
            dict(
                start=t1,
                release_end=t2,
                pattern_end=t6,
                release_pips=release_pips,
                release_bars=release_bars,
                angle=ang,
                acc_bars=acc_bars,
                acc_ratio=acc_bars / release_bars if release_bars else None,
            )
        )
    return results


def plot_pattern(df_h1: pd.DataFrame, res: dict, out_path: Path):
    """绘制交易快照"""
    start, end = res["start"], res["pattern_end"]
    # 扩大前后各 30 根 K 线
    df_sub = df_h1.loc[start - pd.Timedelta(hours=30): end + pd.Timedelta(hours=30)]
    addplots = []
    title = (
        f"上三交易机会 | 释放: {res['start']} -> {res['release_end']} "
        f"| 累积结束: {res['pattern_end']} "
        f"| 幅度: {res['release_pips']:.1f}p | 角度: {res['angle']:.1f}° | 时间比: {res['acc_ratio']:.1f}x"
    )
    mpf.plot(
        df_sub,
        type="candle",
        style="yahoo",
        title=title,
        volume=True,
        savefig=dict(fname=str(out_path), dpi=160, bbox_inches="tight"),
        addplot=addplots,
    )


def main():
    if not SRC.exists():
        print(f"未找到数据文件: {SRC}")
        return
    df_h1 = load_h1(SRC)
    # 放宽条件：更敏感的拐点、较低的释放要求
    pivots = zigzag(df_h1, pct=0.0015)  # 原 0.003，约 15p 波动识别拐点
    patterns = find_patterns(
        df_h1,
        pivots,
        min_release_pips=40,     # 原 80
        min_release_angle=30,    # 原 45
        max_retrace_ratio=0.55,  # 原 0.5
        min_time_ratio=1.5,      # 原 2.0
    )
    if not patterns:
        print("未找到上三交易机会")
        return

    print(f"共发现 {len(patterns)} 个上三交易机会，正在保存快照...")
    rows = []
    for idx, res in enumerate(patterns, 1):
        out_png = OUT_DIR / f"upper_three_{idx:02d}.png"
        plot_pattern(df_h1, res, out_png)
        rows.append(
            {
                "start": res["start"],
                "release_end": res["release_end"],
                "pattern_end": res["pattern_end"],
                "release_pips": res["release_pips"],
                "release_bars": res["release_bars"],
                "angle": res["angle"],
                "acc_bars": res["acc_bars"],
                "acc_ratio": res["acc_ratio"],
                "snapshot": out_png.name,
            }
        )
        print(f"{idx}. {res['start']} -> {res['pattern_end']} | 快照: {out_png.name}")

    pd.DataFrame(rows).to_csv(OUT_DIR / "upper_three_summary.csv", index=False, encoding="utf-8-sig")
    print(f"汇总已保存: {OUT_DIR / 'upper_three_summary.csv'}")


if __name__ == "__main__":
    main()

