# OpennessLLM

OpennessLLM is a Windows command-line tool for LLM-assisted engineering with
TIA Portal Openness. It inventories and exports engineering objects, maintains a
reviewable filesystem clone of PLC/HMI sources, and applies approved changes
through explicit safety gates.

Current version: `0.12.11`. Created by `Zibitpnz`.

## What It Does

- inventories PLC and HMI objects through TIA Portal Openness;
- exports PLC source and XML representations for inspection;
- maintains a diffable `CLONE_PROJECT` workspace and guarded apply workflow;
- extracts and patches selected HMI texts and screen geometry;
- builds runtime offset maps for classic non-optimized Global and Instance DBs;
- provides guarded PLC runtime reads, snapshots, and explicit opt-in writes;
- produces machine-readable reports suitable for LLM and automation workflows.

## Requirements

- 64-bit Windows with Windows PowerShell;
- .NET Framework 4.x, including the 64-bit C# compiler used by `build.ps1`;
- a locally installed and licensed TIA Portal for commands that use Openness;
- membership in the local `Siemens TIA Openness` Windows group;
- access to the matching TIA Portal PublicAPI installation.

The repository does not contain or redistribute Siemens DLLs, TIA Portal, or a
TIA project. PublicAPI assemblies are discovered from the local installation at
runtime. The tool is primarily developed against TIA Portal V21 and also
recognizes the V20 PublicAPI layouts described in the changelog.

## Safety

Read and inspect commands are separated from write commands. Potentially
destructive actions use dry-run behavior, preflight reports, explicit `--apply`
flags, and additional confirmation flags where appropriate. Review
[`SAFETY_GATES_RU.md`](SAFETY_GATES_RU.md) before connecting the tool to a
production engineering project or controller.

PLC and HMI automation can affect real machinery. Validate generated changes in
an offline copy, keep project backups, compile in TIA Portal, and follow the
site's commissioning and functional-safety procedures.

## Project Status

The tool is under active development. Interfaces and generated metadata may
change between versions. Use the offline self-test before working with a new
build:

```powershell
.\OpennessLLM\run.cmd self-test --out .\OpennessLLM\out\self-test-current
```

Version commands:

```powershell
.\OpennessLLM\run.cmd version
.\OpennessLLM\run.cmd --version
```

## Documentation

- [`LLM_START_HERE_RU.md`](LLM_START_HERE_RU.md): model-neutral startup protocol;
- [`COMMAND_REFERENCE_RU.md`](COMMAND_REFERENCE_RU.md): detailed CLI reference;
- [`WORKFLOWS_RU.md`](WORKFLOWS_RU.md): practical operating workflows;
- [`SAFETY_GATES_RU.md`](SAFETY_GATES_RU.md): write-safety rules and gates;
- [`INTERNALS_RU.md`](INTERNALS_RU.md): architecture and validation logic;
- [`TROUBLESHOOTING_RU.md`](TROUBLESHOOTING_RU.md): common failures and recovery;
- [`CONTRIBUTING.md`](CONTRIBUTING.md): contribution and test workflow;
- [`SECURITY.md`](SECURITY.md): private vulnerability reporting guidance;
- [`CHANGELOG.md`](CHANGELOG.md): version history.

## Disclaimer

This independent project is not affiliated with, endorsed by, or sponsored by
Siemens. Siemens, TIA Portal, and related product names are trademarks of their
respective owners and are used only to describe compatibility.

## License

OpennessLLM is available under the [MIT License](LICENSE).

## Build

The examples below assume that the current directory is a workspace containing
the cloned repository in `OpennessLLM`. The `.cmd` wrappers also work when local
PowerShell execution policy blocks direct `.ps1` execution.

```powershell
.\OpennessLLM\build.cmd
```

## Run

```powershell
.\OpennessLLM\run.cmd
```

Useful options:

