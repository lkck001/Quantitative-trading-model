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

## Documentation

- [Architecture Decision Record](../../../../docs/Manuals/documentation_standards.md)
- [Project Plan](../../project/task_plan.md)

## License

Proprietary
