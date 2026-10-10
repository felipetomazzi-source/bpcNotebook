# Notebook Script v2: generic native working tables

For large method cells and explicit defaults/scalar adapters, see [compact Script](notebook-script-compact.md). Its opt-in `script version 2 compact` header supports up to 120,000 generated characters; ordinary cells retain 60,000.

Generic runtime implemented and verified in NPL/client001 using nonposting native checks. See `docs/evidence/native-script-v2.json` for the source commit, run IDs, checks and read diagnostics, and `docs/evidence/bpc-deployment.json` for actual SAP serialization comparison. Allocation conversion/equivalence is a separate calculation task. Begin each new v2 cell with `script version 2`. Existing v1 source/envelopes remain unchanged. Script is transpiled to ABAP on save and compiled by SAP before persisting. Author text, Unicode and line mapping remain in the saved envelope.

## Full tables and dependencies

```text
script version 2
dataset revenues = "read_revenues" named "REVENUES"
copy working = revenues
empty accumulated = revenues
publish working as "WORKING"
show working as "WORKING_PREVIEW"
```

`dataset` reads the complete native SAP dataset from a declared preceding cell dependency, with the run/source/revision/input/resource checks of `io->read_dataset`. `publish` persists the complete flat native table on SAP; empty schemas survive. Each consumer receives a private copy. `show` produces a bounded browser preview and is never a calculation input. Multiple named datasets can be published by one cell. Running one cell requires valid predecessor datasets; running through a cell executes its predecessors. Checkpoints are inspection boundaries, not arbitrary mid-cell resumability. Historical retries use the frozen snapshot and retained input datasets; live reads must follow the existing retry/data-snapshot contract, never silently blend old inputs with fresh references.

Stored dimension properties and hierarchies are reference inputs too. Adapter dimension access rejects a context using prior-run datasets. Publish the required member/property/hierarchy tables at the read boundary and consume those retained native datasets for independent later steps. Direct adapter property access returns current authorized metadata, not historical property values. A new run through the read stages establishes a new data snapshot.

## Tables, native types and arithmetic

```text
table rows columns CATEGORY member, TIME member, SIGNEDDATA signed, RATIO decimal
row r like rows
r.CATEGORY = member("CATEGORY")
r.TIME = "explicit_authorized_period"
r.SIGNEDDATA = signed("1.2345678")
r.RATIO = decimal("0.123456789012345678901234567890123")
append rows row r
append accumulated from rows
extend extended = rows with FLAG boolean, NOTE text
cast precise = rows with SIGNEDDATA decimal
project projected = rows fields ["CATEGORY", "TIME", "SIGNEDDATA"]
cast final = precise with SIGNEDDATA signed
```

Types: `member` = installed UJ_DIM_MEMBER; `signed` = installed UJ_SIGNEDDATA; `decimal` = decfloat34; `float` = ABAP f; `integer` = ABAP i; `text` = string; `boolean` = c(1). Native model tables preserve their original component types. Append requires exact ordered field names, kinds, lengths and decimals. Projection and casts are explicit copies.

V2 numeric literals and `number()` use UJ_SIGNEDDATA. Use `decimal("...")` for higher precision constants, `float(...)` for the original binary-floating intermediates, and `native amount = r.SIGNEDDATA` to retain the source scalar type. Assignment converts to the target native type and applies SAP rounding at that assignment boundary. `cast final = ... with SIGNEDDATA signed` must occur at the calculation's original business boundaries, not merely at the end if earlier seven-decimal assignments affected the original result. `result` rejects nonnative SIGNEDDATA and requires the installed seven-decimal type; it never silently rounds a high precision result.

```text
divide r.SIGNEDDATA by denominator using float onzero keep
r.SIGNEDDATA = r.SIGNEDDATA + signed("0.0000001")
```

