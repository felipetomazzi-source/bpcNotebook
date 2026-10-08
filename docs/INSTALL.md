# Installation and acceptance

## Local prototype

Node.js 22 or later is sufficient. `npm start` serves `http://127.0.0.1:4173`. Choose **Open allocation demo**, then **Run all**. Select `allocate` in the output selector: CC100 is 66,000. Page size is two rows to demonstrate paging. Change an input and save to see stale outputs. **Retry snapshot** reruns historical source/inputs under a new ID. **Versions** opens immutable revisions.

The local service stores `.local/store.json`, binds loopback and uses one trusted local identity. It simulates exactly two demo operations and refuses edited ABAP. A restart fails unfinished executions without replaying them. The local UI uses SAPUI5 1.120.41 from SAP's CDN; the generated SAP bundle uses installed SAP UI5 resources. Local browser internet access is required. The deployed SAP UI5 browser now passes the allocation-demo workflow.

`npm test` runs lifecycle/HTTP regressions. `npm run pack:sap` updates padded BSP resources after edits and preserves SAP-serialized native sources and metadata. It rejects resource inventory/mapping mismatches. Add/remove pages through SAP and serialize the new metadata before accepting those changes. Do not edit generated WAPA files. `webapp/` is the frontend source.

## SAP deployment

1. Create transportable package **ZBPC_NOTEBOOK** in DEV with your site's transport layer and import this repository using abapGit. Proof objects on the connected target were installed in **$TMP**; move these objects using normal SAP tools before import, or use a clean DEV system. Do not silently overwrite objects belonging to another package.
2. Activate `ZBN_HEAD`, `ZBN_DOC`, `ZBN_SRC`, then exception/types/store/context/compiler; activate service, `ZBN_JOB` and handler together. Activate BSP `ZBPC_NOTEBOOK`. Native sources and all BSP resources were imported with actual abapGit deserializers and activated on the target; their serialization matches Git blobs. Transportable installation and browser acceptance still need verification.
3. Confirm SICF `/sap/bc/zbpc_notebook` uses `ZCL_BN_HTTP`, authenticated SAP logon and **no anonymous/service-user override**. Activate it and `/sap/bc/ui5_ui5/sap/zbpc_notebook`. Use HTTPS, disable cross-origin/CORS access, and preserve the browser's Host through proxies.
4. Access stays disabled by default. The service rejects T000 client category `P`. Basis explicitly enables each trusted DEV user through a TVARVC selection entry: NAME `ZBN_DEV_<SID>_<MANDT>`, TYPE `S`, SIGN `I`, OPTI `EQ`, LOW = SAP user. Wildcard-user entries are not accepted. A single exact-user entry was created for DEVELOPER in the connected DEV client 001 for this test deployment.
5. Grant `S_DEVELOP` scoped to DEVCLASS `ZBPC_NOTEBOOK`, OBJTYPE `PROG`, OBJNAME `ZBN_JOB`: activity **03** view, **02** author, **16** compile/execute/cancel/retry. Grant narrowly scoped background scheduling permissions. This gate is for trusted DEV authors. The job runs as its authenticated submitting user, without impersonation.
6. Open `/sap/bc/ui5_ui5/sap/zbpc_notebook/index.html?sap-client=<client>`. Create/validate the demo, run all, inspect SM37 identifiers, preview both datasets and check that changing inputs/source invalidates consumers.

## Evidence runners

Development scripts use the ADT client in an existing `mcp-abap-abap-adt-api` installation; this is never a product dependency. Set `BPC_ADT_TOOL_ROOT` to that directory. Credentials come from its `.env`; `--codex-env` explicitly selects `[mcp_servers.adt.env]` in current Codex configuration. Credentials are not copied to this repository.

