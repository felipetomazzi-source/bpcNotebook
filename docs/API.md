# API v0.1

SAP base `/sap/bc/zbpc_notebook`; local base `/api`. Preserve `sap-client`. Writes are JSON with `X-BPC-Notebook: 1`, same-origin credentials and authorization; no CORS. Errors are `{code,message}` plus HTTP status. Fields use camel case. Native scalar input values are canonical text in the ABAP ABI; UI normalizes them to declared JSON scalar types. Member selections and resolved ranges are ID arrays. Metadata kinds are environments/models/dimensions/members; search matches IDs and descriptions, offset is nonnegative, pages contain at most 100 authorized items.

| Method/path     | Request                                                     | Response                                   |
| --------------- | ----------------------------------------------------------- | ------------------------------------------ |
| POST /metadata | `{kind,environment,model,dimension,hierarchy,search,offset}` | `{items,hierarchies,more}` (SAP only) |
| GET /notebooks  | none                                                        | owned summaries without cell sources                                 |
| POST /notebooks | `{demo:true,environment,model}` or `{title,environment,model,inputs,cells}`                     | saved revision 1                           |
| GET /notebook   | `id` query                                                  | current definition/freshness               |
| PUT /notebook   | `{id,title,environment,model,inputs,cells,expectedRevision}`                  | immutable revision; 409 on conflict        |
| GET /versions   | `id` query                                                  | source/input history                       |
| POST /validate  | `{notebookId,cellId}`                                       | `{native,supported,diagnostics}`           |
| POST /runs      | `{notebookId,expectedRevision,scope,cellId,idempotencyKey}` | frozen run/job identity                    |
| GET /runs       | `notebookId` query                                          | execution summaries; GET /run has snapshot            |
| GET /run        | `id` query                                                  | state/progress/diagnostics/timings/results |
| POST /cancel    | `{id}`                                                      | cooperative cancellation request           |
| POST /retry     | `{id,idempotencyKey}`                                       | new historical snapshot execution          |
| GET /output     | `runId,cellId,revision,offset,limit` query                  | bounded ordered rows/schema/summary        |

Scope is `one/through/all`; one/through require selected cell. Dependencies are unique earlier IDs. One consumes existing current datasets; through/all produce participating dependencies. Source is loaded from immutable saved SAP versions, never execution-request source. Retries preserve historical source/inputs/external bindings and may therefore produce output stale relative to current edits.

Cells: `{id,title,source,dependencies,sourceVersion,checksum}`. Server owns version/checksum. Inputs: scalar `{name,type,value}` with `number/string/boolean`, or BPC `{name,type,dimension,hierarchy,required,selected,resolved}` with `member/range`. `resolved` is backend-owned. Notebook `environment` and `model` identify the authorized BPC context. See [BPC input contract](bpc-inputs.md). Notebook CAS protects order/dependencies/inputs. Source-only versions change only for source edits; notebook history freezes all metadata.

Output revision is immutable 1 in this milestone; reruns get different IDs. Source/input changes or a newly superseding upstream dataset invalidate consumers, even if values match. Historical outputs remain reviewable. Preview requires correct owner/revision, offset ≥ 0 and limit 1–100, with stable stored row order.

Native comparisons and read diagnostics appear as named tables through the existing `/output` endpoint (`table` query). Full native counts are separate from bounded preview counts. Native `/run` includes `fixtureMode`; fixture runs reject historical retry and cannot provide ordinary cell dependencies. Fixtures require one independent ABAP cell and validated native in-memory tables installed before reads; there is no JSON upload route. See [native validation APIs and examples](native-validation.md).

Idempotency keys bind user/client and request checksum. Repeats return the original run; changed requests with the same key return 409. Concurrent first SAP submissions may return a CAS conflict: repeat the identical key after the first resolves. Snapshots/reservations commit before job release. There are no automatic calculation retries.

States: queued → running → succeeded/failed/cancelled. SAP ten-minute submission deadline/cancellation is checked between cells; local deadline is 60 seconds. Native polling reconciles termination and expiry. Mid-cell preemption requires SM37/operator intervention. Syntax diagnostics include source/generated lines, word and message; run diagnostics also identify cell. Production approved-release execution and live BPC writes are unavailable.

Notebook Script cells use the same ABAP source field and immutable source history. The source contains the versioned authored-script comment envelope and generated ABAP. SAP syntax-checks script cells before accepting a save. See [Notebook Script](notebook-script.md).

## SAP Script Logic handlers

`GET /logic-handler?id=<name>` reads the current user’s named binding. `POST /logic-handler` binds `handler` to `notebookId` / `expectedRevision`, using `handlerRevision` for optimistic replacement (zero creates). The saved notebook must declare its environment/model. Registration does not run cells.

See [the Script Logic contract](notebook-script-logic.md) for BAdI parameters, caller current-view scope, transaction ownership and output review. `/retry` rejects Script Logic runs: invoke the BAdI again from its caller.

## Notebook deletion

POST /delete-notebook takes notebookId and expectedRevision. It hides the notebook while retaining immutable history and outputs. Ownership, revision and active-run guards apply. Deleted notebooks reject new reads, saves, submissions and bound handler invocations. GET /versions and historical GET /run and GET /output remain available to the owner. Cell deletion uses PUT /notebook with the remaining valid dependency graph. See [notebook management](notebook-management.md).
