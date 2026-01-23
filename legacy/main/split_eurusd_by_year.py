# -*- coding: utf-8 -*-
"""
将 Data/EURUSD.csv 按年份拆分到 Data/split_by_year 下，生成 EURUSD_YYYY.csv。
支持两种格式：
1) 有表头，时间列名包含 Time/Datetime/Date 等。
2) 无表头，默认列顺序为：Date, Time/Clock, Open, High, Low, Close, Volume, ...

运行（项目根目录）：
    py main/split_eurusd_by_year.py
"""

import pandas as pd
from pathlib import Path

# 项目根目录
ROOT = Path(__file__).resolve().parent.parent
SRC_FILE = ROOT / "Data" / "EURUSD.csv"
OUT_DIR = ROOT / "Data" / "split_by_year"
CHUNK_SIZE = 200_000  # 分块读取行数，可按需调整

TIME_CANDIDATES = ["Time", "time", "Datetime", "datetime", "Date", "date"]


def ensure_out_dir():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    # 清理旧的拆分文件，避免混入此前写过的表头或重复数据
    for f in OUT_DIR.glob("EURUSD_*.csv"):
        try:
            f.unlink()
        except Exception:
            pass


def detect_header_and_read_chunk(chunk):
    """尝试判断是否有表头；如果是首块且无表头，重新按无表头格式读取整个块"""
    # 简单判断：若首行含 time/date/open 等字段名，视为有表头
    first_row = chunk.iloc[0].astype(str).str.lower().tolist()
    has_header = any(any(k in cell for k in ["time", "date", "open", "high", "low", "close"]) for cell in first_row)
    if has_header:
        return chunk, True
    else:
        # 无表头，按默认格式重新解析（日期+时间在前两列）
        chunk.columns = [
            "Date",
            "Clock",
            "Open",
            "High",
            "Low",
            "Close",
            "Volume",
            "Volume2",
            "Extra",
        ][: len(chunk.columns)]
        chunk["Time"] = pd.to_datetime(chunk["Date"].astype(str) + " " + chunk["Clock"].astype(str), errors="coerce")
        return chunk, False


def find_time_column(df):
    for c in TIME_CANDIDATES:
        if c in df.columns:
            return c
    return None


def process_chunk(df, time_col):
    df[time_col] = pd.to_datetime(df[time_col], errors="coerce")
    df = df.dropna(subset=[time_col])
    df["Year"] = df[time_col].dt.year
    grouped = {}
    for y, g in df.groupby("Year"):
        grouped[y] = g.drop(columns=["Year"])
    return grouped


def append_grouped(grouped, header_known: bool):
    for year, g in grouped.items():
        out_path = OUT_DIR / f"EURUSD_{year}.csv"
        # 对无表头的原始格式，去掉新增的 Time 列并不写表头
        if not header_known:
            if "Time" in g.columns:
                g = g.drop(columns=["Time"])
            write_header = False  # 强制不写表头
        else:
            write_header = not out_path.exists()

        # 价格列保留 5 位小数（仅对价格列进行格式化，不影响成交量）
        price_cols = ["Open", "High", "Low", "Close"]
        for c in price_cols:
            if c in g.columns:
                g[c] = pd.to_numeric(g[c], errors="coerce").round(5).map(lambda x: f"{x:.5f}")

        g.to_csv(out_path, mode="a", index=False, header=write_header)


def split_by_year():
    if not SRC_FILE.exists():
        print(f"❌ 源文件不存在: {SRC_FILE}")
        return

    ensure_out_dir()
    print(f"开始拆分: {SRC_FILE}")
    print(f"输出目录: {OUT_DIR}")

    first_chunk = True
    time_col = None
    header_known = None

    reader = pd.read_csv(SRC_FILE, chunksize=CHUNK_SIZE, header=None)

    for i, raw_chunk in enumerate(reader):
        if first_chunk:
            chunk, has_header = detect_header_and_read_chunk(raw_chunk)
            header_known = has_header
            if has_header:
                # 重新构造 reader 带 header
                reader = pd.read_csv(SRC_FILE, chunksize=CHUNK_SIZE)
                # 已经处理过首块，继续下一块循环
                first_chunk = False
                # 先处理当前块（已带表头）
                time_col = find_time_column(chunk)
            else:
                time_col = "Time"
            if time_col is None:
                print("❌ 未找到时间列，请检查数据格式")
                return
        else:
            if header_known:
                chunk = raw_chunk
                if time_col is None:
                    time_col = find_time_column(chunk)
            else:
                chunk = raw_chunk
                chunk.columns = [
                    "Date",
                    "Clock",
                    "Open",
                    "High",
                    "Low",
                    "Close",
                    "Volume",
                    "Volume2",
                    "Extra",
                ][: len(chunk.columns)]
                chunk["Time"] = pd.to_datetime(chunk["Date"].astype(str) + " " + chunk["Clock"].astype(str), errors="coerce")
                time_col = "Time"

        grouped = process_chunk(chunk, time_col)
        append_grouped(grouped, header_known)
        print(f"  已处理分块 {i + 1}")
        first_chunk = False

    print("✔ 拆分完成，生成文件：")
    for f in sorted(OUT_DIR.glob("EURUSD_*.csv")):
        print("  ", f.name)


if __name__ == "__main__":
    split_by_year()

