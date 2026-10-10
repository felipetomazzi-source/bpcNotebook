# DEMREVID003 Script conversion

Branch: `codex/SSNG-3218-fixture-validation`.

The saved DEV notebook is **DEMREVID003 - Script allocation**, ID `E82AEA36D1571FE1B18BD135480E4C5E`, revision 6 (with explanatory Script comments), in environment `CH_PLANNING`, model `DEMREVID`. All 21 Script cells passed SAP syntax validation and completed a real `Actual` / `2026.006` run. That operational run produced 20,482 replacement records and 2,513 legacy change-set records; its complete datasets and stage outputs are retained in the application. It is a simulation, with no financial posting or Script Logic allocation binding.

## Try the calculation

1. Open BPC Notebook and search for **DEMREVID003 - Script allocation** in `CH_PLANNING` / `DEMREVID`.
2. On Setup, select CATEGORY **Actual** (case sensitive) and TIME **2026.006**, the known nonempty period. Select the explicit reference periods needed by the rules, including `TIME_NA`; the supplied definition also includes `2026.007` and a metadata-resolved one-period lookback. Changing output TIME requires reviewing these reference selections, rather than assuming year/month names.
3. Save the selections. Execute the stages in order, or run all. To restart at a later stage, use execution through that stage so its dependencies are current. Selection edits invalidate previous outputs.
4. Inspect each stage's explanation and control tables. Intermediate calculations stay on SAP in complete native tables. A preview can show only a bounded sample.
5. In the final reconciliation stage, inspect `FINAL_REPLACEMENT` and `FINAL_DELTA`. The latter preserves legacy `CT_DATA` change-set semantics: changed records carry replacement amounts, and disappeared old records carry zero clears. It is not a table of arithmetic new-minus-old differences.

Do not bind this notebook to posting until full nonempty comparisons, authorization checks and the intended caller transaction have been accepted. Current calculation evidence is in `native-evidence.json` and `live-evidence.json`; generic runtime evidence is separate in `docs/evidence/native-script-compact.json`.

## Verified calculation results

All nine nonempty controlled cases passed with identical retained facts and dimension metadata: standard suppression on/off, fallback, rounding, negative revenues, connection carry-forward on/off and HSNS on/off. Comparison includes all 20 dimensions, duplicate multiplicity and exact native seven-decimal amounts, for both replacement tables and legacy change sets, including disappeared-record clears.

The complete live input for `Actual` / `2026.006` contained 44,110 records. Both original-versus-Script comparisons passed with zero added, missing or changed records:

| Suppression | Replacement records | Legacy change-set records |
| --- | ---: | ---: |
| On | 20,482 | 2,513 |
| Off | 20,496 | 2,529 |

`live-evidence.json` also records the automatic read summary and effective output/reference period diagnostics. These results establish the tested selection and controlled paths; they are not acceptance of every customer category/period, a restricted-user scenario or financial posting.

`PREVIEW_ROWS` controls automatic dataset previews. Explicit Script `show` tables use the platform's 5,000-row cap. Their total source counts remain visible. Neither preview supplies downstream calculations. For multiple suppression groups, the advanced input definition can use a string for `FFLASMATGROUPS` with the original comma-separated flag values; the Script preserves the original independent sorting/deduplication and positional pairing of the ID and flag ranges.

The operational definition contains 21 visible Notebook Script stages. Complete native SAP working tables and retained metadata connect the stages; browser previews never supply calculation inputs. The business rules are in `cells/*.bns`, generated from the reviewed rules in `build.cjs`. There is no call to the model-specific allocation engine in the operational cells.

The native compiler and original-versus-Script checks must pass before this definition is offered as a posting replacement. `build-status.json` records compilation; an empty generated source means the cell has not compiled and the definition must not be uploaded.

`build-validation.cjs` constructs a separate nonposting validation notebook. Its fixture preparation and comparison cell use ABAP only to supply authorized complete inputs and call the original implementation as an independent oracle. Every operational stage remains Script. Comparison retains duplicate multiplicity and canonicalizes both complete tables by all dimensions and signed amount before exact ordered comparison.

Required checks: nonempty standard/fallback/rounding/negative/HSNS/connection carry fixtures, suppression on/off, zero clears for disappeared output records, then the known nonempty `Actual` / `2026.006` live input. Platform runtime checks alone do not prove calculation equivalence. Neither notebook publishes a financial posting result.

## Reproduce the validation

Set `BPC_ADT_TOOL_ROOT` to the installed ADT MCP package directory. The tools reuse configured credentials without printing them.

```powershell
node examples/demrevid-script/build.cjs
node examples/demrevid-script/build-validation.cjs
node examples/demrevid-script/verify-native.cjs --notebook=<validation notebook ID>
node examples/demrevid-script/verify-native.cjs --live=true --notebook=<live comparison notebook ID>
```

The harness validates every cell before executing. `--resume-run=<run ID>` resumes polling the first submitted case after a polling interruption; it does not rerun or alter that immutable run. A transient run-document publication race receives bounded retries. Failures remain failures.

`save-notebook.cjs` creates the operational notebook or updates only its recorded ID with an optimistic revision check. It validates all 21 cells after saving. Existing ABAP demonstration notebooks and user drafts are preserved.

The comparison harness now retains complete fact tables and 14 authorized dimension bundles, with explicit hierarchy resolutions, under one capture identifier. Every Script stage and the original validation reader use those retained inputs. Missing metadata fails instead of falling back to live values. Captures are sequential, rather than one database-wide transaction, and should be coordinated with master-data maintenance. See `docs/metadata-fixtures.md` for the contract and retry restrictions.

The original's optional metadata reader is deployed through `codex/SSNG-3218-notebook-metadata-validation` in the Chorus ABAP repository. Its normal business path and `ZCL_BPC_DEMREVID_CALC_003` business source remain unchanged. That DEV branch retains the previously deployed NPL baseline, including its existing temporary BW enrichment workaround; review that baseline separately before any customer transport. `original-metadata-deployment.json` records source readback.

Before any posting migration, restricted-user authorization and caller posting/rollback acceptance remain required. The original's old-output read scope includes `TIME_NA`; the notebook's strict posting scope must explicitly account for any legacy clears there. No production LGF or posting handler has been replaced.

Display values are now capped at 4,096 characters and cell previews at eight MiB, including historical outputs. This keeps metadata packet previews manageable while preserving complete native datasets and exact financial amounts. See `docs/preview-bounds.md` for the display contract.

Technical name: `DEMREVID003_ALLOCATION`. Description: `DEMREVID003 demand revenue allocation`. These are assigned to the existing UUID through the identity sidecar; saved calculation revision 2 and historical executions are unchanged. The technical name is unique within the exact SAP client/environment/model and remains immutable. Future package integration must resolve it with the selected context and an explicit approved revision; assigning the name does not enable posting.


Revision 6 adds explanatory comments to all 21 Script cells. Native validation and exact readback passed; generated calculation bodies, dependencies and current input selections are unchanged. Existing execution history is retained. `comments-evidence.json` records this check.