```powershell
.\OpennessLLM\run.cmd tree --headless --max 1000
.\OpennessLLM\run.cmd inventory --headless
.\OpennessLLM\run.cmd export-xml --headless
.\OpennessLLM\run.cmd inspect --headless
```

Initialize a filesystem clone under `CLONE_PROJECT`:

```cmd
.\OpennessLLM\run.cmd init-clone --attach --out .\CLONE_PROJECT
```

Check whether the current TIA project differs from `CLONE_PROJECT`:

```cmd
.\OpennessLLM\run.cmd check-clone --attach --out .\CLONE_PROJECT
```

For large projects, PLC clone/status commands can be focused on one software
path/name, and combined PLC/HMI status commands can be focused on one HMI
target:

```cmd
.\OpennessLLM\run.cmd init-clone --attach --out .\CLONE_PROJECT --software-path "PLC_1"
.\OpennessLLM\run.cmd status --attach --out .\CLONE_PROJECT --software-path "PLC_1" --hmi-target-path "HMI_1"
```

`init-clone` and `check-clone` require exactly one selected `PlcSoftware`; use
`--software-path` when the project contains more than one PLC. For write safety,
`apply-clone` currently fails closed if the open project contains multiple
`PlcSoftware` objects, even when the evidence bundle was created with a filter.

Accept the latest `check-clone` result into `CLONE_PROJECT`:

```cmd
.\OpennessLLM\run.cmd sync-clone --out .\CLONE_PROJECT
```

When `check-clone` reports blocks added directly in TIA Portal, `sync-clone`
accepts them into both the human CSV view and machine metadata, including
`SoftwarePath` in `plc-blocks.csv` and `_metadata\blocks.jsonl`.
The command builds the complete replacement `_root`, manifests, and metadata
under `_sync-staging` first. Any file/group operation error returns non-zero and
leaves the current baseline plus its authorization bundle unchanged. Commit
uses `_sync-backups` and rolls back installed outputs if publication fails.
Immediately before commit, `sync-clone` revalidates the live workspace inventory;
accepted added/changed/moved sources receive a normalized `tracked-baseline`
sidecar so stale one-shot provenance cannot survive the transaction.

Apply changed clone source files back into TIA Portal through External Sources:

```cmd
.\OpennessLLM\run.cmd apply-clone --attach --out .\CLONE_PROJECT
.\OpennessLLM\run.cmd apply-clone --attach --out .\CLONE_PROJECT --apply --save
```

`apply-clone` supports changed existing blocks, clone-only source files,
clone-side deletes, and renames inside the same block group. If a clone-only
block is placed in a new nested folder, the missing TIA block-group path is
created before the block is generated. Clone-side moves between block groups are
intentionally rejected: TIA Openness does not expose a safe public block move
API, and delete/recreate can break hidden links. Move blocks manually in TIA
Portal, then run `check-clone` and `sync-clone` to accept the project-side move
into the clone.

For a clone-side rename, keep the numeric filename prefix, rename the block in
the source text, and move the adjacent `.meta.json` sidecar with the source when
one exists. `check-clone` recognizes the rename only through a unique matching
PLC/group/type/number identity; an ambiguous match remains blocked.

Instance DB metadata is tracked through the `InstanceOfName` column in
`plc-blocks.csv` and `clone-check-blocks.csv`. New `.db` files are classified as
`GlobalDB` or `InstanceDB` from their source text. `apply-clone` keeps Instance
DB handling conservative: the referenced FB must exist, changing
`InstanceOfName` is forbidden, and Instance DB blocks are applied after FB/FC/OB
sources.

