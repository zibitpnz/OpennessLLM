# Changelog

All notable changes to OpennessLLM are recorded in this file.

## Unreleased

- Version 0.12.5 closes the review-a3 apply/correlation gaps. Apply staging now
  fixes raw and canonical execution digests in each plan item, holds every staged
  file with `FileAccess.Read` / `FileShare.Read`, and revalidates the workspace
  plus all staged digests after project backup immediately before the first TIA
  write. Postconditions compare against the fixed digest, so changing both the
  staged source and the post-write export cannot redefine the expected result.
- Strong path/logical no-ID matches are reconsidered when an unmatched moved
  block has canonically source-equivalent content. Unsupported visual blocks no
  longer downgrade a correlation ambiguity to an informational warning;
  ambiguity keeps candidate evidence and is reported as `Severity=error`.
  Baseline usable-ID/current-unavailable transitions now block as
  `object-id-continuity-unproven`, and `explicit-new-local-source` is excluded
  from the weak rename/renumber graph.
- Existing-block update/rename operations require `tracked-baseline` provenance;
  `unknown-orphaned` sources fail preflight with
  `UNKNOWN_ORPHANED_SOURCE_FORBIDDEN`. Owned real-apply staging cleanup is now
  audited and quarantined on failure; an already committed operation stays
  accepted and explicitly requires no project recovery.
- Review-a3 regression coverage passes `86/86` offline self-tests, including
  staged-source tampering before create/during backup/after write, visual and
  strong-match ambiguity, durable-ID downgrade, orphan provenance, explicit-new
  graph exclusion, and committed cleanup failure.
- The review-a3 build completed a live TIA Portal V21 forward-and-reverse
  comment-only lifecycle. Both authoritative dry-runs and both real applies
  passed post-backup workspace/staged-digest revalidation, exact postconditions,
  compile (`0` errors, `0` warnings), save, fresh post-save checks, and audited
  staging removal. The final clone check is clean and the pre-existing count of
  legacy authoritative-prestate directories remained unchanged.
- Clone baseline correlation now reserves equal usable `TiaObjectId` pairs
  before path/logical/number fallback. Different usable IDs produce the blocking
  `object-replaced-or-mismatched` status, while rename plus renumber without a
  durable ID produces `ambiguous-rename-and-renumber` and no automatic pair.
  Remaining no-ID candidates are resolved from a global graph; only an isolated
  mutually unique number edge is accepted, while a non-bijective component is
  blocked as `ambiguous-object-correlation`.
- Clone-check bundle schema is now 5 and binds `toolVersion`,
  `cloneMatcherRevision`, and `writeSafetyPolicyRevision`. Bundles produced by
  older matcher/write semantics are rejected by both apply and sync with an
  instruction to run a fresh `check-clone`.
- Verification for the review-a2 hardening passed `78/78` offline self-tests.
  A live TIA Portal V21 schema-5 lifecycle then completed a clean check, a
  one-item comment-only dry-run/apply/compile/save, and the reverse cycle. Both
  compiles finished with zero errors/warnings; each operation left the existing
  authoritative pre-state directory count unchanged and apply staging empty.
- Authorization refresh now completes explicitly with a PLC bundle, without PLC
  authorization, or as an aborted revoked attempt. HMI-only status/init and the
  `ExistingWorkspace` outcome no longer fail merely because no PLC bundle was
  produced; a PLC evidence exception cannot promote provisional reports.
- Complete apply pre-state source export now treats missing generated files as
  errors, repeats the project dirty-state gate after export, and strictly removes
  its owned `_preflight\authoritative-*` directory after immutable staging and
  before backup or the first TIA write. Failed cleanup is quarantined with an
  audit and is reported as a no-mutation before-write failure.
- Authoritative `check-clone`, `init-workspace`, and bundle-producing
  `status` / `check-all` collection now runs under one
  `TiaPortal.ExclusiveAccess` lease, requires a clean project before and after
  export, and invalidates the old marker before collection starts. A failed
  attach, scope check, inventory, export, or final stability check therefore
  cannot leave stale write authorization. TEMP workspace snapshots are
  lease-owned and cleaned on every exit path.
- Real `apply-clone` now compares the complete current-side block/group set,
  full metadata, and every exportable live source hash with the checked bundle
  before its first write, including unselected blocks. Available TIA object IDs
  must match pre-state and satisfy Create/Update/Rename/Delete continuity;
  unavailable IDs are explicitly reported as unproven under the documented
  fail-closed metadata/source policy.
