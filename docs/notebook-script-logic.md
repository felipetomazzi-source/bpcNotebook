# Notebook handlers in BPC Script Logic

The `NOTEBOOK` custom-logic BAdI delegates to a named handler bound to a saved notebook revision. It follows the installed `CUSTOM_LOGIC` dispatch pattern, without requiring a calculation-specific ABAP class in each LGF file.

In BPC Notebook, save the notebook with its environment/model, choose **Script Logic**, enter a handler name, and choose **Bind saved version**. Copy the generated block into the relevant logic script. Registration is version checked; replacing an existing mapping is an explicit rebind. Saving subsequent notebook revisions does not change an existing handler.

```text
*START_BADI NOTEBOOK
QUERY = OFF
WRITE = OFF
HANDLER = ALLOC_REVENUES
INPUT_FACTOR = $FACTOR$
INPUT_SUPPRESSZERO = ON
*END_BADI
```

`ALLOC_REVENUES` is an example name: bind it to the intended calculation notebook first. Only supply `INPUT_FACTOR` and `INPUT_SUPPRESSZERO` if that notebook declares `factor` and `suppressZero`. Ordinary cells and Notebook Script cells use the same saved execution path.

## Parameters and current view

- `HANDLER` is required. Handler identifiers are case insensitive, with 1–30 letters, digits or underscores, starting with a letter.
- `INPUT_<name>` overrides a declared notebook input. Number and string inputs retain their types. Boolean overrides accept TRUE/FALSE, ON/OFF, 1/0, or X/empty; they become `true` or `false` in `io->input()`.
- Member/range overrides use comma-separated member IDs. `HIERARCHY_<name>` can select a real hierarchy alongside an explicit selection. SAP resolves nodes to authorized base members; no calendar-year naming convention is assumed.
- Without an explicit member override, an input takes the caller's current-view members for its dimension. Without a matching current-view dimension, the saved selection/default applies. Scalar inputs use saved defaults unless overridden.
- An explicit selection or saved default must stay within any matching caller current-view scope. Unknown inputs, invalid types, unauthorized IDs, hierarchy errors, and widening selections fail the BAdI call.
- Caller current-view filters also constrain model reads for dimensions that are not notebook inputs. Shared execution snapshots retain the original current view, normalized Script Logic parameters, selected IDs, resolved IDs, notebook revision and handler binding revision.

The caller current view must contain authorized base IDs, with at most 10,000 IDs per dimension. A declared range input retains the existing limit of 100 selected IDs. If a caller supplies more IDs for such an input, the invocation fails clearly; it does not truncate them. Notebook adapters inside this first BAdI version use the calling model.

Cells use the existing contracts: `io->input()`, `io->member()`, `io->selection()`, `io->range()`, `io->current_view()`, and `io->script_parameters()`. The latter retains incoming Script Logic parameters and adds the notebook's typed calculation parameters. Declared dependencies receive in-memory copies of preceding cell outputs, with the same dependency access checks used by background runs.

## Execution and outputs

This first implementation runs synchronously and records notebook outputs. It requires an explicit `WRITE = OFF`; missing WRITE or WRITE ON is rejected. It leaves incoming BPC `CT_DATA` unchanged and does not return a preview table for BPC write processing. `QUERY = OFF` avoids an unnecessary initial BPC query; cells read through the validated model adapter as needed.

The handler introduces no COMMIT, ROLLBACK or background-job submission. After every cell succeeds, its output records and completed execution snapshot are staged in the caller's LUW. They become visible in **Execution review** when the caller commits, and disappear if the caller rolls back. Authored ABAP retains the existing trusted-author restrictions; this is not an ABAP sandbox.

Run messages include the execution ID. Exceptions become `CX_UJ_CUSTOM_LOGIC` failures. A failed invocation does not publish partial notebook outputs. BAdI outputs remain external-context results and cannot satisfy ordinary editor-run dependencies; inspect their frozen run directly. To rerun, invoke Script Logic again so it supplies its current view and owns the transaction.

The existing DEV enablement, production block and SAP authorizations remain in force. Handler bindings and notebook revisions must belong to the executing SAP user. Cross-user published handlers and BPC writeback are future extensions.

## Objects and APIs

- `ZBN_NOTEBOOK_BADI`: enhancement of `UJ_CUSTOM_LOGIC`, implementation `ZBN_NOTEBOOK`, filter `CUSTOM_LOGIC_NAME = NOTEBOOK`.
- `ZCL_BN_LOGIC`: registration, parameter binding and `IF_UJ_CUSTOM_LOGIC` entry point.
- `ZCL_BN_SERVICE=>RUN_LOGIC`: synchronous native compilation/execution and staged run records.
- `POST /logic-handler`: `{ "handler": "ALLOC_REVENUES", "notebookId": "...", "expectedRevision": 3, "handlerRevision": 0 }`. Use the current handler revision instead of zero to rebind.
- `GET /logic-handler?id=ALLOC_REVENUES`: retrieve the current user's binding.

No existing business LGF files or calculation classes are replaced automatically.

## Verification

`tools/check-notebook-logic.cjs --notebook=<saved notebook with CATEGORY/TIME>` creates a DEV fixture and calls the actual SAP BAdI using GET BADI / CALL BADI. It verifies pinned revisions after later edits, two cells sharing typed overrides, dependency outputs, frozen periods, Unicode, unchanged CT_DATA, caller rollback and commit, and invalid parameter/scope rejection. It records evidence in [notebook-logic.json](evidence/notebook-logic.json). This test does not execute an existing business LGF or write BPC fact data.

Native ABAP Unit tests cover scope intersection, preservation of dimensions without notebook inputs, disjoint scopes, dependency copies and undeclared dependency rejection. Full SAP abapGit import/serialization comparison includes the enhancement's generated text metadata, class files and BSP resources.
