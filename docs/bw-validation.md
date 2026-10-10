# BW feature validation — 10 October 2026

## Subsequent authorized NPL deployment

The sections below describe the earlier local validation. After explicit user
approval, `ff7965c` and its approved SAP 752 compatibility repair `1de85d0` were
pushed to the existing `codex/SSNG-3218-fixture-validation` branch and pulled
through NPL abapGit repository `000000000008`, package `ZBPC_NOTEBOOK`, request
`NPLK900126`. Target checks confirmed `https://bpc.kwickast.co.nz`, NPL/client
001, logical system `NPLCLNT001`, client category C and SAP_BW 752 SP04.

`ZCL_BN_BW` and `ZCL_BN_CONTEXT` match the deployed repair's source, pass SAP
syntax checks and activated with no errors/inactive objects. All twelve
harmless/short BW ABAP Unit tests passed on SAP. The deployed Script resource
returns HTTP 200 and includes `bwdata` and `io->bw_data`. Read-only checks
confirmed the supplied RSDRI parameters and required DDIC objects.

Actual full abapGit serialization returned all 76 files: 75 match deployed
Git commit `1de85d0` byte-for-byte. The sole difference is the extra final
blank line in `src/zcl_bn_bw.clas.xml`, which SAP removes. It has no semantic
class-content difference. The consolidation into main removes that extra blank line and performs a fresh
full SAP serialization comparison. Activation and native unit tests passed.

Five bounded `RSDCUBE` metadata rows establish that cube and MultiProvider
configurations exist. No provider fact data was read and no actual provider
type is live-certified. Unit denial tests use a seam; real user authorization
denial and end/split/cap behavior remain integration checks for a reviewed
small provider fixture. See [the deployment receipt](evidence/bw-deployment.json).

## Earlier local-only snapshot

At this earlier stage, no SAP system was contacted. No activation, deployment, transport, commit/push,
production extraction or cross-system BW copy was performed.

## Baseline comparison

An isolated `git archive HEAD` snapshot of commit `609949d` was extracted under
`.local/bw-baseline`; the active checkout and concurrent example files were
preserved. The baseline has 66 tests; the feature checkout has 70.

| Original failing test | Baseline result / safe alternative | Classification |
| --- | --- | --- |
| HTTP notebook deletion (`deletion.test.mjs:35`) | Reproduces loopback `EACCES` on baseline; passes with permitted localhost access | Sandbox network restriction |
| Cancel/timeout/worker-loss persistence (`engine.test.mjs:81`) | Reproduces temporary-file rename `EPERM` on baseline; passes with TEMP/TMP under workspace | Sandbox temporary-directory restriction |
| Folder persistence (`folders.test.mjs:8`) | Reproduces temporary-file rename `EPERM` on baseline; passes with workspace TEMP/TMP | Sandbox temporary-directory restriction |
| HTTP demonstration (`http.test.mjs:5`) | Reproduces loopback `EACCES` on baseline; passes with permitted localhost access | Sandbox network restriction |
| HTTP identity creation (`identity.test.mjs:45`) | Reproduces loopback `EACCES` on baseline; passes with permitted localhost access | Sandbox network restriction |
| Recorded SAP serialization (`sap-encoding.test.mjs:26`) | Passes on baseline; fails after feature sources are added/modified | Feature invalidates historical deployment evidence; native integration gate |

With permitted localhost access and workspace TEMP/TMP, **baseline: 66/66
passed**; **feature: 69/70 passed**. The sole remaining failure compares the
recorded 73-file SAP evidence with the current expected count of 76. The feature
adds three native class files and changes the context and packaged Script source.
Updating only the count would leave SHA comparisons failing. No historical SAP
hashes/counts were fabricated or rewritten, and this test was not skipped.

Evidence logs are `.local/bw-baseline/baseline-permitted-results.txt` and
`.local/bw-test-permitted.txt`. Packaging passes and `git diff --check` is clean.

## Feature review and repairs

- Closed a direct `ZCL_BN_BW=>READ_DATA` bypass of the context's fixture/Script
  Logic guard by checking scope inside the adapter itself.
- Added backend identifier checks and duplicate InfoObject rejection, including
  callers using ABAP directly. DDIC elements must be flat and key figures numeric.
- Kept `I_AUTHORITY_CHECK = 'R'`; no disable option, destination, SQL fallback,
  file export or table export is exposed. `I_COMMIT_ALLOWED = abap_false`.
- Both `I_PACKAGESIZE` and `I_MAXROWS` are limit+1, capped at 100001 fetched rows.
  Preflight row/byte budgets run before the function. A nonzero SAP status,
  missing end-of-data, split aggregation or excess result rows raises an error;
  partial result rows are cleared. No result above the requested limit is returned.
- Exact-value filters remain typed SAP range entries (`I`/`EQ`). Empty/duplicate
  filters, unsupported filter fields and oversized lists/values fail. Compiler
  tests show backticks/quotes in values remain escaped data, while executable
  expressions cannot replace a literal limit.

Four BW JavaScript tests passed, including a source-level policy check. Those
checks do not execute ABAP or emulate SAP authorization. Twelve native ABAP Unit
tests were added with a `bw_read` seam: invalid request, fixture and direct fixture
guard, Script Logic guard, invalid identifier/filter, denial, partial package,
split aggregation, overflow, exact-limit and empty-result behavior. They remain
unexecuted. No cached abaplint CLI was available for local native syntax checking.

## Remaining native integration blockers

1. Activate on a compatible BW system with `RSDRI_TH_SFC`, `RSDRI_TH_SFK`,
   `RSDRI_T_RANGE`, `RSINFOPROV`, `RS_BOOL` and `RSDR0_SPLIT_OCCURRED`. Confirm
   the installed function exposes the supplied parameters, including end/split
   flags, maximum/package size, read authorization and commit permission. The
   target must support the ABAP test-seam syntax; local tests cannot establish
   DDIC/function-signature or activation compatibility.
2. Execute native ABAP Unit tests, then small reviewed integration fixtures to
   establish actual InfoObject/DDIC type correspondence, grouped-result
   completeness, end/split flags, authorization denial under the real job user,
   empty/exact-limit/overflow behavior, and currency/unit grouping. The adapter
   preserves SAP checks, but analysis-authorization semantics and cap behavior
   before/after aggregation are not locally certified.
3. Certify each required provider type/version separately. Classic InfoCube,
   classic DSO and MultiProvider are intended initial scope only; no provider
   type has been live-certified by this work. ADSO, CompositeProvider, Open ODS,
   VirtualProvider, QueryProvider and master-data support are unverified.
4. Only after an authorized import/serialization comparison may the recorded
   SAP deployment evidence be regenerated. No such deployment is authorized here.

The maximum bounds returned data and requested SAP packages. It does not bound
database aggregation work or interrupt an in-progress SAP database call. No
production-read readiness is claimed.
