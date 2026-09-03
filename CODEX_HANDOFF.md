# OpennessLLM Handoff

For a model-neutral startup protocol, read `LLM_START_HERE_RU.md` first.
Detailed docs: `COMMAND_REFERENCE_RU.md`, `WORKFLOWS_RU.md`,
`SAFETY_GATES_RU.md`, `INTERNALS_RU.md`, `TROUBLESHOOTING_RU.md`,
and `CHANGELOG.md`.

`OpennessLLM` is a C#/.NET Framework command-line tool for LLM-assisted TIA
Portal Openness engineering work.

Version: `0.12.3`.

Created by: `Zibitpnz`.

## Build

```cmd
.\OpennessLLM\build.cmd
```

The build creates:

```text
OpennessLLM\bin\OpennessLLM.exe
```

## Version

```cmd
.\OpennessLLM\run.cmd version
.\OpennessLLM\run.cmd --version
```

## Local Tests

```cmd
.\OpennessLLM\run.cmd self-test
```

## Project Bootstrap

For a TIA project folder containing a single `*.apXX` project file:

```cmd
.\OpennessLLM\run.cmd init-workspace --attach --attach-index 0 --out .\CLONE_PROJECT
.\OpennessLLM\run.cmd status --attach --attach-index 0 --out .\CLONE_PROJECT
```

If the folder contains more than one `*.apXX`, pass `--project`.

## PLC Workflow

Production PLC writes go through guarded clone source workflow:

```cmd
.\OpennessLLM\run.cmd check-clone --attach --attach-index 0 --out .\CLONE_PROJECT
REM Edit/add/delete/rename source and sidecar files, then refresh the bundle:
.\OpennessLLM\run.cmd check-clone --attach --attach-index 0 --out .\CLONE_PROJECT
.\OpennessLLM\run.cmd apply-clone --attach --attach-index 0 --out .\CLONE_PROJECT
.\OpennessLLM\run.cmd apply-clone --attach --attach-index 0 --out .\CLONE_PROJECT --apply --save
```

`apply-clone --apply --save` holds `TiaPortal.ExclusiveAccess` across the complete
transaction and requires an initially clean project unless the high-friction
dirty-project override is explicitly recorded. It gates the complete report,
validates exact per-action postconditions, restricts reconciliation to the
immutable plan, compiles before Save, rechecks fresh pre/post-save inventories,
and only then publishes the durable baseline. Clone-only sources require a
sidecar with `softwarePath` and `sourceOrigin=explicit-new-local-source`.

When a block is added manually in TIA Portal and then accepted with
`check-clone`/`sync-clone`, version `0.12.2` keeps `SoftwarePath` populated in
both `plc-blocks.csv` and `_metadata\blocks.jsonl`. Treat an empty
`SoftwarePath` on a newly accepted block as a metadata issue to re-check before
apply work.

Fast PLC block lookup from the local clone metadata:

```cmd
.\OpennessLLM\run.cmd block-info --name 5_HM --out .\CLONE_PROJECT
.\OpennessLLM\run.cmd block-info --number 5 --number-space DB --out .\CLONE_PROJECT --json
```

`block-info` is local-only. It does not open TIA Portal and reads
`CLONE_PROJECT\_metadata\blocks.jsonl`, `plc-blocks.csv`, and
`clone-check-blocks.csv`.

## PLC Runtime Access

Runtime commands provide direct S7comm / ISO-on-TCP access to the live PLC
without opening TIA Portal. Version `0.12.1` specifically extends
`plc-runtime-map` to classic non-optimized Global DB fields from `.db` files,
in addition to Instance DB fields through referenced FB declarations:

The address `192.0.2.10` and DB/field names below are documentation-only
examples and must be replaced with values from the target project.

```cmd
.\OpennessLLM\run.cmd plc-runtime-probe --host 192.0.2.10 --rack 0 --slot 2 --db 210 --start 0 --size 32 --timeout-ms 5000
.\OpennessLLM\run.cmd plc-runtime-map --in .\CLONE_PROJECT --out .\OpennessLLM\out\plc-runtime-map-current
.\OpennessLLM\run.cmd plc-runtime-read --host 192.0.2.10 --db DB_Test_Outputs --var Online --map .\CLONE_PROJECT\_runtime_maps --timeout-ms 5000
.\OpennessLLM\run.cmd plc-runtime-snapshot --host 192.0.2.10 --db DB_Test_Inputs --map .\CLONE_PROJECT\_runtime_maps --out .\CLONE_PROJECT\_runtime_snapshots --timeout-ms 5000
```

