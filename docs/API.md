# API v0.1

SAP base `/sap/bc/zbpc_notebook`; local base `/api`. Preserve `sap-client`. Writes are JSON with `X-BPC-Notebook: 1`, same-origin credentials and authorization; no CORS. Errors are `{code,message}` plus HTTP status. Fields use camel case. Native input values are canonical text in the ABAP ABI; UI normalizes them to declared JSON scalar types.

| Method/path     | Request                                                     | Response                                   |
| --------------- | ----------------------------------------------------------- | ------------------------------------------ |
| GET /notebooks  | none                                                        | owned list                                 |
| POST /notebooks | `{demo:true}` or `{title,inputs,cells}`                     | saved revision 1                           |
| GET /notebook   | `id` query                                                  | current definition/freshness               |
| PUT /notebook   | `{id,title,inputs,cells,expectedRevision}`                  | immutable revision; 409 on conflict        |
| GET /versions   | `id` query                                                  | source/input history                       |
| POST /validate  | `{notebookId,cellId}`                                       | `{native,supported,diagnostics}`           |
| POST /runs      | `{notebookId,expectedRevision,scope,cellId,idempotencyKey}` | frozen run/job identity                    |
| GET /runs       | `notebookId` query                                          | execution history and snapshots            |
| GET /run        | `id` query                                                  | state/progress/diagnostics/timings/results |
| POST /cancel    | `{id}`                                                      | cooperative cancellation request           |
| POST /retry     | `{id,idempotencyKey}`                                       | new historical snapshot execution          |
| GET /output     | `runId,cellId,revision,offset,limit` query                  | bounded ordered rows/schema/summary        |

Scope is `one/through/all`; one/through require selected cell. Dependencies are unique earlier IDs. One consumes existing current datasets; through/all produce participating dependencies. Source is loaded from immutable saved SAP versions, never execution-request source. Retries preserve historical source/inputs/external bindings and may therefore produce output stale relative to current edits.

Cells: `{id,title,source,dependencies,sourceVersion,checksum}`. Server owns version/checksum. Inputs: `{name,type,value}` with `number/string/boolean`. Notebook CAS protects order/dependencies/inputs. Source-only versions change only for source edits; notebook history freezes all metadata.

Output revision is immutable 1 in this milestone; reruns get different IDs. Source/input changes or a newly superseding upstream dataset invalidate consumers, even if values match. Historical outputs remain reviewable. Preview requires correct owner/revision, offset ≥ 0 and limit 1–100, with stable stored row order.

Idempotency keys bind user/client and request checksum. Repeats return the original run; changed requests with the same key return 409. Concurrent first SAP submissions may return a CAS conflict: repeat the identical key after the first resolves. Snapshots/reservations commit before job release. There are no automatic calculation retries.

States: queued → running → succeeded/failed/cancelled. SAP ten-minute submission deadline/cancellation is checked between cells; local deadline is 60 seconds. Native polling reconciles termination and expiry. Mid-cell preemption requires SM37/operator intervention. Syntax diagnostics include source/generated lines, word and message; run diagnostics also identify cell. Production approved-release execution and live BPC writes are unavailable.