- Temporary External Sources now use mandatory `Delete()` plus absence and
  complete-collection checks. Generation and cleanup failures are aggregated,
  and any cleanup failure prevents `SaveProject`. Pure rename content evidence
  is copied from the fresh live export into immutable apply staging.
- `init-workspace --force` treats the active `.opennessllm-workspace.lock` as a
  trusted control file, neither rejecting it as unknown nor moving it into a
  generated-artifact backup.
- `check-clone` now publishes its block, group, source-blocker, complete sorted
  workspace inventory, and summary reports as one fail-closed evidence bundle.
  `clone-check-bundle.json` is
  committed last and binds a schema version, `CheckRunId`, row counts, hashes,
  the exact compare directory, normalized project path, project version, stable
  project object identifier when available, and selected `SoftwarePath` set.
  `apply-clone` / `sync-clone` reject missing, interrupted, tampered, cross-run,
  or wrong-project bundles before mutation. Schema 5 also binds every source,
  sidecar, PLC manifest, and `_metadata` file by relative path, size, and hash;
  older bundles require a fresh `check-clone`. Diff generation and workspace
  inventory now use the same immutable local snapshot, every clone-source hash
  is cross-checked, and the live workspace is revalidated immediately before
  marker publication.
- Clone operations now hold an exclusive `.opennessllm-workspace.lock` file
  inside the workspace for the complete command. This removes case/temporary
  directory lock aliases; the lock file is excluded from evidence and staging.
- `apply-clone` now resolves its TIA write target from the validated bundle and
  fails closed before plan construction when the open project contains more
  than one `PlcSoftware`. `init-clone` / `check-clone` likewise require one
  selected PLC, with `--software-path` used to scope read-only clone work.
- `explicit-new-local-source` is now a one-shot origin promoted only by a
  successful `CreateBlock` receipt bound to the check run, selected PLC, target
  identity, source hash/language, and resulting live object. Promotion also
  requires an exportable live source with equal canonical content; metadata-only
  adoption of a pre-existing block is forbidden. The one-to-one promotion batch
  and sidecar/manifest publication use a recoverable `_manifest-publish`
  transaction. Recovery validates the complete batch before changing any
  sidecar, and `init-clone` resolves pending promotion state before invalidating
  the bundle or replacing the baseline. Later manifest loss yields conservative
  `unknown-orphaned` provenance instead of resurrecting the exemption.
- Delete preflight now distinguishes a TIA-only block from a tracked block whose
  clone source is missing. The latter carries its immutable clone-side manifest
  identity and proves exactly one row before any TIA write; the former consumes
  none. A successfully completed tracked deletion removes only its proven row
  before the post-apply check.
- Real `apply-clone` now requires `--save`, rejects partial dirty selections and
  every malformed, unknown, export-error, or unplanned report row before the
  first TIA write, and stages the exact checked source bytes. It holds
  `TiaPortal.ExclusiveAccess` for the complete transaction and defaults to
  `Project.IsModified=false`; the explicit
  `--i-accept-saving-preexisting-project-changes` override is audited as unsafe.
- Post-write acceptance now proves exact Create/Update/Rename/Delete identities,
  token-stream source equality, the complete block set, and permitted new group
  ancestors before reconciliation. Reconciliation is restricted to transitions
  explained by the immutable plan. The broadest SDK-supported target is compiled
  before Save and any compiler error blocks persistence. Fresh pre-save and
  post-save inventories/checks must remain clean and stable before `_root`,
  manifests, regenerated metadata, and a new bundle are published transactionally.
- `check-clone` now reconciles a renamed tracked source with its missing old
  manifest path only when PLC, group, language/type, and block number form a
  unique one-to-one match. This keeps rename as one `moved-or-renamed` row
  instead of an unsafe delete/create pair. Explicit-new sources cannot use this
  adoption path. Successful auto-number promotion also persists the assigned
  live number in the tracked sidecar.
- `sync-clone` no longer guesses the newest `_compare` directory; it consumes
  the directory bound to the validated bundle and verifies current-source
  hashes before copying. It stages a complete replacement `_root`, manifests,
  and metadata, publishes only after every operation succeeds, rolls back a
  failed commit from `_sync-backups`, and returns non-zero without changing the
  current baseline/bundle on any staging error. The live workspace inventory is
  checked again immediately before commit, and accepted added/changed/moved
  sources receive a normalized `tracked-baseline` sidecar.