Clone metadata also tracks `AutoNumber`, `NumberMode`, `NumberSpace`, selected
SDK attributes, SHA-256 hashes, and durable `SourceOrigin`. The latter records
whether a source was actually exported (`exported-source`) or was only an
unsupported-language inventory row (`inventory-only-unsupported`); legacy or
contradictory missing-source rows fail closed as `unknown-orphaned`.
`apply-clone` refuses to
write if a clone source file changed after the latest `check-clone`; run
`check-clone` again after every edit, add, delete, rename, sidecar change, or
manifest change and before applying. A real apply always requires both
`--apply` and `--save`. It holds TIA Portal `ExclusiveAccess` for the complete
write/verify/compile/save interval and requires `Project.IsModified=false`
before writing. The high-friction
`--i-accept-saving-preexisting-project-changes` option explicitly overrides an
initial dirty or unavailable state and is recorded as an unsafe audit decision.

`init-clone` and `sync-clone` also write machine-readable metadata under
`CLONE_PROJECT\_metadata`: `clone-manifest.json`, `blocks.jsonl`,
`groups.jsonl`, and `schema-version.txt`. The CSV files remain the convenient
human-readable view; `_metadata` is the versioned machine view for future
automation. The current metadata schema is 4.

Fast PLC block lookup from the local clone metadata:

```cmd
.\OpennessLLM\run.cmd block-info --name 5_HM --out .\CLONE_PROJECT
.\OpennessLLM\run.cmd block-info --number 5 --number-space DB --out .\CLONE_PROJECT --json
```

`block-info` is local-only: it does not attach to TIA Portal and does not open a
project. It reads `CLONE_PROJECT\_metadata\blocks.jsonl`, `plc-blocks.csv`, and
`clone-check-blocks.csv`, so an LLM can resolve block names, numbers, groups,
clone filenames, and check status without searching through source files.

PLC runtime read/write from the live controller:

The address `192.0.2.10` and the DB/field names below are documentation-only
examples. Replace them with values from your own PLC project before running a
runtime command.

```cmd
.\OpennessLLM\run.cmd plc-runtime-map --in .\CLONE_PROJECT --out .\OpennessLLM\out\plc-runtime-map-current
.\OpennessLLM\run.cmd plc-runtime-read --host 192.0.2.10 --db DB_Test_Outputs --var Online --map .\CLONE_PROJECT\_runtime_maps
.\OpennessLLM\run.cmd plc-runtime-snapshot --host 192.0.2.10 --db DB_Test_Inputs --map .\CLONE_PROJECT\_runtime_maps --out .\CLONE_PROJECT\_runtime_snapshots
.\OpennessLLM\run.cmd plc-runtime-write --host 192.0.2.10 --db DB_Test_Outputs --var Output_1 --value true --map .\CLONE_PROJECT\_runtime_maps
```

`plc-runtime-map` mirrors CSV and Markdown maps into
`CLONE_PROJECT\_runtime_maps`. It maps classic non-optimized Global DB data
fields directly from `.db` sources found recursively under `CLONE_PROJECT\_root`
and Instance DB fields through their referenced FB declarations.
`plc-runtime-snapshot` writes read-only captures
under `CLONE_PROJECT\_runtime_snapshots\YYYYMMDD-HHMMSS` and records the actual
S7 read ranges used. `plc-runtime-write` is a dry-run unless both `--apply` and
`--i-know-this-writes-plc` are present. It refuses read-only map rows and rejects
unsafe output masks above 24 bits for the supported output modules.

