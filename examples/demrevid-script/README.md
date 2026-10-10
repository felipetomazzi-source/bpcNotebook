# DEMREVID003 Script conversion

Branch: `codex/SSNG-3218-fixture-validation`.

The saved DEV notebook is **DEMREVID003 - Script allocation**, ID `E82AEA36D1571FE1B18BD135480E4C5E`, in environment `CH_PLANNING`, model `DEMREVID`. It has 21 Script cells and all 21 have passed SAP syntax validation. It is a simulation: it publishes complete working datasets and bounded inspection tables, with no financial posting or Script Logic allocation binding.

## Try the calculation

1. Open BPC Notebook and search for **DEMREVID003 - Script allocation** in `CH_PLANNING` / `DEMREVID`.
2. On Setup, select CATEGORY **Actual** (case sensitive) and TIME **2026.006**, the known nonempty period. Select the explicit reference periods needed by the rules, including `TIME_NA`; the supplied definition also includes `2026.007` and a metadata-resolved one-period lookback. Changing output TIME requires reviewing these reference selections, rather than assuming year/month names.
3. Save the selections. Execute the stages in order, or run all. To restart at a later stage, use execution through that stage so its dependencies are current. Selection edits invalidate previous outputs.
4. Inspect each stage's explanation and control tables. Intermediate calculations stay on SAP in complete native tables. A preview can show only a bounded sample.
5. In the final reconciliation stage, inspect `FINAL_REPLACEMENT` and `FINAL_DELTA`. The latter preserves legacy `CT_DATA` change-set semantics: changed records carry replacement amounts, and disappeared old records carry zero clears. It is not a table of arithmetic new-minus-old differences.

Do not bind this notebook to posting until full nonempty comparisons, authorization checks and the intended caller transaction have been accepted. Current calculation evidence is in `native-evidence.json` and `live-evidence.json`; generic runtime evidence is separate in `docs/evidence/native-script-compact.json`.

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

Current validation limitations: fact fixtures are retained across cells, but the original's dimension helpers still need a metadata fixture seam to guarantee identical retained property/hierarchy inputs. Live comparisons without that seam are provisional. Restricted-user authorization and caller posting/rollback acceptance remain separate requirements.
