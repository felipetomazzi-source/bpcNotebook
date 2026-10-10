# Complete working datasets and calculation stages

This platform extension supports visible ABAP allocation stages. It does not add new Notebook Script transformations or enable posting.

## Native table handoff

A producer publishes complete native data, separately from bounded browser previews:

```abap
io->publish_dataset( name = 'REVENUES' rows = revenues ).
io->publish_dataset( name = 'RATIOS' rows = ratios ).
```

The consumer declares the producer's cell ID in `dependencies` and retrieves a private working copy:

```abap
DATA(revenues_ref) = io->read_dataset(
  dependency = 'stage01' name = 'REVENUES' ).
FIELD-SYMBOLS <revenues> TYPE STANDARD TABLE.
ASSIGN revenues_ref->* TO <revenues>.
```

Publication captures flat structured tables, including RTTC-created tables. Native DDIC member types, packed decimals, decimal floats and elementary column types remain native: financial amounts never pass through JSON numbers. Empty datasets retain their schema. Nested tables and reference columns are rejected. Returned tables are standard tables with an empty key, preserving the producing table's iteration order. Original sorted/hashed table keys are not retained; consumers must explicitly sort or create keyed copies when required.

Names are unique per producing cell, start with a letter and contain up to 60 letters, digits or underscores. At most 100 datasets and 100 elementary columns per dataset are supported. A checksum covers the schema, full counts and binary contents. Persisted artifacts bind notebook, run, producing cell, output revision, source version/checksum and dependency fingerprint. Ownership, current model member authorization and the frozen dependency binding are checked on retrieval.

`io->artifacts` exposes full output counts/schemas/checksums. `io->dataset_reads` records input dataset identities and producing runs. `GET /datasets?runId=...&cellId=...&revision=1` returns these manifests only. No endpoint sends complete binary artifacts to the browser. Publication automatically adds a bounded `DATASET/<name>` preview. Existing `emit_table` remains a preview API and cannot satisfy `read_dataset`.

## Execution boundaries and data consistency

Run all executes all stages in order. Run through executes through the selected stage. Run cell executes only that stage using valid completed declared predecessors. Existing fingerprint checks reject missing/stale predecessors. New upstream executions invalidate downstream outputs even when source is unchanged.

Full artifacts are persisted only after their producing cell returns successfully and budget/cancellation checks pass. A failed cell publishes no completed artifacts. Earlier successful cell boundaries remain inspectable; arbitrary statements inside a failed cell cannot be resumed. Native BAdI execution retains artifacts in its caller-owned LUW without an internal commit or rollback.

Artifacts expire for dependency reuse after 30 days. Physical database retention is currently administrative; automatic deletion is not implemented. Expired artifacts require rerunning their producing stages.

A stage reusing a prior-run dependency cannot issue fresh generic model fact reads. Read complete calculation and explicitly authorized reference/lookback facts in the first stage, publish them, and perform later filtering against that artifact. Reexecute the read stage to establish new facts. Historical retries of BPC model-bound runs are rejected because retained working tables do not constitute a complete historical database/metadata snapshot. Metadata remains subject to current authorization.

Fixture validation is a separate mode. The first executed stage enables complete in-memory model fixtures before reading facts. Fixture mode stays attached to the run. Each later stage retrieves the retained fixture artifact and calls `enable_fixtures` before model reads. Fixture artifacts can pass between stages only within that same validation run. Live fallback, ordinary-run reuse, historical fixture retry and allocation publication are rejected. Run all/through from fixture preparation are supported; Run cell with fixtures from another run is not.

## Resource budgets

`DATASET_BYTES` is an optional numeric integer input: default 67,108,864 bytes, maximum 268,435,456. Each cell charges complete retrieved and published tables against its aggregate budget using the greater of native memory estimate and compressed buffer size. `WORK_ROWS` also bounds aggregate retrieved/published row counts. These are explicit failure limits, never truncation limits. The byte estimate does not include every ABAP allocator/bookkeeping overhead; synchronous caller memory still needs sizing for the full run.

