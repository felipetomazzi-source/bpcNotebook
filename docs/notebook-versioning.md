# Notebook Git provider — contract v1

This feature is prepared on `codex/notebook-versioning`. It is not deployed or
merged. BPC Git owns repository access, branches, history, diffs and commit
verification. Notebook owns the definition schema, authorization, validation and
immutable SAP revisions. abapGit continues to version the application backend and
UI5 sources. No financial data or execution output is exported by this provider.

## Entry point and transaction boundary

Optional class `ZCL_BN_GIT`, static method `DISPATCH`:

```abap
DATA(json) = zcl_bn_git=>dispatch(
  operation = 'PREVIEW'
  request = request_json ).
```

`operation` and `request` are strings; the returning parameter is `json TYPE string`.
The method raises `ZCX_BN`. Operations are `CAPABILITIES`, `LIST`, `PREVIEW`,
`IMPORT`; all requests require `contractVersion: 1` and `environment`.
All operations require enabled trusted SAP DEV access and access to the selected
BPC environment. LIST checks model access as well as document ownership.
Production restrictions remain in force. PREVIEW and IMPORT require edit access.

The provider performs **no COMMIT, ROLLBACK, execution, transport recording or
handler rebinding**. Its caller must roll back the entire LUW on any import or
subsequent synchronization failure. BPC Git must commit only after its own sync
records and every intended import succeed. PREVIEW writes no documents; it does
metadata and native syntax checks. IMPORT repeats these checks; preview is never
an authorization token. Native `SYNTAX-CHECK` avoids generated subpool exhaustion
when preview and import are called in the same internal session.

## Requests and responses

CAPABILITIES request:

```json
{"contractVersion":1,"environment":"CH_PLANNING"}
```

Response fields: `contractVersion: 1`, `abapImport: true`, `scriptExport: true`,
`scriptImport: false`, `canonicalManifest: true`, `callerTransaction: true`,
`maxBundleBase64: 4000000`. There is no HTTP route in the Notebook application for
these operations: BPC Git calls the optional ABAP provider directly.

LIST optionally accepts `model` and returns:

```json
{"contractVersion":1,"bundles":[{"key":"stable-key","title":"Allocation","model":"DEMREVID","revision":7,"files":[{"path":"NOTEBOOKS/stable-key/notebook.json","contentBase64":"..."}]}]}
```

Files are sorted by full repository-relative path; bundles are sorted by key.
The saved SAP revision is response metadata, not part of Git files. Only current,
owned, undeleted notebooks in the requested environment/model are exported.

PREVIEW and IMPORT accept the same request:

```json
{"contractVersion":1,"environment":"CH_PLANNING","key":"stable-key","expectedRevision":7,"sourceCommit":"0123456789012345678901234567890123456789","files":[{"path":"NOTEBOOKS/stable-key/notebook.json","contentBase64":"..."},{"path":"NOTEBOOKS/stable-key/cells/seed.abap","contentBase64":"..."}]}
```

`model` is optional; when supplied it must match the manifest. `sourceCommit` is a
full lowercase 40- or 64-character commit hash. BPC Git must verify that the files
actually belong to that authorized repository commit before invoking the
provider. The provider records provenance; the hash alone is not proof of Git
authenticity. No credentials are passed to Notebook.

Response fields: `contractVersion`, `canImport`, `validationError`, `revision`,
`notebookId`. PREVIEW returns the requested current revision, with `canImport`
false and an explanatory error for invalid bundles. Failed IMPORT raises an
exception so the caller can roll back; successful IMPORT returns the newly saved
revision, greater than `expectedRevision`. Authorization/contract errors outside
bundle validation raise exceptions for both operations.

## Bundle schema and byte conventions

Paths are case sensitive:

```text
NOTEBOOKS/<stable-key>/notebook.json
NOTEBOOKS/<stable-key>/cells/<stable-cell-id>.abap
```

Stable keys contain 1–64 ASCII letters, digits, underscores or hyphens. Cell IDs
start with a letter and contain at most 30 letters, digits, underscores or
hyphens. Cell and dependency order is significant. Dependencies must name unique
earlier cells. The full bundle must contain exactly its declared files; duplicate
paths, unexpected files, missing sources and path traversal are rejected.
Omitting an old cell from both the manifest and files removes that cell from the
new definition, preserving all old revisions. Whole-notebook deletion is not an
operation in this contract.

`notebook.json` is canonical UTF-8 JSON produced by Notebook's existing
`ZCL_BN_TYPES=>JSON` serializer, without a BOM or final newline. Preserve its
serializer format when editing. Deserializing and reserializing must reproduce
its exact text; unknown fields, omitted schema fields, reordering or alternate
whitespace are rejected. This deliberate v1 restriction prevents unknown runtime
or provider metadata from being accepted silently. A formatter/import upgrade
can relax presentation rules under a later explicit contract.

Manifest field order and types:

