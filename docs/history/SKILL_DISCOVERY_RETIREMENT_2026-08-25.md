# Skill Discovery Retirement Record

## Decision

The repository-local Skill Discovery project under `.agents/` is retired and
is not part of the current trading project. It must not be downloaded,
installed, executed, or maintained as part of the current workflow.

## Historical Result

- Package version: `2.0.0`, L0-only SkillsMP metadata discovery.
- Offline regression: `23/23` passed.
- Layout, JSON/TOML parsing, CLI bootstrap, and official quick validation
  passed; the official validator used a temporary `PyYAML` installation.
- A real SkillsMP single-page probe completed successfully with 50 deduplicated
  metadata candidates and no automatic selections.
- No third-party Skill was downloaded or installed.
- No MT5 formal archive was changed by the Skill work.

## Replacement Boundary

The former project is removed rather than migrated. If a future memory
recovery or discovery Skill is needed, it requires a separately authorized
design and should live in the Codex Skill environment, not in this repository's
retired `.agents/` tree.