- `plc-blocks.csv` and metadata schema 4 record durable `SourceOrigin` as
  `exported-source` or `inventory-only-unsupported`. A mutable `Status` edit no
  longer erases tracked history; legacy/contradictory missing-source rows become
  fail-closed `unknown-orphaned` evidence.
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
  Normal exportable matches still classify that missing file as an intentional
  clone-side deletion; retained metadata is emitted only when needed as
  ambiguity evidence for an unsupported live block. A completed deletion,
  including the last block in a project, is accepted as a clean after-check.
  A missing manifest row explicitly recorded as `unsupported-language` is not
  treated as tracked source provenance because init-clone never produced a
  source file for that inventory-only visual block.
- Clone matching and ambiguity checks are scoped by `SoftwarePath`; missing
  software scope fails closed where identities could overlap. Loose sources do
  not inherit the first manifest software path, and explicit-new provenance
  requires a nonempty sidecar `softwarePath`. Clone-only creation additionally
  requires `sourceOrigin=explicit-new-local-source`; a numeric filename prefix
  without the sidecar is diagnostic metadata, not write authorization.
- Safety-critical origin metadata is accepted only from a complete, valid flat
  JSON sidecar. Malformed/nested sidecars, invalid JSON escapes, and unescaped
  control characters remain `unknown-orphaned`; JSON whitespace, literals, and
  numbers use their case-sensitive, ASCII-digit standard grammar.
- Canonical SCL/STL equality now serializes a language-aware token stream instead
  of deleting whitespace/comments. Normalized comments are significant canonical
  content, so comment-only edits cannot be silently discarded. Token kinds and
  boundaries, literals, doubled quotes, pragmas/attributes, operators, and STL
  operands remain distinct; unterminated strings/comments fail closed.
- A structurally conflicting `added` + `removed` pair that may identify the
  same block (including an unscoped orphan paired with a scoped live block) now
  invalidates the evidence bundle before apply/sync mutation. Distinct report
  rows that touch the same physical `_root` path are also rejected regardless
  of `SoftwarePath`.
- Missing or unrecognized number spaces on tracked/unknown removed sources now
  overlap every live block number space for conservative source-blocker
  classification.
- Successful `check-clone` removes its empty staging parent; interrupted
  `_check-publish`, `_manifest-publish`, and `_sync-staging` content is recognized and backed up by
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
- Added full transition regressions for post-delete classification,
  explicit-new promotion plus later manifest loss, multi-PLC apply rejection,
  and project-A bundle/project-B apply rejection.
- Added command-path regressions for live-only versus tracked renamed/moved
  deletion, promotion receipt/content checks, duplicate-batch and whole-batch
  recovery, recovery-before-init ordering, pre-mutation multi-PLC rejection,
  durable manifest origin, and transactional sync failure.
- `build.ps1` now propagates the C# compiler exit code so CI cannot report a
  stale executable as a successful build.
- Documentation now reflects compile-before-save inside production
  `apply-clone`; standalone compile commands remain available for diagnostics.
- Added regressions for immutable snapshot publication, case-aliased
  cross-process locking, complete-report export errors, exact postconditions,
  collateral reconciliation rejection, canonical token adversaries, final sync
  fingerprinting, stale sidecar normalization, and the dirty-project gate.
- Verification result: `self-test` passed `68/68`.
- Live TIA Portal V21 validation passed the complete auto-number CreateBlock,
  UpdateSource, RenameAndUpdateSource, and DeleteBlock lifecycle. Every mutation
  satisfied exact postconditions, compiled with zero errors/warnings, saved, and
  ended with a clean schema-4 post-save bundle and no temporary block remaining.
- The hardened build additionally passed an authoritative clean `check-clone`
  and a comment-only `UpdateSource` round trip in TIA Portal V21. The recorded
  complete pre-state was `blocks=2; groups=1; sources=1; errors=0`; exact and
  collateral postconditions passed, unavailable object IDs were explicitly
  reported as `unproven`, compile completed `targets=1; errors=0; warnings=0`,
  Save succeeded, the published bundle was clean, and apply/TEMP staging was
  empty afterward.

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