`apply-clone` always runs an authoritative preflight first, including dry-runs.
Both modes hold `TiaPortal.ExclusiveAccess`, require an accepted project dirty
state, revalidate the complete live block/group/source state, apply the complete
report gate, and hash-verify immutable source staging. A dry-run stops only after
those proofs and never invokes a TIA write method. It writes
`apply-clone-preflight-summary.txt`, `apply-clone-preflight-plan.csv`,
`apply-clone-preflight-issues.csv`, and JSONL projections under
`_apply-reports` (kept outside the hash-bound baseline `_metadata`).
If any preflight issue has severity `error`, `--apply` stops before the first
TIA write. The preflight revalidates the complete current PLC block/group set
and metadata, and re-exports every exportable live source,
including blocks outside the apply plan. Every source hash must still match the
latest `check-clone`; a saved or unsaved unplanned TIA edit therefore blocks the
apply before mutation. TIA object identifiers are also required to remain
continuous whenever the SDK provides them; unavailable identifiers are
explicitly reported as unproven rather than silently treated as proof.
Baseline-to-current matching reserves equal usable TIA object identifiers before
path/name/number fallbacks. A fallback candidate with a different usable ID is
reported as blocking `object-replaced-or-mismatched`; simultaneous rename and
renumber with unavailable IDs is blocking `ambiguous-rename-and-renumber`.
Remaining no-ID number and rename/renumber candidates are evaluated as one
global graph: a non-bijective component is blocking
`ambiguous-object-correlation`, so old-number reuse cannot authorize a rename or
delete plan. A strong path/logical no-ID match is also returned to that graph if
an unmatched current block has source-equivalent content after normalizing only
the top-level declaration name. Correlation ambiguity remains blocking even when
the current visual block cannot be exported, and the candidate list is retained
in the evidence. If the baseline has a usable TIA object ID but the current run
cannot prove it, `object-id-continuity-unproven` blocks apply and sync instead of
erasing the durable identifier.
The complete pre-state export must actually create every requested source file,
must leave `Project.IsModified=false` unless the explicit unsafe override is in
effect. Required live bytes are first copied into immutable staging, then the
owned export is strictly removed before backup or the first TIA write. Cleanup
failure is a before-write blocker and quarantines the export with an audit file.
For a real apply, the filesystem project backup is created under the same
`ExclusiveAccess` lease after all pre-write gates pass. If the clone workspace
is inside the project directory, that active `--out` directory is excluded from
the project backup; its separately versioned/audited clone artifacts are not
TIA project data, and its held workspace lock must remain active through apply.
An incomplete backup directory is removed and never reported as a valid backup.
After backup and immediately before the first TIA mutation, the active workspace
inventory and every staged raw/canonical digest are checked again. Staged sources
remain open with read-only sharing while TIA can consume them, and postconditions
compare the exported result with the digests fixed in the plan rather than
re-reading a mutable expected file. Owned apply staging is removed after the
transaction; a committed cleanup failure is a non-recovery warning with an
audited quarantine path and an explicit local confidentiality-cleanup action.

After writing, each action must satisfy its exact block identity, available
object-ID continuity, and token-stream source postcondition, and the complete
block/group sets must contain no collateral change. Source comments are part of
the accepted content contract, so comment-only edits cannot be discarded as
formatting. Pure rename classification and validation normalize only the
top-level declaration-name token; all attributes, interfaces, body tokens, and
comments must remain equivalent. Validation uses an immutable copy of the freshly
exported pre-write source. Temporary External Sources must be deleted and the
complete ExternalSource collection must remain stable before saving. Only
plan-explained formatting, assigned-number, rename, sidecar, and manifest
transitions may be reconciled. `apply-clone` then compiles
the broadest supported project/software target and refuses to save on any
compiler error. Fresh pre-save and post-save inventories must remain clean and
stable; the durable clone baseline is published only from the post-save snapshot.

