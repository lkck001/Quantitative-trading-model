# Project Working Rules

## Session Entry

- Every new session must read `SESSION_LOG.md` before analyzing the project,
  running commands, changing files, or proposing the next step.
- Treat `SESSION_LOG.md` as the single source of truth for the current project
  state, active objective, risks, and handoff status.
- Read historical archives only when the current snapshot is insufficient.
  Search `docs/history/` by a specific version, case ID, date, function, or
  error; do not read an entire archive by default.

## Task Scope

- Work strictly within the task explicitly given by the user.
- Before implementation, state the immediate objective and important exclusions.
- Do not add features, refactor, clean up, optimize, migrate data, or introduce
  extra safeguards unless the user requested them.
- Report unrelated findings without modifying them. If a newly discovered issue
  blocks the requested task or requires a material scope change, stop and ask
  the user before expanding the work.
- Stop when the requested acceptance criteria are met; do not continue into a
  follow-up phase without explicit authorization.

## Execution And Agents

- Without an explicit instruction such as “执行”, “开始”, or “继续”, do not
  modify code or run project commands. Inputs beginning with `!` are discussion
  only.
- Use one primary agent by default. Do not start sub-agents unless the user
  explicitly requests delegation, parallel work, or multiple-agent review.
- Prefer the smallest targeted inspection, edit, and validation needed for the
  current task. Do not launch broad audits automatically.

## Change Safety

- Preserve all unrelated user changes in a dirty worktree. Do not reset, clean,
  overwrite, or repair files outside the requested scope.
- Do not operate MT5 with mouse or keyboard automation. The user performs UI
  operations and visual acceptance.
- Do not create or run temporary `ChartScreenShot` scripts.
- Formal opportunity archives may change only through user-explicit annotation
  or `保存结构` actions. Startup, preview, and year/timeframe/case switching must
  not write archive data.
- Keep `MT5_EnergyTrading.mq5.bak`.
- `MT5_Integration/MQL5_Link/MT5_EnergyTrading.mq5` is CP936. Edit it only via an
  external UTF-8 working copy, `apply_patch`, CP936 write-back, strict round-trip
  verification, and MetaEditor compilation.
- Keep `SESSION_LOG.md` and project documentation as UTF-8 with BOM.
- Preserve the project/MT5 junctions as the single source of code and data; do
  not replace them with manual copies:
  - `D:\mt5\MQL5\Experts\MT5_EnergyTrading` points to the project EA directory.
  - `D:\mt5\MQL5\Files\opportunity_annotations` points to the formal archive.
  - `D:\mt5\MQL5\Files\split_by_year` points to the yearly CSV directory.

## Validation

- Validate in proportion to the requested change, starting with the narrowest
  relevant check. Do not turn validation into an unrelated code review.
- For functional changes, verify initialization, the core path, error reporting,
  and final status. Log platform failures with `GetLastError()` where applicable.
- The assistant may perform static checks and compilation; MT5 visual behavior
  remains user-verified.

## Session Log Maintenance

- Keep `SESSION_LOG.md` as a concise current-state snapshot, not a chronological
  transcript. Target no more than 100 lines.
- Update or replace obsolete state instead of appending `Session Continuation`
  sections.
- Keep only the current objective, formal build and data baselines, active risks,
  acceptance criteria, next step, and handoff information.
- Move completed-phase detail, old versions, old hashes, incident timelines, and
  superseded decisions to the existing history archive. Do not place raw command
  output or long design discussions in the current snapshot.
- Update `SESSION_LOG.md` after a major project phase, after changing a formal
  baseline, and before recommending a new session.
