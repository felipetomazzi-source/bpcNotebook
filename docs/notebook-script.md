# Notebook Script v1

For complete native working tables, grouping, indexed joins, explicit precision, reference scopes and allocation results, see [Notebook Script v2](notebook-script-v2.md). V2 requires an explicit `script version 2` header; existing v1 source remains compatible.

Use **Add script cell** for the simpler language; **Add cell** retains the existing ABAP editor. Choose the notebook's BPC environment/model first for metadata completion and BPC reads. Existing scalar and dimension-selection inputs retain their contracts.

```text
dimension materials = DEMREVID-MATCONN
members connections = materials
show connections as "MEMBERS"

model plan = DEMREVID
data facts = plan where TIME = range("TIME") and CATEGORY = selection("CATEGORY") limit 10000
let factor = number(input("factor"))
for row in facts
  row.SIGNEDDATA = row.SIGNEDDATA * factor
end
show facts as "FACTS"
```

The example needs notebook inputs TIME (range), CATEGORY (member), and factor (number). Model/dimension names are illustrative; available names come from SAP metadata. `data facts = DEMREVID` also creates the model adapter implicitly. Omitted filters retain the adapter's frozen notebook selections. Additional filters are validated and intersected with those selections by the existing backend. `range("TIME")` uses the snapshot's backend-resolved base periods. `selection("CATEGORY")` uses its selected IDs. An explicit filter containing hierarchy nodes is rejected by the model adapter; use a range parameter for backend resolution.

Typing `DEMREVID-` opens dimension suggestions. `DEMREVID-MATCONN-` and a declared dimension alias such as `materials-` offer stored properties. Ctrl+Space also opens completion. Model aliases work for dimension qualification. Suggestions include descriptions, use the current environment's authorized metadata endpoint, and follow its paging. Metadata is cached for the current application session; reload to refresh changed metadata. An unavailable or unauthorized model does not produce suggestions. Backend adapter authorization remains authoritative when executing.

```text
members chosen = materials ["MEMBER_ID"]
let description = materials-EVDESCRIPTION("MEMBER_ID")
message description
```

Member reads return the native dimension table including stored properties, descriptions, and hierarchy parent columns. Property access uses the existing stored-property adapter; future virtual-property providers are not enabled by this language version.

Statements:

| Statement | Behavior |
| --- | --- |
| `dimension d = MODEL-DIMENSION` | Authorized dimension adapter; `DIMENSION` alone uses the notebook model. |
| `model m = MODEL` | Authorized model adapter. |
| `members rows = d` | Authorized dimension members; optional `["ID", "ID2"]` restricts IDs. |
| `let label = d-PROPERTY("ID")` | A stored member property; `MODEL-DIMENSION-PROPERTY("ID")` also works. |
| `data rows = m where DIMENSION = ["ID"] limit 10000` | Generic model read; combine filters with `and`. Default limit 100000; allowed range 1–1000000. |
| `let factor = number(input("factor"))` | Scalar or member-list declaration. Variables keep their declared type. |
| `for row in rows` / `end` | Loop over a table. `row.FIELD` reads or assigns a field after a runtime existence check. |
| `if condition` / `else` / `end` | Conditional execution. |
| `show rows as "RESULT"` | Named table output using the existing bounded snapshot preview. |
| `table rows` | Declare the existing key/amount scalar-result table. |
| `append rows key = "CC100" amount = factor * 100` | Add a scalar-result row. |
| `read rows = "earlier_cell"` | Read an explicitly declared earlier-cell scalar dependency. |
| `emit rows` | Emit the existing scalar-result table. |
| `message expression` | Add a run message. |

Expressions support numbers, double-quoted text, `true`/`false`, parentheses, `+ - * / %`, comparisons `== != < <= > >=`, and `and or not`. Built-ins are `input`, `member`, `selection`, `range`, `number`, `text`, `count`, and `concat`. `input` returns the existing string representation, so convert numeric inputs explicitly. Boolean inputs can be tested with `input("suppressZero") == "true"`. Text concatenation uses `concat(a, b)`. `#` starts a comment outside quoted text. Names are case-sensitive ASCII identifiers; use exact SAP model, dimension and property names. Table fields are resolved case-insensitively to ABAP component names. A cell can mix script constructs, but not arbitrary ABAP statements; use a separate ABAP cell when needed.

Saving compiles the script deterministically in the browser and stores executable ABAP through the existing save API. The same source includes a versioned UTF-8/base64 comment envelope containing the exact authored script, plus script-line markers for generated diagnostics. Both forms are therefore covered by the existing immutable source checksum/version and frozen execution snapshot, without a separate storage schema or migration. Generated source is limited to the existing 60000-character limit. Invalid or incomplete script syntax blocks saving. SAP also compiles every script cell before writing any immutable source rows; generated ABAP syntax errors reject the save with the cell and script line. **Generated ABAP** shows the complete saved execution source; **Validate** uses SAP's actual temporary compiler and maps compilation errors back to script lines. Adapter/member/field validation and calculation failures can still occur at execution time.

The compiler only accepts its documented grammar and emits calls to the existing adapters; it does not evaluate JavaScript or offer a raw ABAP escape. Existing trusted-author DEV authorization and the production block continue to apply. Generated ABAP executes through the same background worker as ABAP cells; the local Node simulation does not execute these new scripts. Editing the generated ABAP outside the script editor causes it to open as an ordinary ABAP cell, preserving the edit. Compiler v1's output is part of the storage contract: incompatible future code generation must use a new version and an explicit migration rather than silently replacing saved source.

Verification: parser/type/error/source-preservation tests, live dimension/property completion, native SAP compilation of three scripts, and a background run producing 66000/39600/26400 from scalar arithmetic/conditions/loops. Authorized CATEGORY member/property and DEMREVID model reads completed; that frozen TIME selection returned an empty fact table, so nonempty transactional fact arithmetic was not asserted. Unicode text survived save/read and appeared intact in execution messages. The actual abapGit import/serialization compared all 42 repository files, including the new BSP Script.js page and mapping. Evidence is in `docs/evidence/notebook-script.json`, `script-completion.png`, and `sap-roundtrip.json`.

Repeat the SAP verification with `node tools/check-notebook-script.cjs --notebook=<existing notebook with CATEGORY/TIME selections>` after configuring BPC_ADT_TOOL_ROOT. The tool creates a dedicated verification notebook and uses read-only BPC adapters.
