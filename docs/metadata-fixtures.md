# Frozen metadata for nonposting comparisons

Fact fixtures alone do not freeze dimension properties or hierarchy resolutions. Use the optional metadata bundle contract when comparing calculations against identical complete inputs. Original-code adapters must also use the fixture context; a legacy constructor that reads SAP directly still produces a provisional comparison.

Capture live authorized metadata in the first preparation cell of a new DEV preview run. Use `io->snapshot_identifier( )` for every bundle. Do not capture metadata after attaching historical dependencies. Capturing dimensions sequentially does not provide a database-wide transactional snapshot: coordinate against master-data maintenance, and retain the capture provenance when reporting equivalence.

```abap
DATA bundles TYPE zcl_bn_bpc=>tt_dimension_fixtures.
DATA(adapter) = io->bpc_dimension( 'AUDITTRAIL' ).
APPEND adapter->capture_dimension(
  snapshot_id = io->snapshot_identifier( )
  hierarchy_reads = VALUE #( ( hierarchy = 'PARENTH1' member = 'DEMREVID_OUTPUT' ) ) ) TO bundles.
" Add the other required dimensions using the same capture identifier.
DATA packets TYPE zcl_bn_bpc=>tt_dimension_packets.
packets = zcl_bn_bpc=>pack_dimensions( fixtures = bundles max_bytes = 67108864 ).
io->enable_fixtures( fixtures = VALUE #( ( environment = io->environment
  model = io->model rows = facts ) ) dimensions = bundles freeze_metadata = abap_true ).
io->publish_dataset( name = 'FACTS' rows = <facts> ).
io->publish_dataset( name = 'METADATA' rows = packets ).
```

Here `facts` is a reference to the complete authorized native model table, and `<facts>` is its assigned table. Author-specific dimension and hierarchy names belong in the preparation cell, not in the generic runtime.

Packets form one flat native table. Each packet retains a complete native member-table schema/content, stored property schema, hierarchy names and explicitly requested root-to-base resolutions. Packet serialization uses the existing checksummed native dataset codec. Publish the packet table as a full SAP dataset, never a browser preview. Fiscal links come from the retained TIME member properties; lookback execution must continue using the run's already authorized, frozen fiscal links.

Each dependent Script cell loads both datasets from its declared preparation dependency:

```text
script version 2 compact
dataset facts = "capture" named "FACTS"
dataset metadata = "capture" named "METADATA"
fixture facts model "DEMREVID" metadata metadata
dimension audit = DEMREVID-AUDITTRAIL
```

ABAP cells use `io->enable_fixtures( fixtures = ... metadata = <metadata> freeze_metadata = abap_true )`. `fixture_copy` retains private copies of the same fact and metadata bundles for the original implementation. Route its dimension reader through that copied context's `bpc_dimension` adapter. Neither Script Logic nor allocation-result publication accepts fixtures.

In metadata fixture mode, member tables, stored properties, hierarchy names, captured child resolutions and fiscal properties use retained values. An uncaptured dimension/member/root fails; it never falls back to live values. The adapter rechecks current model/member read authorization and member existence, which can reject revoked access without substituting current descriptions or properties. Virtual providers remain explicit and are not captured or invoked automatically.

Consumers receive private native table copies, including empty schemas. The combined metadata packet and native-table payload is bounded by the configured dataset budget; over-budget inputs fail without truncation. There are at most 50 bundles and 1,000 explicit hierarchy resolutions per bundle.

Historical execution may load retained packets and facts through validated declared dataset dependencies. Their producing run IDs and every participating binding must match the bundle capture ID. Mixed snapshots fail `DATA_SNAPSHOT`. Capture and fresh metadata enrichment remain forbidden with prior-run dependencies. A new capture requires a new run through the preparation stage. Persisted checkpoints support cell boundaries, not arbitrary mid-cell recovery.

Legacy `fixture facts model "..."` remains compatible and freezes facts only. It must not be described as a complete metadata snapshot comparison.
