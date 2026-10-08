# Notebook and cell management

Use the trash button beside a notebook in the sidebar, or **Delete notebook** in its toolbar. Confirmation removes it from the active list. The backend checks ownership and the displayed revision, and refuses deletion while an execution is queued or running. Saved versions, immutable sources, execution snapshots and output previews remain available for audit; new saves, submissions and bound Script Logic invocations are blocked for a deleted notebook.

Use the trash button in a cell header to remove a step. If other cells depend on it, confirmation lists the selected cell and all transitive dependents. This avoids leaving invalid dependency references or silently rewriting authored code. Cell removal is an unsaved edit until **Save version**; previous versions and runs retain their original cells.

Creating or opening another notebook with unsaved changes offers **Save**, **Discard**, or **Cancel**. Save must succeed before navigation continues. Discard leaves the saved revision unchanged. Requests superseded by a newer notebook selection cannot replace the current notebook.

## Loading performance

The SAP notebook endpoint previously read and decoded every dataset for every cell and again for dependency freshness checks. It now loads relevant published run-result headers once per request, reuses a per-notebook metadata cache, and reads output metadata without loading preview rows into that cache. Dataset/document checksum validation remains enabled. New result records include their output creation time, allowing older candidates to be skipped; historical results without that field still use the actual dataset timestamp.

Notebook and execution lists return summaries. Retrieve a full notebook from GET /notebook and a frozen execution from GET /run; list responses do not contain cell sources or execution snapshots. Replaced notebook-list and input controls are destroyed to release their resources. The main workspace uses standard UI5 busy handling during loading.

For the tested saved Notebook Script example, one SAP notebook load fell from 11,144 ms to 152 ms. The notebook list payload fell from 109,573 to 5,734 bytes; its run list fell from 42,748 to 3,900 bytes. These are measured samples on the connected DEV system, not a latency guarantee for every notebook.

## API and verification

POST /delete-notebook takes notebookId and expectedRevision, and returns a deleted flag. It uses the same JSON/custom-header, origin and authorization protections as other writes. Deletion writes an immutable owner-scoped tombstone; it does not erase notebook history. Cell deletion uses the existing revision-checked notebook save contract.

[SAP verification evidence](evidence/notebook-deletion.json) covers native execution, saved cell removal, immutable history/output retention, revision conflicts, active execution refusal, deleted-resource guards, a bound handler refusal, list summaries and a Script Logic regression run. Browser checks cover delayed-response navigation, cascade confirmation, saving cell removal, Save/Discard navigation and notebook removal from the sidebar. The local suite includes corresponding deletion and HTTP protection tests.