- `node tools/check-native.cjs --codex-env`: installs **only this prototype's DDIC/classes/report into $TMP**, activates them and runs harmless compiler tests. It does not enable users, ICF or transports.
- `node tools/run-native-probe.cjs --codex-env`: dialog/background temporary-compilation probe.
- `node tools/sap-roundtrip.cjs --codex-env --import`: imports repository Git-clean blobs using real SAP abapGit object deserializers, activates and serializes all objects, and compares every returned byte with Git. This mutates this application’s `$TMP` objects, creates/updates the local `$BN_ROUNDTRIP` package for package metadata, and creates/updates its SICF node. See [scope and evidence](evidence/ENCODING.md).
- `node tools/run-integration.cjs --codex-env`: SAP-table source, frozen background snapshot, dependent datasets, paging and stale-input integration test.

Results are recorded under `docs/evidence/`. The connected client's **upper ABAP Unit risk limit rejects dangerous tests**, even when the request allows them. Basis must decide whether to allow dangerous/long tests through `SAUNIT_CLIENT_SETUP` in DEV. Retain the truthful dangerous classification. The integration test also requires explicit trusted-user enablement. The ABAP Unit policy was unchanged; DEV application access was later enabled for DEVELOPER at the user’s request to deploy a test version. Integration leaves immutable records for inspection; the small probe removes only its uniquely keyed INDX scratch entry.

Capture a successful integration result, source/document rows and terminal SM37 job status before declaring the seven-part native milestone complete. Also accept one-cell stale-dependency rejection, queued/running cancellation, syntax failure, a deliberately dumped DEV cell, timeout, simultaneous saves/submissions and unauthorized users. Repeat the same idempotency key after an uncertain submission; use a new key for an intentional retry.

## BPCIO tile

Embed `bpc.notebook` from `/sap/bc/ui5_ui5/sap/zbpc_notebook/` using `sap.ui.component` and `ComponentContainer`. Pass settings `{ embedded: true, environment: selectedEnvironment }`. The hub keeps its header and Back button, loads UI5 1.120 or newer once, and supplies its theme. Notebook hides its standalone header and theme selector. See the [embedding contract and complete example](../README.md#embed-in-the-bpcio-hub).

Call `setEnvironment(environment)` for environment changes and `requestNavigateBack()` from the hub Back button. Wait for `navigateBack` before destroying the container/component; Cancel or a failed save leaves the notebook open. Preserve the authenticated SAP client in the hub URL. Repository/backend remain independent.

## Limits and production work

Jobs default to a ten-minute deadline; RUN_SECONDS configures 1–7,200 seconds. Cancellation/deadline checks occur between cells and at cooperative allocation boundaries. See [allocation budgets and acceptance](demrevid-allocation.md). Polling reconciles cancelled/finished jobs that did not publish normal completion. Deadline expiry records failure and blocks later worker publication. It **cannot preempt arbitrary ABAP mid-cell**: inspect/terminate active jobs in SM37 before retrying. A crash after snapshot commit but before identity publication expires without automatic resubmission. Schedule reconciliation independently of browser polling for production.

Dataset schema is `(key: string, amount: decfloat34)`, maximum 10,000 rows per output, maximum 100 rows per preview. Full JSON remains in SAP; paging uses stable frozen append order. Outputs store owner, schema, revision, checksum and 30-day retention eligibility. **No automatic cleanup** is implemented: a future reference-aware cleanup/audit job must preserve historical bindings/releases. Replace whole-dataset JSON reads with chunked/ordinal SQL storage for large allocations.

Production stays blocked. Required: independent review/approval/promotion, signed immutable release manifests, release-only execution, author/reviewer/approver/operator authorization objects, restricted identities and enforceable resource/access controls, scheduled reconciliation/retention, quotas/scalable storage and security review. Arbitrary ABAP can access SAP objects and issue commits as its job identity; temporary compilation is not a sandbox. No live-BPC-data save endpoint exists.

## Connected DEV deployment

The repository was committed/pushed to main and pulled by SAP abapGit with transport NPLK900126. Package ZBPC_NOTEBOOK was created by the pull. The SAP UI5 repository API created the application-specific launch ICF node, now included in src. Native browser execution succeeded; allocation output CC100 is 66,000. Both cells ran as real SAP background work. DEV access is enabled only for DEVELOPER. Open the README launch link to test.
