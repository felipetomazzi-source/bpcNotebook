# BPC Notebook — first milestone design

## Architecture inspected (8 October 2026)

The adjacent `bpcIO` project separates `ZCL_BPC_IO_HTTP` (ICF JSON routing) from business services, with a UI5 BSP `ZBPC_OBJECTS` serialized as WAPA files. `bpcGit` uses package `ZBPC_GIT`, BSP `ZBPC_GIT`, ABAP 7.52 and UI5 1.52. It documents the standalone client-preserving URL `/sap/bc/ui5_ui5/sap/zbpc_git/index.html?sap-client=…`; the current BPCIO checkout also supports newer Git through an embedded component. This project follows the requested standalone tile pattern with package `ZBPC_NOTEBOOK`, BSP `ZBPC_NOTEBOOK`, ICF `/sap/bc/zbpc_notebook` and its own service/worker. Adjacent repositories are references and are not modified.

## Contract and persistence

Notebook edits are optimistic: the caller supplies the expected notebook revision. Each save creates an immutable notebook document containing cell IDs, order, dependencies, typed inputs, immutable source versions, author, timestamp and SHA-256 checksums. Cell source is data, never a repository object. A compare-and-swap head protects concurrent writes. Historical documents remain readable.

Runs contain frozen participating cells, source versions/checksums, order, input values and dependency bindings. Scope `one` requires current successful upstream outputs; `through` includes cells up to selection and `all` includes all. Dependencies must precede consumers; unknown IDs, duplicates and cycles are rejected. Editing source, inputs, dependencies or order invalidates downstream current-output bindings, without changing historical runs.

Dataset identity is `(runId, cellId, revision)`, owned by the submitting user and client. Prototype schema is a fixed table of `{key, amount}` with deterministic row ordinals. Outputs are immutable, held by the server, and previews require the expected output revision, offset and a bounded limit. Browser requests contain references, never intermediate datasets. This deliberately small schema proves the execution lifecycle; arbitrary allocation schemas and scalable chunk storage remain production work.

Native storage: client-dependent `ZBN_SRC` (immutable source keyed by notebook/cell/version, with sequence, dependencies, author, timestamp and checksum), `ZBN_HEAD` (CAS heads) and `ZBN_DOC` (immutable JSON notebook/run/dataset documents). Kind/ID/revision distinguish records; documents carry author, UTC timestamp and checksum; head records enforce owner. Runs use versioned state documents so transitions are audited. Per-user idempotency reservations bind submission keys to request checksums and run IDs. JSON uses `/UI2/CL_JSON` camel-case fields. No public operation writes live BPC data.

## Native cell ABI

Generated code is a subroutine pool containing `FORM execute USING io TYPE REF TO zcl_bn_context`. The saved cell body can call `io->input( name )`, `io->read( dependency )`, `io->emit( rows )` and `io->message( text )`. A stable global context carries explicit inputs, declared dependency references, messages and output. Compilation returns pool name only for the current internal session. A background worker loads the frozen snapshot, regenerates the wrapper in its own session, calls `PERFORM execute IN PROGRAM (pool) USING context`, and persists each result before proceeding. It never transports a generated program name across requests.

## Compilation findings and target constraints

Read-only ADT query of CVERS on the connected target returned SAP_BASIS/SAP_ABA/SAP_BW **752 SP04**, SAP_UI **752 SP06**. This is classic ABAP, not ABAP Cloud. Native activation and job evidence must be recorded separately from local simulator tests.

SAP documents a limit of 36 temporary pools per internal session; the prototype caps participating cells at 30. Pool source is session-local and must be generated again in background. Syntax errors include generated line, source line (wrapper offset), word and message. Uncatchable dumps, `MESSAGE X`, `STOP`, resource exhaustion and arbitrary commits require job reconciliation; exception handlers cannot prove sandboxing. Reference: [SAP temporary subroutines](https://help.sap.com/saphelp_autoid2007/helpdata/en/9f/db999535c111d1829f0000e829fbfe/content.htm?no_cache=true).

Implemented wrapper tests on this target passed: a generated body read a typed input through `ZCL_BN_CONTEXT`, emitted a structured amount of 60,000, and a syntax error mapped generated line 3 to source line 1. The independent basic probe returned 42 in dialog and confirmed generation `sy-subrc = 4` on invalid code. Native services/tables/report activated with no remaining diagnostics. A test exposed `/UI2/CL_JSON` converting JSON `true` into string `X`; inputs now normalize this to canonical `true/false` before persistence. Background tests are honestly marked dangerous and were skipped by the client's upper risk policy even with explicit request flags. Background generation and end-to-end SAP persistence remain **unproven**, not inferred from local simulation. Evidence: `docs/evidence/native-check.json`, `native-probe.json`, `native-integration.json`.

Inspected local `mcp-abap-abap-adt-api/src/handlers/CodeAnalysisHandlers.ts`: `handleRunClass` delegates to `adtclient.runClass(args.className)`. Installed `abap-adt-api/build/AdtClient.js` posts to `/sap/bc/adt/oo/classrun/` plus upper-case class name and returns the response body. It has no notebook parameters or snapshot semantics. The product uses its own API; ADT is only a development verification tool. `IF_OO_ADT_CLASSRUN` is not required.

## Jobs and failures

Submission freezes data before `JOB_OPEN`, `SUBMIT ... VIA JOB`, `JOB_CLOSE`. Job identifiers are persisted and returned. State machine: queued → running → succeeded/failed/cancelled. Cancellation is cooperative between cells; a stuck or dumped job needs SM37/operator termination and reconciliation. No automatic retry: an explicit retry creates a new run from a chosen snapshot and new key. Timeout is checked between cells; the monitor reconciles terminal job status and expiry. ABAP has no safe general-purpose preemption for arbitrary cell bodies. The local worker models these transitions but does not execute ABAP.

## Governance and rollout

Temporary compilation grants code execution under the job identity. Source allowlists are not a sandbox. Native execution is disabled by default until a Basis administrator enables the prototype for trusted DEV users. Authoring/execution require separate authorization checks, dataset ownership and CSRF protection. Production execution is blocked in this milestone. Review/approval/promotion must add signed immutable releases, independent approvers, audit export, release-only production selection, restricted execution identity and enforceable infrastructure authorization restrictions before PRD activation.

Transport repository objects and DDIC definitions DEV → TEST → PRD through CTS/abapGit conventions; promote table-stored code separately as reviewed checksum manifests. A future BPC save must validate output revision, environment/model, BPC permissions and work status at the write boundary. Retention must preserve referenced outputs and releases, clean expired unreferenced rows in a scheduled job and audit deletion. The prototype does not expose a destructive cleanup or BPC-save endpoint.

## Deliverables and evidence policy

Runnable local UI5 prototype and persistent HTTP reference service; native ABAP artifacts and target compilation probe; behavioral tests for freezing, stale dependencies, paging, ownership, CAS and duplicate keys. Local calculations are explicitly labeled simulation and limited to the two demonstration operations. SAP milestone completion requires installation/activation plus captured database and SM37 evidence. Never infer native execution from local tests.
