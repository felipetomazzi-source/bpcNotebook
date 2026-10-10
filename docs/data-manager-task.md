# Direct notebook Data Manager task (DEV preview)

This feature lets an ordinary BPC Data Manager package execute a revision-pinned Notebook handler without LGF or UJ_CUSTOM_LOGIC dispatch. The first release is preview only: it records calculation outputs and never performs business writeback.

## Objects

| Object | Purpose |
|---|---|
| ZCL_BN_DM | Validates package context, selection, overrides and approved handler revision; calls ZCL_BN_LOGIC=>INVOKE synchronously |
| ZCL_BN_DM_PROCESS | Installed BPC actor and BW process interfaces; parameter retrieval, package logs, success/failure mapping |
| ZCL_BN_DM_INSTALL | Explicit DEV chain provisioning; refuses existing chain/variant objects |
| ZBNBOOK | BW process type pointing to ZCL_BN_DM_PROCESS |
| ZBPC_NOTEBOOK | Reusable BPC process chain |
| ZBPC_NOTEBOOK_START | Unique immediate start variant; activation uses I_NOPLAN and does not schedule work |
| ZBPC_NOTEBOOK_RUN | Custom process variant |

On the connected SAP installation, /CPMB/DEFAULT_FORMULAS is the chain; /CPMB/DEFAULT_FORMULAS_LOGIC is its Run Logic task variant. The installer copies that installed six-row topology through CL_RSPC_CHAIN and replaces only the Run Logic and start variants. It preserves BPCMODIFY, both OR inputs and BPCCLEAR, including success/error routing.

The installer registers process type/text customizing after S_TABU_NAM checks and uses BW APIs for variants, trigger generation, chain creation/check/activation. It keeps BW authority checks enabled. It is deliberately DEV-only via existing Notebook authorization. Configuration is created without transport recording in this prototype; collect process type/text customizing, chain, start and process variants using normal SAP transport tools before distributing. Do not run the installer in production or change production enablement to use this prototype.

## Package configuration

Select ZBPC_NOTEBOOK when creating a package. The package script controls:

- SUSER, SAPPSET, SAPP: actual authenticated package context; overrides cannot impersonate another owner.
- SELECTION: native DM selection; explicit resolved base members are required. Use SELECTINPUT for noncalculated members. Invalid/calculated/unauthorized scope is rejected by Notebook validation; it is never silently dropped.
- HANDLER: a reviewed named Notebook binding belonging to the execution user.
- HANDLER_REVISION: positive approved binding revision. A rebind requires reviewing/updating the package.
- REPLACEPARAM: INPUT_<name>/HIERARCHY_<name> pairs; TAB and EQU are different single-character separators.
- WRITE=OFF and EXECUTION=PREVIEW are internal and cannot be changed by package overrides.

Use examples/data-manager/notebook-preview.txt as the DEV fixture example. When submitting through the native package API, use the exact prompt NAME including percent markers (for this example: %SELECTION% and %BNFACTORVALUE%). Plain names leave percent markers around the substituted value and can also replace substrings inside parameter keys. BN_DM_VERIFY / revision 1 identifies the currently verified fixture, not a business allocation. New fixtures or intentional rebindings may increment that revision; update the package explicitly. Different packages can use the same chain with different reviewed bindings.

The native SAP runtime may still contain owner-private handler/notebook restrictions and trusted DEV enablement. Production execution and cross-user approved publication are separate work. Business posting requires its own reviewed BPC transaction/writeback adapter; there is no posting implementation in this task.

## Transaction and status behavior

The task calls INVOKE in the current Data Manager work process. It creates no nested Notebook background job. Notebook run/artifact staging participates in the package LUW; the BPC actor is called with IF_ERROR_ROLLBACK enabled. The adapter itself does not commit. The standard BPC actor's SET_ALLOW_ABORT updates/commits its task state before calculation; it does not commit notebook outputs. Existing trusted ABAP cell code must respect the transaction contract.

The current synchronous notebook runner does not poll Data Manager abort during cells. The task therefore uses the same not-allow-abort behavior as installed BPC Run Logic. Notebook execution budgets still apply. Do not describe this as cancellable execution.

The process returns a noninitial BW instance and green only after a successful/warning actor status. Failure returns red and standard BPC cleanup still runs. Package logs include the notebook run ID and full notebook diagnostics. No partial financial rows can be posted because preview never exports a posting result.

## Development and verification

Branch: codex/notebook-data-manager. Worktree: C:/Users/FelipeTomazzi/projects/bpcNotebook-data-manager.

Set BPC_ADT_TOOL_ROOT to your installed mcp-abap-abap-adt-api folder. The tooling reads the existing configured ADT connection without printing credentials.

```powershell
node tools/deploy-data-manager.cjs
node tools/deploy-data-manager.cjs --install
node tools/check-data-manager.cjs --notebook=<saved CATEGORY/TIME notebook>
```

--install is an explicit provisioning action, not an idempotent update. A repeated invocation refuses an existing chain. After a failed installation, inspect its named objects and reconcile them before retrying; BW APIs can persist configuration before a later error.

The contract check creates a private two-cell nonposting fixture and reviewed handler. It changes the latest notebook source after binding to prove the pinned version is used, then checks native selection, typed/Unicode overrides, complete dependency outputs, rollback removing staged records, invalid overrides, empty scope and stale handler revision. Its live fixture remains available for the package test. It reads metadata from the seed and does not execute or alter its business cells.

The live DEV package is CH_PLANNING / DEMREVID / Calculations / BN_NOTEBOOK_PREVIEW. The verified run completed MODIFY, ZBPC_NOTEBOOK_RUN and CLEAR with status 1 / SUCCESS. It executed the reviewed notebook revision 1 while the latest draft was revision 2. Its second cell returned Data Manager preview / amount 4 for factor 2.

Evidence:
- docs/evidence/data-manager-deployment.json: SAP syntax/activation and explicit chain installation.
- docs/evidence/data-manager-contract.json: native contract assertions and fixture identity.
- docs/evidence/data-manager-package.json: actual Data Manager submission/status/log, pinned run and two-cell output verification.
- docs/evidence/data-manager-source.json: six native source/metadata blobs match committed Git bytes; all three classes have clean native syntax and package ZBPC_NOTEBOOK / request NPLK900128.

No existing business LGF, business package or /CPMB chain is modified.
