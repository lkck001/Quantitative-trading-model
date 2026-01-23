# Quantitative Trading Model (QTM)

## Project Overview
This project is an automated trading system based on pattern recognition (ZigZag, DTW) and structural analysis.
It aims to identify specific market structures (e.g., channels, breakouts) and execute trades based on confirmation triggers.

## Project Structure
- `src/`: Source code
  - `strategies/`: Trading strategies (ZigZag, Pattern Matching)
  - `data_loader/`: Data fetching and processing
  - `utils/`: Helper functions (plotting, math)
  - `backtest/`: Backtesting engine
- `Data/`: Historical market data (CSV)
- `config/`: Configuration files
- `notebooks/`: Jupyter notebooks for research
- `legacy/`: Archived old files

## Setup
1. Create virtual environment: `python -m venv Trading`
2. Activate venv: `.\Trading\Scripts\activate`
3. Install dependencies: `pip install -r requirements.txt`

## Usage
Run the main entry point:
```bash
python main.py
```