`check-clone` publishes `clone-check-blocks.csv`,
`clone-check-groups.csv`, `clone-check-source-blockers.csv`,
`clone-check-workspace.csv`, and the summary as
one evidence bundle committed by `clone-check-bundle.json`. Before API
resolution or TIA attach, a durable `clone-check-attempt.json` revokes any old
authorization. Reports first have state `reports-prepared`; only after the outer
clean-project and fresh-inventory checks does the marker transition to
`authoritative-complete`, after which the attempt sentinel is removed.
`apply-clone` and
`sync-clone` reject a missing/incomplete marker, mismatched run IDs, row counts,
or SHA-256 hashes. `sync-clone` also uses the exact compare directory named by
the marker and copies signed current/workspace inputs under read leases into
owned hash-checked files. The complete publish tree is checked against an exact
file/directory allowlist, source/sidecar/manifest/metadata cross-references are
validated under read locks, and commit reads only a hash-bound immutable ZIP
package. Bundle schema 7 also binds the tool version, matcher revision, write-safety policy,
normalized TIA project path, project version, stable
project object identifier when available, the selected `SoftwarePath` set, and
a sorted inventory of every source, sidecar, manifest, and `_metadata` file.
`check-clone` holds `TiaPortal.ExclusiveAccess` while collecting the complete
live inventory, exporting sources, and publishing its marker, and requires a
saved clean project before and after export. It builds its diff and inventory
from one immutable local snapshot, cross-checks every clone-source hash, and
verifies the live workspace again immediately before publishing the marker.
The old marker is invalidated before authoritative collection starts; attach,
open, crash, and final-validation failures leave the durable attempt sentinel,
so no stale or provisional bundle is accepted. Temporary local snapshots are
lease-owned and deleted strictly; a failed deletion fails the command and moves
the owned directory to an audited quarantine when possible. Clone workspace
paths and recursive copies reject reparse points, junctions, and symlinks. All clone commands
serialize through an exclusive `.opennessllm-workspace.lock` file inside the
workspace; this control file is ignored by `init-workspace --force` backup
classification and is never moved as generated content. A strict schema-4
publication journal binds its owner, canonical workspace, operation, transaction,
staging owner, immutable package, installation directory, and every old/new
component fingerprint. The package is fully extracted and verified in a
transaction-owned directory before any old component is moved to backup. Each
complete component is then installed by a same-volume rename, so process death
during extraction cannot leave a partial active `_root`, metadata, or CSV file.
After preparation, both publishers revalidate against the ORIGINAL authoritative
workspace inventory. Old objects are captured with Windows handle-based renames
and journaled volume/file IDs, then the captured tree is checked against that
same inventory and the original fingerprints under file read leases before any
new component is installed. Late edits are rejected, not silently accepted as
a new old-state hash. Before `captured-verified`, recovery returns identified
captured objects (including editor changes) only to absent original paths;
untouched active data is never deleted. Missing/replaced capture evidence or a
recreated active destination stops recovery with both sides retained. Capture
requires Windows `FILE_ID_INFO` and same-volume handle renames; unsupported
filesystems fail closed. These filesystem IDs are unrelated to TIA object IDs.
Recovery validates the complete record and all participating paths before the
first mutation; an unproven final component is never deleted. Strict rollback
binds each displaced object to a journaled Windows file ID and renames that
handle into the transaction backup's permanent `_rollback` directory, outside
disposable installation staging. Its captured content is checked against the
recorded new fingerprint under file read leases AFTER the rename, before
restoring the old component. Edited/missing/replaced/unbound captures stop
recovery with the journal, old baseline and captured data retained for manual
inspection; retries check these captures before any further mutation. The
captures are checked again before finalizing rollback and are NEVER deleted by
recovery, even when verification succeeds. This retention also protects edits
made through old editor handles after verification; it does not promise to
detect edits made after recovery has finished. Inspect and reconcile both
versions before explicitly removing these backups. Outer staging cleanup also
retains nested rollback backups after their journal has been consumed. Cleanup
retains staging, package, and owner marker at their original paths while a
publication journal remains, including when a temporary I/O error interrupts
rollback. The next clone
command deterministically restores an interrupted transaction before other
work, and a recovered post-save apply never resurrects its pre-apply
authorization marker. Each publication backup contains
`publication-completion.json` with one of the durable states `not_committed`,
`committed`, or `committed_with_diagnostic_failure`, so a failed optional report
write cannot make an already committed operation look safe to repeat. A locked
completion file is also a diagnostic failure after verified commit and does not
revoke the verified apply bundle. If the completion file still says
`not_committed`, a retained journal with `state=committed` takes precedence; the
next clone command verifies the installed state and updates completion before
removing the journal/package. A failure reopening the journal for flush after
its atomic replacement does not prove that commit failed. Recovery distinguishes
verified commit, completed rollback, aborted capture, and unresolved outcome from
the ON-DISK journal and component verification, never the in-memory state alone.
A verified commit returns through the committed-diagnostic caller branch; apply
still runs its mandatory post-commit verification. Original I/O diagnostics are
preserved even if later completion/report writes fail too. An unreadable journal
or failed installed-state verification remains unresolved, with evidence retained,
not a claimed rollback or successful commit. Mandatory recovery at command entry
blocks new work while a previous transaction's completion cannot be finalized.
Older journal schemas require manual inspection
with all transaction evidence retained. Bundles from earlier tool/policy versions
must be refreshed with `check-clone` (current policy: `clone-write-policy-v12`,
publication journal schema `5`, check-bundle schema still `7`).

