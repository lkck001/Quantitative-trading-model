# Triangle Opportunity Detection

## Purpose
- Implement triangle-pattern opportunity detection as a standalone module.
- Current focus: Phase A only (accumulation pre-filter), no ZigZag/triangle fit yet.

## Structure
- `docs_resources_triangle/`: extracted notes and design docs
- `src/`: detection logic and utilities

## Status
- Phase A script is implemented:
  - `src/build_accumulation_labels.py`
  - Covered steps: preprocessing + sliding windows + accumulation pre-filter
  - Output file: `accumulation_labels.csv` (for MT5 overlay rendering)

## Run Phase A
```bash
python src/AsipanEnergyTradingSystem/modules/opportunity_detection/triangle/src/build_accumulation_labels.py
```

Useful parameters:
- `--input-csv`
- `--output-csv`
- `--timeframe-minutes` (default `15`)
- `--window-days` (default `2`)
- `--thr-range`, `--thr-slope`, `--thr-flip`

Default output schema:
- `zone_id, symbol, timeframe`
- `window_start, window_end`
- `zone_low, zone_high`
- `range_atr_ratio, slope_norm, flip_count`
- `pass_flag, score, window_count, bar_count`
