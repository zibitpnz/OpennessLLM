# Changelog

All notable changes to OpennessLLM are recorded in this file.

## Unreleased

- `check-clone` now publishes its block, group, source-blocker, and summary
  reports as one fail-closed evidence bundle. `clone-check-bundle.json` is
  committed last and binds a schema version, `CheckRunId`, row counts, hashes,
  and the exact compare directory. `apply-clone` / `sync-clone` reject missing,
  interrupted, tampered, or cross-run bundles before mutation.
- `sync-clone` no longer guesses the newest `_compare` directory; it consumes
  the directory bound to the validated bundle and verifies current-source
  hashes before copying.
- Source-blocker write classification is now a single shared helper
  (`SourceBlockedStatusBlocksWrite` / `BlockingSourceBlockedRows` /
  `BlockingSourceBlockerCount`) used by every pre-write gate, the after-write
  verification, the formatting-reconciliation pass, `status` / `check-all`,
  `init-workspace`, and `clone-check-source-blockers.csv`. These paths can no
  longer disagree about whether the project is writable.
- A `source-blocked-*` row blocks `apply-clone` / `sync-clone` unless it is
  `source-blocked-current-only` **and** (a) no `removed` clone row could be the
  same block by number or name, **and** (b) no `removed` clone row without the
  exact durable `explicit-new-local-source` sidecar origin shares its block
  number space or has an unknown number space. `CloneProvenance` is now `tracked-baseline`,
  `explicit-new-local-source`, or fail-closed `unknown-orphaned`. (b) fails
  closed on a tracked block that
  changed both name and number before conversion. `source-blocked-language-converted`,
  `source-blocked-export-error`, and any unknown `source-blocked-*` status always
  block. A loose source without the exact origin assertion receives no
  new-block exemption, including when `plc-blocks.csv` is missing or partial.
  Manifest rows also retain `tracked-baseline` provenance when their `_root`
  source file is missing, so deleting the source cannot erase tracking history.
- Clone matching and ambiguity checks are scoped by `SoftwarePath`; missing
  software scope fails closed where identities could overlap. Loose sources do
  not inherit the first manifest software path, and explicit-new provenance
  requires a nonempty sidecar `softwarePath`.
- Safety-critical origin metadata is accepted only from a complete, valid flat
  JSON sidecar. Malformed/nested sidecars, invalid JSON escapes, and unescaped
  control characters remain `unknown-orphaned`; JSON whitespace, literals, and
  numbers use their case-sensitive, ASCII-digit standard grammar.
- A structurally conflicting `added` + `removed` pair that may identify the
  same block (including an unscoped orphan paired with a scoped live block) now
  invalidates the evidence bundle before apply/sync mutation. Distinct report
  rows that touch the same physical `_root` path are also rejected regardless
  of `SoftwarePath`.
- Missing or unrecognized number spaces on tracked/unknown removed sources now
  overlap every live block number space for conservative source-blocker
  classification.
- Successful `check-clone` removes its empty staging parent; interrupted
  `_check-publish` content is recognized and backed up by
  `init-workspace --force` as generated workspace state.
- `BlockingSourceBlockerCount` recomputes from the full block report AND
  cross-checks `clone-check-source-blockers.csv` (`Severity=error` rows; older
  reports without the column fail closed), after bundle integrity validation.
- `sync-clone` now loads the dedicated source-blocker report and uses the same
  cross-report gate as `apply-clone`; the gate runs before any clone file,
  backup, manifest, or sync report mutation.
- Missing, blank, or unknown `Severity` values and malformed dedicated
  source-blocker rows fail closed. Only an explicit `warning` on
  `source-blocked-current-only` with usable software/block identity is
  non-blocking.
- `clone-check-source-blockers.csv` emits `Severity=warning` for a non-blocking
  `source-blocked-current-only` row and `Severity=error` for blocking rows.
- `status` / `check-all` report a separate `informationalSourceBlockers` count
  and no longer mark `ReadyForApply=no` for non-blocking source blockers.
- Added offline regression tests `source-blocker-classification-shared`,
  `source-blocker-report-severity`, `source-blocker-after-write-and-sync`,
  `source-blocker-tracked-identity-change` (incl. both-name-and-number change),
  `source-blocker-report-cross-check`, and
  `sync-clone-source-blocker-cross-report-gate`, plus interrupted bundle and
  durable-origin regression cases.
- Documentation now states explicitly that `apply-clone` does not compile;
  interface regressions are detected only by a subsequent external
  `compile-all --apply` in the full workflow.
- Verification result: `self-test` passed `36/36`.

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