The journal and the abrupt-child regression test cover managed failures and
unexpected process termination while the filesystem state retained by Windows
remains available. They do not claim power-loss, kernel-crash, controller-cache,
or storage-device ordering guarantees: directory entry moves/deletes have no
explicit volume-level durability barrier in this implementation. After such a
system/storage event, inspect the journal, publication backup, and active
components and run a fresh authoritative check instead of assuming automatic
recovery is sufficient.
`init-workspace` and the bundle-producing PLC portion of `status` / `check-all`
use the same authoritative lease and clean-project rules. A successful command
that found no selected PLC software, or `init-workspace` returning
`ExistingWorkspace` before a PLC check, closes the refresh attempt without
creating PLC authorization and keeps any previous PLC bundle revoked. A PLC
evidence failure remains a command failure even after status diagnostics have
been written; provisional evidence is never promoted.
`apply-clone` validates all of these against the open project before constructing
a plan or invoking any TIA write method. Any pre-schema-7 or mismatched-policy bundle must be
refreshed by running `check-clone` again.

When `TiaObjectId` is unavailable, no implementation can prove engineering-object
continuity for every combination of replacement plus rename, renumber, and
substantial source edits. OpennessLLM blocks ambiguous/source-equivalent shadow
cases and reports the remaining permitted logical match as explicitly
`unproven`; operators must retain this limitation in their safety assessment.

Every new clone-only block must have a sidecar file next to the source file:

```text
MyNewBlock.scl
MyNewBlock.scl.meta.json
```

Supported flat sidecar fields are `blockKind`, `numberMode`, `number`,
`autoNumber`, `programmingLanguage`, `name`, `instanceOfName`, `softwarePath`,
and `sourceOrigin`. The sidecar wins over the filename numeric prefix and must
contain nonempty `softwarePath` plus
`"sourceOrigin":"explicit-new-local-source"`. A filename numeric prefix alone
does not authorize creation.
Loose `unknown-orphaned` sources are never authorized to update or rename an
existing TIA block. `UpdateSource`, `RenameBlock`, and
`RenameAndUpdateSource` require `tracked-baseline`; intentional adoption or
recovery must go through `sync-clone` or a separate explicit workflow.

A source discovered outside `plc-blocks.csv` has fail-closed
`unknown-orphaned` provenance. To assert that it is intentionally new local
input, set `"sourceOrigin":"explicit-new-local-source"` in its sidecar; this is
the only loose-source origin that receives the new-block exemption from the
ambiguous visual-block gate. A nonempty `softwarePath` in the same valid flat
JSON sidecar is required; malformed/nested metadata or invalid JSON escapes
remain `unknown-orphaned`. This origin is one-shot: only a successful
`CreateBlock` operation can issue a promotion receipt. The receipt binds the
check run, selected PLC, target identity, source hash, language, and resulting
live object; promotion additionally requires an exportable live source with the
same canonical content (formatting-only differences are allowed). A
pre-existing same-identity block is not adopted.
Whitespace-only formatting may differ, but comments are significant canonical
content and must match.
The recoverable `_manifest-publish` transaction rewrites the sidecar origin to
`tracked-baseline` and publishes the manifest as one transition. Recovery
validates the complete journal, staged manifest, sources, identities, and every
sidecar before consuming any sidecar. A direct `init-clone` rerun finishes this
recovery before invalidating the current bundle or writing a new baseline, so a
stale staged manifest cannot later replace the reinitialized manifest. If that
row is later lost, the consumed sidecar becomes `unknown-orphaned` instead of
receiving the new-block exemption again. Delete preflight distinguishes an
untracked TIA-only block from a tracked missing-source block and proves the exact
manifest row to consume before any TIA write; only the latter row is removed
after a successful deletion.

