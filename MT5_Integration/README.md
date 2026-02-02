/*

 */
# MT5 Integration Bridge

> A communication bridge between Python (Algorithm) and MT5 Strategy Tester (Visualizer) using Named Pipes.

## Structure

- `PipeServer.py`: Python script to create a named pipe and send commands.
- `PipeClient.mq5`: MQL5 EA to read from the pipe and execute commands (draw lines, pause, etc.).

## Setup

1.  **Python Side**:
    - Run `python PipeServer.py` to start the server.
2.  **MT5 Side**:
    - Compile `PipeClient.mq5` in MetaEditor.
    - Run `PipeClient` EA in Strategy Tester (Visual Mode).

## Commands

- `DRAW_LINE|name|time1|price1|time2|price2`: Draw a trendline.
- `WAIT`: Pause execution (for step-by-step debugging).
- `NEXT`: Resume execution for one step.
