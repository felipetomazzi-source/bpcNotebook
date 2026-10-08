# Encoding and SAP serialization verification

The connected SAP system imported and serialized all **38 repository artifacts** on 2026-10-08. Every serialized byte matches its actual Git clean-filter blob. [Machine-readable results](sap-roundtrip.json) record the Git blob identity, SAP SHA-256, byte length and comparison for every file. This covers 8 classes and their test includes, 2 reports, 3 tables, BSP application metadata and 7 page bodies, SICF metadata, package metadata and `.abapgit.xml`.

## Conventions verified against BPCIO

BPCIO's `.abapgit.xml` and object metadata XML contain a UTF-8 BOM. ABAP and BSP page bodies do not. Its Git blobs contain LF; its Windows checkout uses CRLF because Git applies `core.autocrlf`. Notebook explicitly declares the equivalent checkout convention in `.gitattributes`. The comparison uses `git hash-object -w --path` and `git cat-file blob`, retaining BOMs, padding, punctuation and blank lines while applying Git's declared newline conversion. The local comparison uses Git clean-filter blobs; the deployed comparison additionally checks the serialized bytes against the committed branch after an online abapGit pull.

BSP content uses 255-character padded lines, separated by newlines without an additional terminal separator. An input ending in a newline produces a padded final empty line; an input without one does not. Packaging preserves source trailing spaces and intentional blank lines. Reads use fatal explicit UTF-8 decoding and writes specify UTF-8. The current middle-dot punctuation also passed through SAP intact. Regression tests cover accented text, punctuation and terminal-line variants.

## Differences investigated and fixed

- Replaced compressed hand-built metadata and source formatting with actual SAP abapGit output, including generated DDIC field details and exception-class formatting.
- Removed wholesale native-source rewriting, BOM stripping and `trimEnd()` from packaging. Canonical metadata remains owned by SAP serialization.
- Mapped external UI5 `Component-preload.js` to the valid internal BSP page `Componentpreload.js`; the SAP page API rejected the hyphenated internal name.
- Verified the seven BSP pages against the six UI5 mappings plus the mapping file itself. Packaging rejects stale files and missing mappings/pages.
- Headless workbench activation did not initially activate BSP pages. The verification runner explicitly loads the **inactive** version and activates it using the SAP BSP API. Returned nonempty page bodies were then compared, so an empty/omitted export cannot pass.

## What was run

```powershell
$env:BPC_ADT_TOOL_ROOT='C:\Users\FelipeTomazzi\mcps\mcp-abap-abap-adt-api'
node tools/sap-roundtrip.cjs --codex-env --import --package=ZBPC_NOTEBOOK --transport=NPLK900126 --output=.local/sap-selections-final
npm test
```

The runner executes SAP's installed `ZCL_ABAPGIT_OBJECT_*` deserializers and `ZCL_ABAPGIT_OBJECTS=>SERIALIZE` through a development-only `$TMP` class, `ZCL_BN_SERIALIZE_CHECK`. Repository configuration also passes through `ZCL_ABAPGIT_DOT_ABAPGIT` deserialize/serialize. Input is a ZIP of actual local Git blobs; it never uploads credentials or pushes Git. Final comparison: **41/41 identical; no missing files**. The local suite passes 16 tests, including packaging idempotence and hashes against this real SAP export.

Application objects were verified in `$TMP`. Package metadata was independently imported into `$BN_ROUNDTRIP` to avoid modifying `$TMP`'s description; abapGit package metadata intentionally allows installation-package remapping. SICF `/sap/bc/zbpc_notebook` was imported with its normal handler and activated by the abapGit deserializer. No trusted-user execution enablement was added. These verification objects remain available for inspection.

This verifies actual SAP import/serialization against Git; it does not claim a network pull from the remote branch or installation into the transportable `ZBPC_NOTEBOOK` package. Those deployment checks, SAP UI5 browser acceptance and background execution acceptance remain documented in `INSTALL.md`. Re-run the comparison after changing any native source, metadata or BSP body; the recorded hashes deliberately invalidate stale evidence.

## Deployment follow-up

At the user’s request, code was pushed to main and pulled through SAP abapGit using transport NPLK900126. A second SICF object for the SAP UI5 launch URL is now included. The newest machine-readable comparison imports all 41 files against package ZBPC_NOTEBOOK; every file passes. Browser testing on installed SAP UI5 found and fixed its unsupported ObjectStatus Information value state and the empty native error structure. DEVELOPER is enabled in DEV client 001. The real background allocation succeeded and returned CC100 = 66,000. Earlier paragraphs describe the initial local-package verification; this follow-up supersedes its deployment limitations.

The BPC selector deployment additionally passed a full online repository serialization after the network pull: **41/41 files match committed Git blobs**, with no missing package objects. See [deployment evidence](bpc-deployment.json). The test caught and corrected old `$TMP` assignments for WAPA and the notebook API SICF object using SAP's TADIR/CTS APIs and the existing transport.

## Notebook Script Logic deployment

The latest comparison covers all 45 files, including the NOTEBOOK BAdI enhancement and its SAP-generated SOTR text identifiers. The enhancement XML was canonicalized from the real SAP serializer and then imported/serialized again without differences. UTF-8 BOM conventions, CRLF checkout line endings, BSP 255-character padding, punctuation and intentional blank lines remain preserved. The local suite passes 23 tests; six harmless native adapter/context tests and real BAdI invocation tests also pass. See notebook-logic.json for pinned revision, caller LUW and parameter/current-view checks.
