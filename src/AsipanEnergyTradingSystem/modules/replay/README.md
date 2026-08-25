# Visual Market Replayer (MVP)

> A lightweight, interactive market replay tool for validating ZigZag algorithms and pattern recognition logic.

## Quick Start

1.  **Install Dependencies**:
    ```bash
    pip install -r requirements.txt
    ```

2.  **Run the Replayer**:
    ```bash
    python run_replay.py
    ```

## Features

- **Step-by-Step Replay**: Simulate real-time market data flow (bar by bar).
- **Interactive Charting**: Based on `lightweight-charts`, supporting zoom, pan, and markers.
- **ZigZag Visualization**: Real-time plotting of ZigZag pivots to verify "repainting" behavior.

## Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `DATA_PATH` | Path to CSV data file | `../data/EURUSD_H1.csv` |
| `ZIGZAG_DEV` | Deviation threshold | `0.0015` |

## Forex Tester Data Conversion

Forex Tester 2 stores imported M1 bars in `data/EditMode/<SYMBOL>/1/Bars.dat`.
Convert a date range to the no-header, nine-column CSV format used by both the
MT5 FULL chart and `feed_replay.py`:

```powershell
python src/AsipanEnergyTradingSystem/modules/replay/src/convert_forex_tester_bars.py `
  "<Forex Tester>/data/EditMode/EURUSD/1/Bars.dat" `
  Data/Local_Data/split_by_year/EURUSD_2003.csv `
  --start 2003-01-01 --end 2003-12-31
```

Use `data/EditMode/EURUSD/1/Bars.dat` as the authoritative M1 source for the
2002–2026 annual exports. Do not use `data/Ticks/EURUSD.dat` for this workflow;
the inspected tick file contains only 2010 data.

The converter does not overwrite an existing output unless `--overwrite` is
provided. The output columns are:

```text
Date,Time,Open,High,Low,Close,TickVolume,RealVolume,Spread
```

## Documentation

- [Architecture Decision Record](../../../../docs/Manuals/documentation_standards.md)
- [Project Plan](../../project/task_plan.md)

## License

Proprietary
