# Quantitative Trading Model (QTM)

## Purpose

The primary production system is the MT5 EA under `MT5_Integration/`.
Python code under `src/AsipanEnergyTradingSystem/` is optional support for
market replay, Forex Tester conversion, and the triangle Phase A experiment.

## Directory Map

- `MT5_Integration/`: production EA source and MT5 integration files; changes
  follow the project rules in `AGENTS.md`.
- `Data/`: local-only market data, formal opportunity archives, derived labels,
  and visual evidence. The MT5 Junctions point to these directories; do not
  create copied data sources.
- `src/AsipanEnergyTradingSystem/`: maintained Python support modules and their
  module-owned documentation.
- `docs/Manuals/`: project-wide documentation standards.
- `docs/Operations/`: operator workflow references, including the transitional
  `CODEX_KEY_PROMPTS.md` source for a future memory-recovery Skill.
- `docs/history/`: completed-phase archives and retired project records.
- `SESSION_LOG.md`: current project state; it is not a chronological transcript.

## Python Dependencies

Python support remains optional and the existing replay launcher still uses
the ignored project-local `Trading/` environment. Keep that environment until
the launcher receives a separate configurable-runtime change:

```powershell
python -m venv Trading
.\Trading\Scripts\python.exe -m pip install -r requirements.txt
```

The replay module has additional dependencies in
`src/AsipanEnergyTradingSystem/modules/replay/requirements.txt`.

## Operating Rules

- Read `AGENTS.md` and `SESSION_LOG.md` before project work.
- Treat `Data/Local_Data/opportunity_annotations/` as formal human-authored
  evidence; only explicit annotation actions may change it.
- Keep generated data, logs, caches, virtual environments, and credentials out
  of Git.
