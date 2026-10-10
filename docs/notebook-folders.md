# Notebook folders

Folders organize your own notebooks without changing calculations. They are one level deep and private to your SAP user/client. Folders can contain notebooks from several models/environments; model groups remain inside each folder. Embedded mode continues to show only the hub-selected, authorized environment.

- Select **New folder** in the left workspace to create a named folder.
- Use the folder's rename button to change its name.
- Use a notebook's **Move to folder** button to select a folder or **Unfiled**.
- Expand/collapse each folder with its arrow. This view state lasts for the current component session.
- Search finds titles, explanations, model/environment names and IDs across all folders. Matching folders expand while searching; clear search to restore the previous collapsed view.
- Remove a folder only after moving all its notebooks out. A folder with notebooks in another currently hidden environment also cannot be removed. Folder removal never deletes notebooks.

All existing notebooks initially remain **Unfiled**. No automatic migration or example-folder creation runs. Folder actions also work while a notebook has an unsaved draft; they do not save, discard or modify it.

## Persistence and authorization

`GET /folders` returns `{ revision, folders: [{ id, name }], memberships: [{ notebookId, folderId }] }`. Missing membership means Unfiled. `PUT /folders` accepts the same complete organization plus `expectedRevision`. Refresh/reload after a 409 conflict; concurrent changes cannot overwrite one another.

The backend stores a separate immutable document history with kind `O`, keyed by the authenticated SAP user in the current client, through the existing owner-scoped/checksummed store. It uses the existing HTTP JSON/header/origin guards and trusted DEV/read/update authorizations. Every assigned notebook is checked for ownership, deletion and current environment/model access. No client-supplied owner is accepted. Folder names are 1-80 characters, unique ignoring case and whitespace differences; IDs are 1-64 ASCII letters/digits/underscore/hyphen. Limits: 200 folders and 10,000 memberships. Duplicate membership and unknown folder references fail. Removing a nonempty folder fails even if the same request removes its memberships: move notebooks out first.

Notebook kind `N` documents, revisions, source, execution snapshots, datasets and handler bindings remain unchanged. Deleted notebook membership is omitted from organization reads; its immutable notebook/run history remains under the existing deletion policy. Folder changes do not post financial data.

## Verification

`node tools/check-folders.cjs --codex-env` creates its own temporary unbound preview notebook/folder, checks actual native persistence and rejection paths, verifies unchanged source/revision/history, then removes only its own test folder and archives only its own test notebook. It leaves pre-existing folders and memberships untouched; organization revision increases to retain an audit trail. Native evidence is saved in `docs/evidence/native-folders.json`.

Local tests cover per-user isolation (including foreign ownership rejection), restart persistence, concurrent edits, empty/nonempty removal, unchanged execution snapshots and folder/search rendering with an unsaved draft. The final deployment additionally requires online abapGit serialization comparison and the full local test suite.
