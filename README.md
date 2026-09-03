# OpennessLLM

OpennessLLM is a Windows command-line tool for LLM-assisted engineering with
TIA Portal Openness. It inventories and exports engineering objects, maintains a
reviewable filesystem clone of PLC/HMI sources, and applies approved changes
through explicit safety gates.

Current version: `0.12.3`. Created by `Zibitpnz`.

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
`check-clone` again before applying.

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

`apply-clone` always runs a strict preflight first, including dry-runs. It writes
`apply-clone-preflight-summary.txt`, `apply-clone-preflight-plan.csv`,
`apply-clone-preflight-issues.csv`, and JSONL projections under `_metadata`.
If any preflight issue has severity `error`, `--apply` stops before the first
TIA write. On real `--apply`, the preflight also exports the live TIA source for
existing blocks that will be changed/renamed/deleted and compares it with
`CurrentSourceSha256` from the latest `check-clone`; if TIA changed after the
check, apply is refused.

`check-clone` publishes `clone-check-blocks.csv`,
`clone-check-groups.csv`, `clone-check-source-blockers.csv`, and the summary as
one evidence bundle committed by `clone-check-bundle.json`. `apply-clone` and
`sync-clone` reject a missing/incomplete marker, mismatched run IDs, row counts,
or SHA-256 hashes. `sync-clone` also uses the exact compare directory named by
the marker and rechecks current-source hashes before changing `_root`. Bundle
schema 2 also binds the normalized TIA project path, project version, stable
project object identifier when available, and the selected `SoftwarePath` set.
`apply-clone` validates all of these against the open project before constructing
a plan or invoking any TIA write method. A schema-1 bundle must be refreshed by
running `check-clone` again.

For new clone-only blocks, an optional sidecar file can be placed next to the
source file:

```text
MyNewBlock.scl
MyNewBlock.scl.meta.json
```

Supported flat sidecar fields are `blockKind`, `numberMode`, `number`,
`autoNumber`, `programmingLanguage`, `name`, `instanceOfName`, `softwarePath`,
and `sourceOrigin`. When a
sidecar exists, it wins over the filename numeric prefix. Without a sidecar,
the old shorthand still works: a numeric prefix on a clone-only filename means
"request this manual block number".

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
same normalized content. A pre-existing same-identity block is not adopted.
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
.\OpennessLLM\run.cmd apply-clone --attach --out .\CLONE_PROJECT --apply
```

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