| Field | Meaning |
| --- | --- |
| contractVersion | Integer, exactly 1 |
| key | Stable bundle key, matching the request and path |
| title | Notebook title, normal 120-character limit |
| environment | Must match the selected target environment |
| model | Authorized target model; required |
| inputs | Ordered definition records below |
| cells | Ordered cell records below |

Each input contains, in order: `name`, `type`, `dimension`, `hierarchy`,
`required` (boolean), `purpose`, `lookbackFrom`, `lookbackSteps` (integer).
Supported types remain number/string/boolean/member/range. Reference purpose and
lookback declarations remain definitions. Selected member IDs, resolved periods,
fiscal links and current scalar values are runtime state and are excluded.
Contract v1 has no definition-default field or implicit derived-provider binding.
Unsupported additional definitions are rejected, rather than silently dropped.

Each cell contains, in order: `id`, `title`, `language`, `sourceFile`,
`generatedFile`, `dependencies` (ordered array of IDs). ABAP cells use
`language: "abap"`, `sourceFile: "cells/<id>.abap"`, `generatedFile: ""`.
Sources are canonical base64 encodings of exact UTF-8 text bytes. Unicode,
punctuation, BOMs, CRLF/LF, trailing spaces and intentional final blank lines are
preserved; invalid or non-round-trippable UTF-8 is rejected. No trimming or source
reformatting occurs. Git clients must preserve these source bytes rather than
apply automatic line-ending conversion to notebook bundle files.

Script v1 exports include author source as `cells/<id>.bns`, with
`language: "script"`, plus the exact saved envelope as
`cells/<id>.generated.abap` in `generatedFile` for audit. The embedded author
bytes are extracted without pretending that a backend transpiler checked them.
**All Script imports are rejected** until the supported transpiler can run on
SAP. Renaming generated code to `.abap` does not bypass this restriction: Script
envelopes/source markers are rejected in ABAP sources too. Ordinary custom ABAP
remains available to authorized trusted authors.

Limits: maximum 30 cells, 50 input definitions, 61 files, 60,000 source characters
per cell, 1,200,000 base64 characters per file and 4,000,000 total base64 characters
per import bundle. Requests larger than 4,500,000 characters fail explicitly.
Normal execution resource limits remain independent of Git import.

## Identity, revision and local inputs

An existing SAP notebook initially exports its immutable notebook ID as its
stable key. Imported bundles acquire an owner-scoped `G` document mapping their
stable key to the target-local Notebook ID. Export subsequently uses that key.
An existing key mapping is never silently rebound. A key that already names an
owned notebook resolves to that notebook. `expectedRevision: 0` creates a new
local notebook only when the key has no target. Existing environment/model must
match the imported definition; changing model bindings is not an implicit restore.

Before writing, IMPORT locks the existing notebook and checks its revision again.
Normal immutable source/version persistence then performs the saved revision CAS.
A race to create a stable key fails its mapping insert; caller rollback must
remove the losing notebook/source writes. Existing snapshots and handler bindings
are not updated. Revision-pinned handlers require a separate deliberate action.

Every member/range selection is cleared on import. Users select local authorized
members before execution, which resolves/freeze periods using current SAP
metadata. An identical scalar definition retains its target-local value. New
numbers start at 0, booleans at false, strings empty. Resource parameters use
safe local defaults: RUN_SECONDS=600, READ_LIMIT=100000, WORK_ROWS=1000000,
PREVIEW_ROWS=200. Normal validation still rejects invalid retained values.

An immutable `V` document records stable key, repository path, source commit,
target notebook ID/revision and a hash of the sorted complete bundle. Runtime
outputs, financial datasets, execution snapshots, handler bindings, private
fixtures, timestamps and author metadata are not added to Git definitions.

## Verification and release gate

Run static checks with:

```powershell
npm exec --yes --package=@abaplint/cli@2.120.71 -- abaplint abaplint-git.json
npm test
```

The lint configuration checks the three changed backend classes and their tests,
loading other repository sources and SAP stubs for context. It does not certify
unrelated legacy calculation code. ABAP Unit tests in `ZCL_BN_GIT` cover exact
Unicode/whitespace bytes, deterministic exclusion of runtime metadata, empty
sources, dependencies, BOM preservation, script audit export/import rejection,
duplicate/undeclared files and invalid manifests. Native tests are prepared but
have not been run on SAP.

The existing local SAP serialization gate deliberately fails for changed
serialized backend files until new SAP evidence exists. Do not regenerate the
old evidence from local hashes or treat the previous main branch round trip as
proof for this branch. Before accepting/deploying this integration, authorize a
test-system pull, activate through abapGit, run native tests and integration
checks, serialize back and compare every affected artifact with Git. Verify
concurrent saves/creation, unauthorized users/models, whole-LUW rollback after a
provenance or BPC Git sync failure, unchanged historical runs/handler revisions,
and successful create/update exports. A clean local diff is insufficient.

No deployment or transport recording is performed during this preparation phase.
Future SAP changes must also account for system transport policy before a pull.
