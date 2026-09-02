# Changelog

All notable changes to OpennessLLM are recorded in this file.

## Unreleased

- Source-blocker write classification is now a single shared helper
  (`SourceBlockedStatusBlocksWrite` / `BlockingSourceBlockedRows` /
  `BlockingSourceBlockerCount`) used by every pre-write gate, the after-write
  verification, the formatting-reconciliation pass, `status` / `check-all`,
  `init-workspace`, and `clone-check-source-blockers.csv`. These paths can no
  longer disagree about whether the project is writable.
- A `source-blocked-*` row blocks `apply-clone` / `sync-clone` unless it is
  `source-blocked-current-only` **and** (a) no `removed` clone row could be the
  same block by number or name, **and** (b) no `removed` clone row the clone
  actually tracked (new `CloneProvenance` column: `manifest` vs `file-scan`)
  shares its block number space. (b) fails closed on a tracked block that
  changed both name and number before conversion. `source-blocked-language-converted`,
  `source-blocked-export-error`, and any unknown `source-blocked-*` status always
  block. A `removed` row for a loose hand-placed `_root` file (`file-scan`) is a
  new clone-only block and does not by itself make an unrelated visual block
  blocking.
- `clone-check-blocks.csv` gains a `CloneProvenance` column.
- `BlockingSourceBlockerCount` recomputes from the full block report AND
  cross-checks `clone-check-source-blockers.csv` (`Severity=error` rows; older
  reports without the column fail closed), taking the max — a partial or stale
  main report can no longer hide a blocker.
- `sync-clone` now loads the dedicated source-blocker report and uses the same
  cross-report gate as `apply-clone`; the gate runs before any clone file,
  backup, manifest, or sync report mutation.
- Missing, blank, or unknown `Severity` values and malformed dedicated
  source-blocker rows fail closed. Only an explicit `warning` on
  `source-blocked-current-only` is non-blocking.
- `clone-check-source-blockers.csv` emits `Severity=warning` for a non-blocking
  `source-blocked-current-only` row and `Severity=error` for blocking rows.
- `status` / `check-all` report a separate `informationalSourceBlockers` count
  and no longer mark `ReadyForApply=no` for non-blocking source blockers.
- Added offline regression tests `source-blocker-classification-shared`,
  `source-blocker-report-severity`, `source-blocker-after-write-and-sync`,
  `source-blocker-tracked-identity-change` (incl. both-name-and-number change),
  `source-blocker-report-cross-check`, and
  `sync-clone-source-blocker-cross-report-gate`.
- Verification result: `self-test` passed `34/34`.

## 0.12.3 - 2026-08-27

- Prepared a sanitized public distribution without project-specific network,
  DB, field, equipment, or filesystem identifiers.
- Generalized the 24-bit `CommandMask` / `AllowedOutputMask` runtime write guard
  so it no longer depends on a project-specific DB name.
- Added an offline regression test for the generalized DWORD output-mask guard.
- Added a public-facing README, MIT license, security policy, contribution guide,
  and Windows CI workflow.
- Verification result: `self-test` passed `28/28`.

## 0.12.2 - 2026-06-27

- Fixed `sync-clone` acceptance of blocks added in TIA Portal.
- New accepted block rows now keep `SoftwarePath` in both `plc-blocks.csv` and
  `CLONE_PROJECT\_metadata\blocks.jsonl`.
- Updated the portable and internal documentation for the metadata fix.
- Verification result: `self-test` passed `27/27`.

## 0.12.1 - 2026-06-27

- Extended `plc-runtime-map` to classic non-optimized Global DBs declared as
  `DATA_BLOCK ... STRUCT ... END_STRUCT`.
- Kept Instance DB mapping through referenced FB declarations.
- Added support for quoted Global DB field names.
- Runtime-map source discovery works recursively under `CLONE_PROJECT\_root`.

## 0.12.0

- Added read-only PLC runtime snapshots in CSV, Markdown, JSON, raw HEX, and
  read-range report formats.

## 0.11.0

- Added direct PLC runtime access over S7comm / ISO-on-TCP.
- Added read-only DB probes, runtime maps, variable reads by name, and guarded
  runtime writes with dry-run behavior by default.

## 0.10.6

- Added TIA Portal V20-compatible PublicAPI resolution.
- Supported both `PublicAPI\VXX\net48\Siemens.Engineering.Base.dll` and the
  legacy `PublicAPI\VXX\Siemens.Engineering.dll` layout.