When the project is already open in TIA Portal, use `--attach`:

```cmd
.\OpennessLLM\run.cmd inventory --attach --out .\OpennessLLM\out\inventory-current
.\OpennessLLM\run.cmd export-xml --attach --out .\OpennessLLM\out\export-current --force
.\OpennessLLM\run.cmd inspect --attach
```

Generate readable PLC source files for selected blocks:

```cmd
.\OpennessLLM\run.cmd export-source --attach --name FB_Openness_Test --extension scl --out .\CLONE_PROJECT\source
.\OpennessLLM\run.cmd export-source --attach --name OB1 --extension awl --out .\CLONE_PROJECT\source
.\OpennessLLM\run.cmd export-source --attach --name DB_Main --extension db --out .\CLONE_PROJECT\source
```

Probe the SDK document export API for a selected block:

```cmd
.\OpennessLLM\run.cmd export-documents --attach --name FB_Openness_Test --out .\CLONE_PROJECT\documents
```

Create a filesystem copy of the PLC block group structure under
`CLONE_PROJECT\_root`:

```cmd
.\OpennessLLM\run.cmd clone-folders --attach --out .\CLONE_PROJECT
```

Writes are guarded. Without `--apply`, `set-attribute` is a dry-run:

```cmd
.\OpennessLLM\run.cmd set-attribute --attach --target block --name OB1 --attribute HeaderAuthor --value Codex
```

PLC source edits should go through the guarded clone workflow:

```cmd
.\OpennessLLM\run.cmd check-clone --attach --out .\CLONE_PROJECT
.\OpennessLLM\run.cmd apply-clone --attach --out .\CLONE_PROJECT --apply --save
```

The real `apply-clone` command performs the broadest SDK-supported compile after
post-write verification and before saving. The standalone compile commands below
remain useful for diagnostics and for changes made outside the clone workflow.

Compile one PLC block and print recursive TIA compiler diagnostics:

```cmd
.\OpennessLLM\run.cmd compile-block --attach --name FB_Openness_Test --apply
```

Compile the broadest SDK-supported project/software scope:

```cmd
.\OpennessLLM\run.cmd compile-all --attach
.\OpennessLLM\run.cmd compile-all --attach --apply
.\OpennessLLM\run.cmd compile-all --attach --apply --save
```

Without `--apply`, `compile-all` is a dry-run and lists the compile targets. With
`--apply`, it first tries the broadest available compile target. If the TIA
Openness SDK does not expose a project-level compile provider, it falls back to
all compile-capable software targets, such as PLC software and HMI runtime
software. Compiler output includes nested message descriptions and paths, and
the command exits with an error when TIA reports compile errors.

Delete a PLC block:

```cmd
.\OpennessLLM\run.cmd delete-block --attach --name Openness --apply --save
```

If `--project` is omitted, the tool searches for a single `*.apXX` project file
near the current project folder. The Windows user that runs the tool must be a member of the local
`Siemens TIA Openness` group.

If needed, run this from an elevated PowerShell window:

```powershell
.\OpennessLLM\enable-openness-admin.ps1
```

Then sign out of Windows and sign back in.

If PowerShell script execution is disabled, use the `.cmd` wrappers instead:

```cmd
.\OpennessLLM\enable-openness-admin.cmd
.\OpennessLLM\run.cmd inventory --headless
```