`PREVIEW_ROWS` controls only bounded previews, default 200, maximum 5,000. Existing read, execution-time, cancellation and preview-value budgets continue to apply. Full tables remain on SAP.

## Accountant-facing stages

The UI uses standard Fiori `IconTabBar`, `Panel`, `Switch`, buttons and text controls. Setup shows notebook explanation and inputs; each numbered stage shows its explanation, prerequisites, execution status and Run cell/Run through actions. Advanced ABAP and dependency editing are collapsed by default. Changing tabs preserves editors and unsaved source. Boolean inputs use switches; input keys are unchanged.

Definitions optionally provide plain text `notebook.explanation` (8,000 characters) and `cells[].explanation` (4,000). Help can be edited and saved in immutable notebook revisions. Explain the stage's purpose, inputs, outputs, reconciliation and fallback/rounding rules. Do not describe a preview as a writeback result.

## Verification status

`docs/evidence/dataset-codec-roundtrip.json` records the isolated SAP abapGit import/serialization comparison and five native codec tests. The integrated deployment subsequently passed all seven tests (`docs/evidence/native-dataset-tests.json`) and full background-worker all/one/through tests (`docs/evidence/native-working-datasets.json`), including 12,003 native rows, private copies, empty schemas, bounded previews and stale/missing predecessor rejection. `docs/evidence/bpc-deployment.json` records exact online abapGit serialization of all 61 deployed repository files. Allocation equivalence remains a separate calculation-agent check.

## Per-cell metadata and read-authorization cache

During the execution service's cell body, secure model metadata and authorized dimension/hierarchy member lists are reused for repeated artifact/fixture checks. Keys include SAP client, current user, language, environment, model, security-on mode, dimension and hierarchy. Caches are cleared before and after every cell, including exceptional exits; ordinary metadata HTTP requests are uncached. Model context/security and model access are checked on cache hits. Membership lookups use deduplicated hashed sets rather than repeated linear scans; SAP authorization APIs and their native member lists remain unchanged.

Read member authorization and metadata form a coherent view within one cell. They refresh at the next cell boundary, rather than providing instantaneous mid-cell revocation detection. Final allocation validation clears the cache and performs fresh member write checks. No cache survives a run/cell boundary or is stored in the browser/database.

The compiler normalizes CRLF only in its private compilation text. Saved source, source versions and checksums remain unchanged. JSON serialization repairs raw control characters inside string values while preserving normal serialized bytes and existing hash conventions.

## Text compatibility with the installed SAP JSON decoder

Author source, scalar input text, titles and explanations permit CR, LF and tab. Other control characters are explicitly rejected before saving or submission rather than accepted and corrupted by the installed legacy `/UI2` decoder. Incoming JSON Unicode escape tokens are likewise rejected before decoding, except `\u0009`, `\u000A` and `\u000D`, which are converted to supported standard escapes. Send accented text, symbols and punctuation as actual UTF-8 text; Python clients should use `ensure_ascii=False`. Escaped literal backslashes such as the text `\u0001` remain literal text. CR/LF/tab, Unicode text, quotes and backslashes are verified by native persistence tests.

Diagnostic responses escape all 32 low control characters into valid JSON; the complete wire round trip is verified with `JSON.parse`. This does not claim the legacy native decoder supports every Unicode escape. The earlier temporary diagnostic globals `ZCL_BN_JSON_CHECK` and `ZCL_BN_RUN_DOC_CHECK` reside in `$TMP`, are unused by the application, and remain unreferenced pending controlled cleanup. Delivered diagnostic tools use preview-only Notebook cells and archive their temporary notebooks. They never upload global source. Serialization tools run only an installed reviewed helper; helper changes require Git/abapGit transport.

The installed decoder also mishandles standalone `\r`. Platform deserialization applies a narrow private CR compatibility conversion, preserving CRLF, standalone CR and literal doubled-backslash text. The wire representation remains valid JSON. This conversion is applied only before native deserialization; it is not a general Unicode-escape parser.
