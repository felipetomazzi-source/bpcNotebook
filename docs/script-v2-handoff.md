# Calculation-agent handoff: generic Script v2

Runtime source: `74c4dc512ffe0ff7c9e5dbdfff33bff2f45ccee5`, branch `codex/notebook-script-tables`.
Integrated deployment source: `17073f5` on `codex/SSNG-3218-fixture-validation`.
SAP: NPL, client 001, package ZBPC_NOTEBOOK, abapGit repository 000000000008, transport NPLK900126. Source changes were transported through Git/abapGit; no direct global source upload and no financial posting during verification.

The full syntax and semantics are in [Notebook Script v2](notebook-script-v2.md). Start every new cell with `script version 2`. The runtime contains no model-specific calculation calls. Original allocation classes appear only in the controlled verification oracle.

## Ready capabilities

- Complete typed SAP datasets shared across declared cell dependencies, immutable publication/private consumption and empty-schema retention. Browser previews are never calculation inputs.
- Native table creation, copying, projection, column extension/casting, append, filter, row mutation/deletion and explicit copy loops.
- Native grouping by included/excluded/all nonamount dimensions. Explicit stable/unstable sorts and adjacent deduplication.
- Immutable composite-key indexes, first/last/unique precedence, one-to-many matches, missing policies, and live native binary/linear `find` aliases for residual corrections.
- Explicit high precision `decimal` intermediates, float division with zero-denominator retention, native scalar types and explicit seven-decimal `signed` casts at original calculation boundaries.
- Separate frozen output/reference scopes, actual fiscal offsets, authorized metadata/stored-property access and read diagnostics.
- Exact key-based native result comparison and explicit ordered comparison retaining duplicate multiplicity/order. Full counts and bounded difference previews.
- Controlled shared fixture input tables, checkpoints, full dataset counts, resource/deadline checks and stale predecessor rejection.
- Explicit result publication through the existing pinned, validated, transaction-owned allocation integration; fixture mode blocks publication. Legacy `changes ... mode legacy` produces replacement values and zero clears, preserving duplicate behavior and order.

## Verification

`npm test`: 40 passing local checks. Targeted ABAP syntax/parser lint: zero issues across 64 files. `tools/check-script-v2.cjs`: 15 passing native checks, including deliberate expected failures. Its recorded `passed` status is true. The native descriptor is UJ_SIGNEDDATA kind P, 11 bytes, seven decimals.

The native checks cover nonempty arithmetic/grouping/lookup/transforms, exact ordered duplicate differences, legacy duplicate changes against the original helper, 12,003-row full native handoff with three-row browser previews, empty schema/private copies, single-cell reuse/stale rejection, real authorized model fixtures and fiscal lookbacks, read diagnostics, undeclared references, fixture posting prohibition, numeric result boundaries and explicit resource failure.

Final SAP serialization compared every one of the 65 repository files byte for byte with committed Git blobs, including BOMs, line endings and serializer padding. Evidence:

- [Native runs, read diagnostics and frozen selections](evidence/native-script-v2.json)
- [Actual SAP import/serialization comparison](evidence/bpc-deployment.json)
- [SAPUI5 repository cache metadata refresh](evidence/ui-cache-refresh.json)

## Continue the allocation

Translate the 21 business stages method by method into visible Script using generic adapters. Preserve every original lookup fallback, binary-search flag, unstable/stable sort choice, blank-member default, native assignment/rounding boundary, suppression flag and selected residual row. Use full named datasets for stage inputs/outputs; keep checkpoints for the material ratio stages.

Publish needed dimension member/property/hierarchy metadata as complete datasets in the read stages. Fresh dimension adapter access is rejected when a cell binds preceding datasets from another run; retained metadata must be used for independent execution. Running through the read stages creates a new snapshot.

Enable fixture mode in the first executed cell and every subsequent cell, including comparison cells. Both implementations must use the same complete retained fixtures. Fixture runs cannot call `result`; publish the final replacement/change-set datasets and compare them. Use a separately controlled live allocation path for explicit `result` publication, retaining the existing backend authorization and transaction checks.

The remaining work is the allocation conversion and nonempty original-versus-Script equivalence testing. These platform checks do not prove all DEMREVID003 business paths or customer data equivalence. Restricted-user authorization cases and caller transaction rollback still need the calculation/integration acceptance checks; platform verification used DEVELOPER and never posted financial data.

Explicit limits: 100 flat native fields, 60,000 generated characters per cell, 50 diagnostic reads per cell, ±24 fiscal offsets from frozen actual metadata, and configured resource budgets. Generic working-memory guards estimate per-operation allocation; they are not total live-heap accounting. Arbitrary mid-step resumption is unsupported. Derived-property providers remain an explicit server extension point with no implementation installed; use actual stored PRODUCT_TYPE and visible simple derived values where appropriate. No additional known generic capability blocks the current translation.

Existing user notebooks and the unsaved bpcIO browser tab were preserved. Verification notebooks were created only for these checks and archived afterward.