`plc-runtime-map` writes CSV, Markdown, per-DB maps, and summary reports to
`CLONE_PROJECT\_runtime_maps`. The map is computed from classic non-optimized
SCL/DB sources under `CLONE_PROJECT\_root` recursively. It maps Global DB
`DATA_BLOCK ... STRUCT ... END_STRUCT` fields directly from `.db` files and maps
Instance DB fields through their referenced FB declarations. It skips `VAR_TEMP`
and `VAR CONSTANT`, aligns FB section boundaries to even bytes, supports quoted
DB field names, and expands nested FBs/structs.

`plc-runtime-snapshot` is read-only and writes `snapshot-summary.txt`,
`snapshot-values.csv`, `snapshot-values.md`, `snapshot-values.json`,
`snapshot-raw.hex`, and `snapshot-read-ranges.csv` under
`CLONE_PROJECT\_runtime_snapshots\YYYYMMDD-HHMMSS`. Large DBs are read
sequentially in ranges up to 222 bytes; inspect `snapshot-read-ranges.csv` before
treating a snapshot as a tight timing slice.

Runtime write is intentionally double-guarded:

```cmd
.\OpennessLLM\run.cmd plc-runtime-write --host 192.0.2.10 --db DB_Test_Outputs --var Output_1 --value true --map .\CLONE_PROJECT\_runtime_maps
.\OpennessLLM\run.cmd plc-runtime-write --host 192.0.2.10 --db DB_Test_Outputs --var Output_1 --value true --map .\CLONE_PROJECT\_runtime_maps --apply --i-know-this-writes-plc
```

Without both `--apply` and `--i-know-this-writes-plc`, it is only a dry-run.
Ask for explicit human confirmation before real PLC runtime writes.

## Compile Diagnostics

Compile one block:

```cmd
.\OpennessLLM\run.cmd compile-block --attach --attach-index 0 --name <block-name> --apply
```

Compile the broadest SDK-supported scope:

```cmd
.\OpennessLLM\run.cmd compile-all --attach --attach-index 0
.\OpennessLLM\run.cmd compile-all --attach --attach-index 0 --apply
.\OpennessLLM\run.cmd compile-all --attach --attach-index 0 --apply --save
```

`compile-all` is guarded as a write command. Without `--apply`, it only reports
the compile strategy and targets. With `--apply`, it first tries a project-level
compile provider; if that is not exposed by the installed TIA Openness SDK, it
falls back to all compile-capable software targets, for example PLC software and
HMI runtime software. Compiler diagnostics are printed recursively, including
nested message paths and descriptions. TIA compile errors make the command fail
with a non-zero exit code.

## HMI Workflow

Read-only HMI analysis:

```cmd
.\OpennessLLM\run.cmd hmi-inventory --attach --attach-index 0
.\OpennessLLM\run.cmd hmi-export-xml --attach --attach-index 0
.\OpennessLLM\run.cmd hmi-digest --in <hmi-export-dir>
.\OpennessLLM\run.cmd hmi-check --attach --attach-index 0 --out .\CLONE_PROJECT
```

Guarded HMI ProjectTexts apply remains the supported write path for selected
text-list/text changes.

## Cleanup

Audit local generated artifacts:

```cmd
.\OpennessLLM\run.cmd clean-local
.\OpennessLLM\run.cmd clean-local --scope probe-generated
```

Real local cleanup requires explicit `--apply`.

## Notes

- Runtime project version is detected from `*.apNN`.
- Matching TIA Openness PublicAPI is resolved by `--api-dir`,
  `TIA_OPENNESS_API_DIR`, registry, or default Portal path.
- Version `0.10.6` accepts both `Siemens.Engineering.Base.dll` under
  `PublicAPI\VXX\net48` and legacy `Siemens.Engineering.dll` under
  `PublicAPI\VXX`; the legacy path is for TIA Portal V20 machines.
- `--software-path` focuses PLC clone/status commands on one software path/name.
- `--hmi-target-path` focuses the HMI part of `status`/`init-workspace` on one
  HMI target path/name.
- Legacy generated PLC XML write commands were removed from production CLI.
