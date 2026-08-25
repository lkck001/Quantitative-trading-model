#!/usr/bin/env python3
"""Phase-A accumulation-zone labeling for triangle opportunity recognition.

This script implements only steps 2.1~2.3:
1) input preprocessing
2) sliding-window scan
3) accumulation pre-filter labeling

Output is a compact `accumulation_labels.csv` that can be rendered in MT5.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

import numpy as np
import pandas as pd


DEFAULT_INPUT = Path(
    r"E:\Quantitative trading model\Data\Local_Data\split_by_year\EURUSD_2024.csv"
)
DEFAULT_OUTPUT = Path(
    r"E:\Quantitative trading model\Data\Local_Data\labels\accumulation_labels.csv"
)


@dataclass(frozen=True)
class Config:
    symbol: str
    timeframe_label: str
    timeframe_minutes: int
    window_days: float
    step_bars: int
    min_window_bars: int
    atr_period: int
    thr_range: float
    thr_slope: float
    thr_flip: int
    pass_required: int
    merge_gap_bars: int
    min_zone_days: float
    max_zone_days: float
    require_range_pass: bool
    require_slope_pass: bool
    overlap_threshold: float
    range_expand_mult: float


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Build accumulation pre-filter labels (Phase A, steps 2.1~2.3) "
            "from full-history OHLCV CSV."
        )
    )
    parser.add_argument("--input-csv", type=Path, default=DEFAULT_INPUT)
    parser.add_argument("--output-csv", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument(
        "--output-windows-csv",
        type=Path,
        default=None,
        help="Optional debug output for every sliding window.",
    )
    parser.add_argument("--symbol", type=str, default="EURUSD@_2024_FULL")
    parser.add_argument("--timeframe-label", type=str, default="M15")
    parser.add_argument("--timeframe-minutes", type=int, default=15)
    parser.add_argument("--window-days", type=float, default=2.0)
    parser.add_argument("--step-bars", type=int, default=1)
    parser.add_argument("--min-window-bars", type=int, default=120)
    parser.add_argument("--atr-period", type=int, default=14)
    parser.add_argument("--thr-range", type=float, default=11.0)
    parser.add_argument("--thr-slope", type=float, default=0.03)
    parser.add_argument("--thr-flip", type=int, default=100)
    parser.add_argument("--pass-required", type=int, default=2)
    parser.add_argument("--merge-gap-bars", type=int, default=1)
    parser.add_argument("--min-zone-days", type=float, default=1.0)
    parser.add_argument("--max-zone-days", type=float, default=2.5)
    parser.add_argument(
        "--no-require-range-pass",
        action="store_true",
        help="Allow windows that fail range compression if other rules pass.",
    )
    parser.add_argument(
        "--no-require-slope-pass",
        action="store_true",
        help="Allow windows that fail slope condition if other 2/3 rules pass.",
    )
    parser.add_argument(
        "--overlap-threshold",
        type=float,
        default=0.60,
        help="Deduplicate zones when overlap ratio exceeds this threshold.",
    )
    parser.add_argument(
        "--range-expand-mult",
        type=float,
        default=1.20,
        help="Split zones when merged total range expands too much vs avg window range.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    min_zone_days = max(0.1, args.min_zone_days)
    max_zone_days = max(min_zone_days, args.max_zone_days)
    config = Config(
        symbol=args.symbol,
        timeframe_label=args.timeframe_label,
        timeframe_minutes=max(1, args.timeframe_minutes),
        window_days=max(0.1, args.window_days),
        step_bars=max(1, args.step_bars),
        min_window_bars=max(5, args.min_window_bars),
        atr_period=max(2, args.atr_period),
        thr_range=max(1e-9, args.thr_range),
        thr_slope=max(1e-9, args.thr_slope),
        thr_flip=max(1, args.thr_flip),
        pass_required=min(3, max(1, args.pass_required)),
        merge_gap_bars=max(0, args.merge_gap_bars),
        min_zone_days=min_zone_days,
        max_zone_days=max_zone_days,
        require_range_pass=not args.no_require_range_pass,
        require_slope_pass=not args.no_require_slope_pass,
        overlap_threshold=min(0.99, max(0.1, args.overlap_threshold)),
        range_expand_mult=max(1.05, args.range_expand_mult),
    )

    df = load_source_csv(args.input_csv)
    bars = resample_ohlcv(df, config.timeframe_minutes)
    bars = enrich_with_atr(bars, config.atr_period)

    window_bars = compute_window_bars(config.window_days, config.timeframe_minutes)
    window_bars = max(window_bars, config.min_window_bars)

    windows = scan_windows(bars, window_bars, config)
    zones = merge_pass_windows(windows, bars, config)

    write_outputs(
        windows=windows,
        zones=zones,
        output_csv=args.output_csv,
        output_windows_csv=args.output_windows_csv,
        config=config,
    )

    print_summary(bars=bars, windows=windows, zones=zones, output_csv=args.output_csv)


def load_source_csv(path: Path) -> pd.DataFrame:
    if not path.exists():
        raise FileNotFoundError(f"Input CSV not found: {path}")

    # Read without trusting header shape. The source may have 6~9 columns.
    raw = pd.read_csv(path, header=None)
    if raw.shape[1] < 6:
        raise ValueError(f"Unsupported CSV format (need >=6 columns): {path}")

    first_col = raw.iloc[0, 0]
    header_like = isinstance(first_col, str) and (
        "time" in first_col.lower() or "date" in first_col.lower()
    )
    if header_like:
        raw = raw.iloc[1:].reset_index(drop=True)

    # Common format in this project:
    # date,time,open,high,low,close,tick_volume,real_volume,spread
    if raw.shape[1] >= 8:
        time_col = (
            raw.iloc[:, 0].astype(str).str.strip() + " " + raw.iloc[:, 1].astype(str).str.strip()
        )
        base = 2
    else:
        time_col = raw.iloc[:, 0].astype(str).str.strip()
        base = 1

    out = pd.DataFrame(
        {
            "time": pd.to_datetime(time_col, errors="coerce"),
            "open": to_float(raw.iloc[:, base]),
            "high": to_float(raw.iloc[:, base + 1]),
            "low": to_float(raw.iloc[:, base + 2]),
            "close": to_float(raw.iloc[:, base + 3]),
            "volume": to_float(raw.iloc[:, base + 4]) if raw.shape[1] > base + 4 else 0.0,
        }
    )

    out = out.dropna(subset=["time", "open", "high", "low", "close"])
    out = out.sort_values("time").drop_duplicates(subset=["time"], keep="last")
    out = out.reset_index(drop=True)
    return out


def to_float(series: pd.Series) -> pd.Series:
    return pd.to_numeric(series.astype(str).str.replace(",", ".", regex=False), errors="coerce")


def resample_ohlcv(df: pd.DataFrame, timeframe_minutes: int) -> pd.DataFrame:
    if df.empty:
        raise ValueError("Input data is empty after preprocessing.")

    bars = df.copy().set_index("time")
    rule = f"{timeframe_minutes}min"
    bars = bars.resample(rule).agg(
        {
            "open": "first",
            "high": "max",
            "low": "min",
            "close": "last",
            "volume": "sum",
        }
    )
    bars = bars.dropna(subset=["open", "high", "low", "close"]).reset_index()
    if len(bars) < 10:
        raise ValueError(
            "Too few bars after resampling. Check timeframe/input data availability."
        )
    return bars


def enrich_with_atr(df: pd.DataFrame, atr_period: int) -> pd.DataFrame:
    out = df.copy()
    prev_close = out["close"].shift(1)
    tr = pd.concat(
        [
            out["high"] - out["low"],
            (out["high"] - prev_close).abs(),
            (out["low"] - prev_close).abs(),
        ],
        axis=1,
    ).max(axis=1)
    out["atr"] = tr.rolling(atr_period, min_periods=1).mean()
    out["atr"] = out["atr"].replace(0, np.nan).ffill().bfill()
    return out


def compute_window_bars(window_days: float, timeframe_minutes: int) -> int:
    bars_per_day = (24 * 60) / timeframe_minutes
    return max(2, int(round(window_days * bars_per_day)))


def scan_windows(df: pd.DataFrame, window_bars: int, cfg: Config) -> pd.DataFrame:
    records: list[dict[str, float | int | str | pd.Timestamp]] = []
    n = len(df)
    if n < window_bars:
        raise ValueError(
            f"Not enough bars ({n}) for window size ({window_bars}). "
            "Lower window-days/min-window-bars or provide more data."
        )

    for right in range(window_bars - 1, n, cfg.step_bars):
        left = right - window_bars + 1
        w = df.iloc[left : right + 1]
        atr_mean = float(max(w["atr"].mean(), 1e-12))

        range_value = float(w["high"].max() - w["low"].min())
        range_atr_ratio = range_value / atr_mean

        slope_norm = compute_slope_norm(w["close"].to_numpy(dtype=float), atr_mean)
        flip_count = compute_flip_count(w["close"].to_numpy(dtype=float))

        cond_range = range_atr_ratio <= cfg.thr_range
        cond_slope = abs(slope_norm) <= cfg.thr_slope
        cond_flip = flip_count >= cfg.thr_flip
        pass_count = int(cond_range) + int(cond_slope) + int(cond_flip)
        pass_flag = 1 if pass_count >= cfg.pass_required else 0
        if cfg.require_range_pass and not cond_range:
            pass_flag = 0
        if cfg.require_slope_pass and not cond_slope:
            pass_flag = 0

        score = compute_score(
            range_atr_ratio=range_atr_ratio,
            slope_norm=slope_norm,
            flip_count=flip_count,
            cfg=cfg,
        )

        records.append(
            {
                "window_start": w["time"].iloc[0],
                "window_end": w["time"].iloc[-1],
                "window_low": float(w["low"].min()),
                "window_high": float(w["high"].max()),
                "range_atr_ratio": range_atr_ratio,
                "slope_norm": slope_norm,
                "flip_count": int(flip_count),
                "pass_count": pass_count,
                "pass_flag": pass_flag,
                "score": score,
                "bars": int(window_bars),
            }
        )

    return pd.DataFrame.from_records(records)


def compute_slope_norm(close: np.ndarray, atr_mean: float) -> float:
    if close.size < 2:
        return 0.0
    x = np.arange(close.size, dtype=float)
    slope = float(np.polyfit(x, close, 1)[0])
    return slope / max(atr_mean, 1e-12)


def compute_flip_count(close: np.ndarray) -> int:
    if close.size < 3:
        return 0
    delta = np.diff(close)
    signs = np.sign(delta)
    signs = signs[signs != 0]
    if signs.size < 2:
        return 0
    return int(np.sum(signs[1:] != signs[:-1]))


def compute_score(
    *,
    range_atr_ratio: float,
    slope_norm: float,
    flip_count: int,
    cfg: Config,
) -> float:
    score_range = max(0.0, 1.0 - (range_atr_ratio / cfg.thr_range))
    score_slope = max(0.0, 1.0 - (abs(slope_norm) / cfg.thr_slope))
    score_flip = min(1.0, flip_count / float(cfg.thr_flip))
    return float((score_range + score_slope + score_flip) / 3.0)


def merge_pass_windows(windows: pd.DataFrame, bars: pd.DataFrame, cfg: Config) -> pd.DataFrame:
    passed = windows[windows["pass_flag"] == 1].copy()
    if passed.empty:
        return pd.DataFrame(
            columns=[
                "zone_id",
                "symbol",
                "timeframe",
                "window_start",
                "window_end",
                "zone_low",
                "zone_high",
                "range_atr_ratio",
                "slope_norm",
                "flip_count",
                "pass_flag",
                "score",
                "window_count",
                "bar_count",
                "zone_days",
            ]
        )

    passed = passed.sort_values("window_start").reset_index(drop=True)
    bar_delta = infer_bar_delta(bars["time"])
    max_gap = bar_delta * cfg.merge_gap_bars
    max_zone_span = pd.Timedelta(days=cfg.max_zone_days)

    zones: list[dict[str, float | int | str | pd.Timestamp]] = []
    current = init_zone(passed.iloc[0])

    for i in range(1, len(passed)):
        row = passed.iloc[i]
        candidate_end = max(current["window_end"], row["window_end"])
        candidate_span = candidate_end - current["window_start"]
        row_window_range = float(row["window_high"]) - float(row["window_low"])
        candidate_low = min(current["zone_low"], float(row["window_low"]))
        candidate_high = max(current["zone_high"], float(row["window_high"]))
        candidate_zone_range = candidate_high - candidate_low
        candidate_avg_window_range = (current["window_range_sum"] + row_window_range) / (
            current["window_count"] + 1
        )
        range_ok = candidate_zone_range <= (
            candidate_avg_window_range * cfg.range_expand_mult
        )
        can_merge = row["window_start"] <= current["window_end"] + max_gap
        if can_merge and candidate_span <= max_zone_span and range_ok:
            current["window_end"] = candidate_end
            current["zone_low"] = candidate_low
            current["zone_high"] = candidate_high
            current["range_atr_ratio_sum"] += float(row["range_atr_ratio"])
            current["slope_norm_sum"] += float(row["slope_norm"])
            current["flip_count_sum"] += int(row["flip_count"])
            current["score"] = max(current["score"], float(row["score"]))
            current["window_range_sum"] += row_window_range
            current["window_count"] += 1
        else:
            zones.append(finalize_zone(current, bar_delta))
            current = init_zone(row)

    zones.append(finalize_zone(current, bar_delta))

    out = pd.DataFrame.from_records(zones)
    if out.empty:
        return pd.DataFrame(
            columns=[
                "zone_id",
                "symbol",
                "timeframe",
                "window_start",
                "window_end",
                "zone_low",
                "zone_high",
                "range_atr_ratio",
                "slope_norm",
                "flip_count",
                "pass_flag",
                "score",
                "window_count",
                "bar_count",
                "zone_days",
            ]
        )

    out = out[
        (out["zone_days"] >= cfg.min_zone_days) & (out["zone_days"] <= cfg.max_zone_days)
    ].reset_index(drop=True)
    out = dedupe_overlapping_zones(out, cfg.overlap_threshold)
    out.insert(0, "zone_id", np.arange(1, len(out) + 1))
    out.insert(1, "symbol", cfg.symbol)
    out.insert(2, "timeframe", cfg.timeframe_label)
    return out


def infer_bar_delta(times: pd.Series) -> pd.Timedelta:
    deltas = times.diff().dropna()
    if deltas.empty:
        return pd.Timedelta(minutes=1)
    return pd.to_timedelta(deltas.median())


def init_zone(row: pd.Series) -> dict[str, float | int | pd.Timestamp]:
    window_range = float(row["window_high"]) - float(row["window_low"])
    return {
        "window_start": row["window_start"],
        "window_end": row["window_end"],
        "zone_low": float(row["window_low"]),
        "zone_high": float(row["window_high"]),
        "range_atr_ratio_sum": float(row["range_atr_ratio"]),
        "slope_norm_sum": float(row["slope_norm"]),
        "flip_count_sum": int(row["flip_count"]),
        "score": float(row["score"]),
        "window_range_sum": window_range,
        "window_count": 1,
    }


def finalize_zone(
    zone: dict[str, float | int | pd.Timestamp], bar_delta: pd.Timedelta
) -> dict[str, float | int | pd.Timestamp]:
    window_count = int(zone["window_count"])
    start = pd.Timestamp(zone["window_start"])
    end = pd.Timestamp(zone["window_end"])
    bar_count = int((end - start) / bar_delta) + 1 if bar_delta > pd.Timedelta(0) else 1
    zone_days = max(0.0, (end - start) / pd.Timedelta(days=1))
    return {
        "window_start": start,
        "window_end": end,
        "zone_low": float(zone["zone_low"]),
        "zone_high": float(zone["zone_high"]),
        "range_atr_ratio": float(zone["range_atr_ratio_sum"]) / window_count,
        "slope_norm": float(zone["slope_norm_sum"]) / window_count,
        "flip_count": int(round(float(zone["flip_count_sum"]) / window_count)),
        "pass_flag": 1,
        "score": float(zone["score"]),
        "window_count": window_count,
        "bar_count": max(1, bar_count),
        "zone_days": float(zone_days),
    }


def dedupe_overlapping_zones(zones: pd.DataFrame, overlap_threshold: float) -> pd.DataFrame:
    if zones.empty:
        return zones

    ranked = zones.sort_values(
        by=["score", "window_count", "zone_days"],
        ascending=[False, False, False],
    ).reset_index(drop=True)

    keep: list[int] = []
    kept_intervals: list[tuple[pd.Timestamp, pd.Timestamp]] = []
    for idx, row in ranked.iterrows():
        start = pd.Timestamp(row["window_start"])
        end = pd.Timestamp(row["window_end"])
        if end <= start:
            continue

        overlaps = False
        for k_start, k_end in kept_intervals:
            ratio = interval_overlap_ratio(start, end, k_start, k_end)
            if ratio >= overlap_threshold:
                overlaps = True
                break

        if not overlaps:
            keep.append(idx)
            kept_intervals.append((start, end))

    deduped = ranked.loc[keep].copy()
    deduped = deduped.sort_values("window_start").reset_index(drop=True)
    return deduped


def interval_overlap_ratio(
    a_start: pd.Timestamp, a_end: pd.Timestamp, b_start: pd.Timestamp, b_end: pd.Timestamp
) -> float:
    inter_start = max(a_start, b_start)
    inter_end = min(a_end, b_end)
    inter = max(pd.Timedelta(0), inter_end - inter_start)
    a_span = max(pd.Timedelta(minutes=1), a_end - a_start)
    b_span = max(pd.Timedelta(minutes=1), b_end - b_start)
    shorter = min(a_span, b_span)
    return float(inter / shorter)


def write_outputs(
    *,
    windows: pd.DataFrame,
    zones: pd.DataFrame,
    output_csv: Path,
    output_windows_csv: Path | None,
    config: Config,
) -> None:
    output_csv.parent.mkdir(parents=True, exist_ok=True)

    zones_out = zones.copy()
    if not zones_out.empty:
        zones_out["window_start"] = format_times(zones_out["window_start"])
        zones_out["window_end"] = format_times(zones_out["window_end"])
        zones_out["zone_low"] = zones_out["zone_low"].map(lambda x: f"{x:.5f}")
        zones_out["zone_high"] = zones_out["zone_high"].map(lambda x: f"{x:.5f}")
        zones_out["range_atr_ratio"] = zones_out["range_atr_ratio"].map(lambda x: f"{x:.6f}")
        zones_out["slope_norm"] = zones_out["slope_norm"].map(lambda x: f"{x:.6f}")
        zones_out["score"] = zones_out["score"].map(lambda x: f"{x:.6f}")
        zones_out["zone_days"] = zones_out["zone_days"].map(lambda x: f"{x:.3f}")

    zones_out.to_csv(output_csv, index=False, encoding="utf-8-sig")

    if output_windows_csv is not None:
        output_windows_csv.parent.mkdir(parents=True, exist_ok=True)
        windows_out = windows.copy()
        windows_out["symbol"] = config.symbol
        windows_out["timeframe"] = config.timeframe_label
        windows_out["window_start"] = format_times(windows_out["window_start"])
        windows_out["window_end"] = format_times(windows_out["window_end"])
        windows_out.to_csv(output_windows_csv, index=False, encoding="utf-8-sig")


def format_times(series: pd.Series) -> Iterable[str]:
    return pd.to_datetime(series).dt.strftime("%Y.%m.%d %H:%M")


def print_summary(
    *,
    bars: pd.DataFrame,
    windows: pd.DataFrame,
    zones: pd.DataFrame,
    output_csv: Path,
) -> None:
    pass_windows = int((windows["pass_flag"] == 1).sum())
    print("=== Phase A Accumulation Labeling Complete ===")
    print(f"Bars scanned: {len(bars)}")
    print(f"Windows scanned: {len(windows)}")
    print(f"Pass windows: {pass_windows}")
    print(f"Merged zones: {len(zones)}")
    print(f"Output: {output_csv}")


if __name__ == "__main__":
    main()
