# BW InfoProvider reads

Notebook Script v2 has `bwdata`, separate from BPC model reads. It reads an
explicit local BW technical provider through SAP `RSDRI_INFOPROV_READ` with
`I_AUTHORITY_CHECK = 'R'`. There is no SQL, remote destination, staging copy,
writeback or automatic fallback. SAP executes under the notebook job user;
that user's BW authorizations must be reviewed, especially for background jobs.
The adapter does not accept an authorization-disable option. It explicitly
disallows SAP commits and disables currency conversion. The read authorization
flag is preserved; the exact standard/analysis authorization behavior must be
verified in the installed BW release with an unauthorized job user.

```text
script version 2
bwdata facts = "ZSALES" fields characteristic "0CALMONTH" as MONTH type "/BI0/OICALMONTH", characteristic "0CURRENCY" as CURRENCY type "/BI0/OICURRENCY", keyfigure "0AMOUNT" as AMOUNT type "/BI0/OIAMOUNT" where "0CALMONTH" = ["202601"] limit 1000
show facts as "BW"
```

Use actual installed InfoObjects and their DDIC data elements. Aliases are
unique ABAP component names. Retain currency/unit characteristics when reading
amounts/quantities. Key figures use SUM, grouped by selected characteristics;
this is a provider fact read, not a BEx query or formula/exception aggregation.
Filters use exact internal-format values, OR within one list and AND across
distinct characteristics. Each filtered characteristic must be selected.
Duplicate filters, empty lists and silently truncated values are rejected.
No hierarchy expansion or BPC frozen scope is applied to BW filters.

ABAP cells use `io->bw_data( provider = ... fields = VALUE #( ... )
filters = VALUE #( ... ) max_rows = ... )`, returning a native dynamic table.
Field entries supply `infoobject`, `alias`, `ddic_type`, and `kind`
(`characteristic` or `keyfigure`). Existing table operations and dataset
publication work with the returned reference. Script Logic calls and fixture
executions reject this API, including direct adapter calls, so they cannot escape caller scope or read live BW
while testing. BPC authorization/result contracts remain unchanged.

The required limit is 1..100000 rows, with at most 100 fields/filters and 1000
values per filter. One bounded BW package requests limit+1 rows. Overflow or
an unfinished package or a split aggregation raises `BW_LIMIT` and returns no partial calculation
table. Narrow filters when a provider cannot finish within the package. No
automatic paging, bulk extraction or stable ordering is promised. Existing
deadline, working-row and working-byte checks apply after the read; SAP owns
the database-call duration and aggregation work.

## Compatibility and validation status

The selected interface is SAP's released BW Data Manager interface. Classic
InfoCubes, classic DSOs and MultiProviders are the intended initial provider
scope, subject to the installed RSDRI interface and its provider restrictions.
ADSO, CompositeProvider, Open ODS View, VirtualProvider, master-data and
QueryProvider support is **not certified by this implementation**. Availability
differs by BW release/provider settings; unsupported providers fail through
SAP with `BW_READ`. Do not interpret the technical provider argument as
universal support. No BW query-variable processing is offered.

Local tests verify compiler syntax, projection/filter generation, literal
escaping and static authorization/bounds policies. Twelve native ABAP Unit
tests include mocked denial, partial/split packages, overflow, exact-limit and
empty results; those tests have **not been executed**. No SAP activation, ABAP Unit execution or live BW
read was performed. Before release, check the installed DDIC structures and
function signature, activate the sources, and test a small authorized fixture
provider, denial of access, exact-limit/overflow, empty results, currencies,
and each required provider type. Explicit DDIC elements must match actual
InfoObject storage types; local validation checks flat element/numeric kind,
but does not establish that metadata correspondence. Verify that the installed
RSDRI result cap/end/split signals describe complete grouped results for each
provider, including MultiProvider partitions. The connected non-BW development system alone
cannot establish BW compatibility. No CET500 extraction into CWT300 or CWP to
CWT copy is authorized or performed.

SAP references: [released InfoProvider read interface](https://help.sap.com/docs/SUPPORT_CONTENT/bwplaolap/3361383473.html),
[authorization behavior](https://help.sap.com/docs/SUPPORT_CONTENT/bwplaolap/3361383924.html),
[interface/version notes (KBA 1828877)](https://userapps.support.sap.com/sap/support/knowledge/en/1828877).

See [local validation and baseline comparison](bw-validation.md) for exact test
results and outstanding activation requirements.
