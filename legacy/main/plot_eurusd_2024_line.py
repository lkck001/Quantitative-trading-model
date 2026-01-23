# -*- coding: utf-8 -*-
"""
绘制 EURUSD 2024 全年行情折线图（每日收盘价）。
数据源：Data/split_by_year/EURUSD_2024.csv（可能无表头，日期在前两列）。
输出：Data/split_by_year/EURUSD_2024_line.png
运行：在项目根目录执行  py main/plot_eurusd_2024_line.py
"""

from pathlib import Path
import sys
import pandas as pd
import matplotlib.pyplot as plt

# 项目根目录
ROOT = Path(__file__).resolve().parent.parent
SRC_FILE = ROOT / "Data" / "split_by_year" / "EURUSD_2024.csv"
OUT_PNG = ROOT / "Data" / "split_by_year" / "EURUSD_2024_line.png"


def load_and_filter(csv_path: Path) -> pd.DataFrame:
    if not csv_path.exists():
        print(f"❌ 找不到数据文件: {csv_path}")
        sys.exit(1)

    # 判断是否有表头
    with open(csv_path, "r", encoding="utf-8") as f:
        first_line = f.readline().strip().lower()
    has_header = any(h in first_line for h in ["time", "date", "open", "high", "low", "close"])

    if has_header:
        df = pd.read_csv(csv_path)
    else:
        # 无表头，按常见tick格式：日期,时间,open,high,low,close,vol,...
        df = pd.read_csv(
            csv_path,
            header=None,
            names=[
                "Date",
                "Clock",
                "Open",
                "High",
                "Low",
                "Close",
                "Volume",
                "Volume2",
                "Extra",
            ],
            engine="python",
        )
        df["Time"] = pd.to_datetime(df["Date"].astype(str) + " " + df["Clock"].astype(str), errors="coerce")

    # 寻找时间列
    time_col = None
    for c in ["Time", "time", "Datetime", "datetime", "Date", "date"]:
        if c in df.columns:
            time_col = c
            break
    if time_col is None:
        print("❌ 未找到时间列，请检查列名")
        sys.exit(1)

    df[time_col] = pd.to_datetime(df[time_col], errors="coerce")
    df = df.dropna(subset=[time_col])
    df = df.sort_values(time_col).set_index(time_col)

    # 只保留2024年
    df = df.loc[(df.index >= "2024-01-01") & (df.index <= "2024-12-31")]

    # 如果是高频数据，按日取收盘价；如果已是日频，直接使用
    if len(df) == 0:
        print("❌ 过滤后无2024年的数据")
        sys.exit(1)

    # 按日重采样，取每日最后一笔Close
    df_daily = df.resample("D").agg({"Close": "last"})
    df_daily = df_daily.dropna(subset=["Close"])
    return df_daily


def plot_line(df_daily: pd.DataFrame, save_path: Path):
    plt.figure(figsize=(14, 6))
    plt.plot(df_daily.index, df_daily["Close"], color="#1f77b4", linewidth=1.0)
    plt.title("EURUSD 2024 日收盘价", fontsize=16, fontweight="bold")
    plt.xlabel("日期", fontsize=12)
    plt.ylabel("价格", fontsize=12)
    plt.grid(alpha=0.3)
    plt.tight_layout()
    plt.savefig(save_path, dpi=200)
    print(f"✓ 折线图已保存: {save_path}")


def main():
    df_daily = load_and_filter(SRC_FILE)
    print(f"日线数据量: {len(df_daily)}，范围: {df_daily.index.min()} ~ {df_daily.index.max()}")
    plot_line(df_daily, OUT_PNG)


if __name__ == "__main__":
    main()