The divide statement reproduces float conversion/division followed by native assignment; zero denominator keeps the original amount. Residual corrections belong in visible Script and must update the specifically selected existing row. No automatic ratio normalization is performed. `round(value, decimals, "half_up")` explicitly uses decimal arithmetic; other modes: `half_even`, `toward_zero`, `away_from_zero`, `ceil`, `floor`.

## Grouping, ordering and lookup precedence

```text
group byPeriod = rows include ["CATEGORY", "TIME"] amount "SIGNEDDATA"
group noMaterial = rows exclude ["MATCONN"]
group fullKeys = rows all
sort rows unstable by TIME asc, ACCOUNT asc, MATCONN asc
sort ranked stable by TIME asc, MATCONN asc, SIGNEDDATA desc
deduplicate ranked adjacent by ["TIME", "MATCONN"]
index ix = rows by ["TIME", "MATCONN"] many
lookup first = ix where TIME = "period" and MATCONN = "material" policy first missing initial
lookup last = ix where TIME = "period" and MATCONN = "material" policy last missing error
match joined = ix where TIME = "period" and MATCONN = "material"
```

Group sums only the designated amount, in native type, applying assignment rounding on each input addition. `include` clears omitted components; `exclude` clears listed components; `all` retains every nonamount component. Output keeps the full schema and first-occurrence group order. Empty input yields the same empty schema. Blank-member normalization is a separate visible Script operation: no hardcoded `_NA` defaults and no implicit member substitution.

Sort stability is mandatory and explicit. Adjacent deduplication retains the first row in the current order. Each index is an immutable private snapshot at construction: source mutations require rebuilding it. Composite keys use native SAP equality and require each key exactly once in a query. `many` retains duplicates/source order; `unique` rejects duplicate keys at construction. Lookup `first`/`last` are explicit source-order precedence; lookup `unique` fails on multiple matches. `missing initial` returns a typed initial row; `missing error` fails. `found(row)` captures that lookup's status. `match` returns all matching rows in source order with a complete schema, including zero matches. Joins and carry-forward are expressed as loops plus indexed queries; no model-specific runtime helper is required.

```text
find selected = rows where TIME = "period" and ACCOUNT = "account" search binary missing error
selected.SIGNEDDATA = selected.SIGNEDDATA + discrepancy
```

Unlike indexed lookup's private row copy, `find` aliases the current table row for visible mutation. `binary` uses native ABAP BINARY SEARCH; the author must sort by the matching ascending key prefix first. `linear` preserves native first-match behavior. This permits the allocation's exact residual-row selection without replacing it with generic normalization.

## Transformations and loops

```text
filter positive = rows as r where r.SIGNEDDATA > 0
for r in rows
  if r.MATCONN == ""
    r.MATCONN = "explicit_default"
  end
end
for r in rows copy
  r.TIME = nextPeriod
  append accumulated row r
end
for r in accumulated
  if r.SIGNEDDATA == 0
    delete r
  end
end
for period in range("TIME")
  message period
end
```

Plain row loops alias native rows; `copy` loops use independent rows. Structural changes to a table being iterated are rejected except `delete` of the current innermost row (which continues the loop). `break`, `continue`, `clear row`, `clear nativeScalar`, `assert condition message "..."` are available. Scalar helpers: `initial`, `found`, `upper`, `lower`, `abs`, `is_in(value, ids)`, `matches(value, "A*")`, `slice(text, zeroBasedOffset, length)`.

## Metadata, output periods and reference scope

```text
dimension materials = DEMREVID-MATCONN
members properties = materials
properties schema = materials
let productType = materials-PRODUCT_TYPE("member_id")
let hierarchyNames = hierarchies(materials)
let descendants = children(materials, "node_id", "PARENTH1")
model calculation = DEMREVID
data output = calculation where TIME = range("TIME") and CATEGORY = selection("CATEGORY") limit 100000
reference model references = DEMREVID
data mappings = references where TIME = ["TIME_NA"] limit 100000
let previousPeriod = offset(member("START_PERIOD"), -1)
```

