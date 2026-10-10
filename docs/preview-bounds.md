# Complete datasets and bounded display output

`publish_dataset` retains the complete native table in SAP. `read_dataset` returns a private full native working copy. Preview clipping does not modify either table, its schema, row count, financial values, binary packet or checksum. A preview is never a calculation dependency or an implicit allocation result.

Browser display output has three separate limits:

- Dataset publication previews use `PREVIEW_ROWS` (default 200, maximum 5,000). Direct `show`/`emit_table` output has a maximum of 5,000 rows.
- Each displayed value has at most 4,096 characters. Longer strings become a UTF-8-valid prefix followed by an ellipsis. Native financial numbers and dimension IDs fit within this limit and remain exact decimal strings/member IDs.
- All preview tables in one cell share an eight MiB UTF-8 JSON display budget. Schema overhead and row delimiters are reserved conservatively. When rows no longer fit, the remaining rows are omitted from the preview, with the complete source count retained. An oversized schema fails explicitly. Combining fixture-context previews must respect the same budget.

Output API pages and their table summaries expose `valuesTruncated`, `truncatedValues`, `byteLimitReached`, `valueCharacterLimit`, `previewByteLimit` and `previewBytes`. `previewBytes` is the conservative display reservation, not the size of the full native artifact. Existing `total`/`rowCount` remain the available preview count; `sourceTotal`/`totalCount` remain the complete source count. `truncated` identifies omitted rows, separately from shortened values.

The standard UI5 table selector marks shortened previews. The page label reports shortened values and when the preview size limit was reached, including empty previews. Paging continues over the retained bounded preview. It does not retrieve clipped full values through the browser.

Metadata packet manifests receive the same display limits as other native tables. Their full serialized member tables stay in server-side datasets; clipped `rows_packet` values displayed in the browser must never be parsed or used as fixture inputs.

`GET /output` applies the same limits to legacy persisted table previews before returning them. It does not rewrite the immutable document. Legacy scalar key/amount pages also clip oversized keys while preserving amount values; their maximum 100 rows keeps each page below the byte budget.