Use actual authorized model/dimension/property metadata. `members` returns complete member/property rows; `properties` returns their schema metadata. Stored properties never invoke legacy constructors or derived-property providers implicitly. `offset` uses frozen actual fiscal links, not member-name parsing (existing ±24 offset contract). `range("TIME")` contains output base periods. Reference reads require separately configured and frozen authorized reference members/lookback members. An arbitrary explicit reference filter is rejected; it cannot enlarge output periods. Script Logic caller current-view restrictions continue to apply; reference exceptions require the existing explicit binding/current-view contract. DSL introduces no bypass. Port simple uppercase/alternative text derivations explicitly; provider implementation/version remains a reviewed server extension point, currently unsupported unless installed.

## Explicit results and change sets

```text
cast replacement = calculated with SIGNEDDATA signed
changes delta = replacement against previous mode legacy
result delta as "BPC_RESULT" kind delta
```

`legacy` returns replacement-valued changes, not subtraction: sorts old by all nonamount fields; compares each new row with the first matching old row; clears that matched old amount after each match; omits equal rows; keeps changed/new values including zeros; appends zero clears for remaining nonzero old records. Duplicate rows are not compressed. `unique` rejects duplicate keys in both inputs. Original ordering, duplicate handling and clearing semantics remain reviewable. Result publication is explicit and separate from previews. The existing pinned BAdI handler validates target model/schema/members/write authorization and owns transaction behavior; generic runtime adds no COMMIT or ROLLBACK. Preview workers do not post financial data. Fixtures cannot publish BPC results.

## Shared fixtures, native comparison and checkpoints

```text
fixture completeInputs model "DEMREVID"
compare counts = original with notebook as "EXACT_COMPARISON"
compare changes = originalDelta with notebookDelta as "ORDERED_DELTA" ordered
assert counts.changed == 0 message "Changed native records"
checkpoint "material ratios" start inputs ["BASE_REVENUES"] outputs ["RATIOS"]
publish ratios as "RATIOS"
checkpoint "material ratios" finish inputs ["BASE_REVENUES"] outputs ["RATIOS"]
```

Fixture mode supplies complete native in-memory model input tables without financial writes, with model/schema/member/authorization/filter checks and no silent fallback to live reads. Enable fixture mode in the first executed cell and in every subsequent context, including pure comparison cells; publish the fixtures as full datasets and pass them to both implementations within the existing immutable fixture contract. `compare` compares every dimension and exact native SIGNEDDATA inside SAP and emits full counts plus bounded difference previews. Its default key comparison rejects duplicates. The explicit `ordered` mode compares complete native rows at each position, retaining duplicate multiplicity and order, with positional changed/added/missing counts and at most 100 preview rows carrying original/notebook labels and positions. It is appropriate for the legacy replacement-valued change set. It does not claim a key-based alignment when record order differs. Read diagnostics remain supplied by the generic adapters, including effective filters/scopes/security/full count.

Working tables stay on SAP. WORK_ROWS, read limits, deadlines and DATASET_BYTES fail explicitly, never truncate calculation inputs. Per-operation working-table/index memory guards are estimates, not a total live-heap accounting mechanism; published/consumed dataset budgets remain cumulative. A failed cell cannot publish a completed partial dataset. Large workload budgets must be set explicitly and validated with representative data.

Ordered comparison adds two reserved preview fields, `BN_DIFF_POSITION` and `BN_DIFF_SOURCE`; its input is limited to 98 fields and must not already contain those names. Other full native working tables support up to 100 fields.

The generic runtime lives in ZCL_BN_TABLE / ZCL_BN_INDEX; it contains no DEMREVID business constants or model-specific method calls. The original allocation class is used only as a controlled test oracle. Full 21-step allocation equivalence requires the separate Script conversion and representative nonempty comparisons, including skipped flags, connections, lookbacks and final CT_DATA semantics.
