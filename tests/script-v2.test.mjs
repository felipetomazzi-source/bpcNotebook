import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
let Script;
vm.runInNewContext(readFileSync('webapp/model/Script.js','utf8'),{sap:{ui:{define:(_,f)=>Script=f()}},TextEncoder,TextDecoder,btoa,atob});
export const nativeScript = `script version 2
# É · São — native rows, not browser numbers
table rows columns CATEGORY member, TIME member, MATCONN member, SIGNEDDATA signed
row r like rows
r.CATEGORY = "Actual"
r.TIME = "period_A"
r.MATCONN = "A"
r.SIGNEDDATA = signed("0.3333333")
append rows row r
r.MATCONN = "B"
append rows row r
r.MATCONN = "A"
r.SIGNEDDATA = signed("0.3333334")
append rows row r
copy original = rows
compare ordered = original with original as "DUPLICATE_COMPARE" ordered
assert ordered.original_rows == 3 and ordered.unchanged == 3 and ordered.changed == 0 message "Ordered duplicate comparison"
copy orderedDifferent = original
for orderedRow in orderedDifferent
  orderedRow.SIGNEDDATA = orderedRow.SIGNEDDATA + signed("0.0000001")
end
compare orderedChanges = original with orderedDifferent as "ORDERED_CHANGED" ordered
assert orderedChanges.changed == 3 and orderedChanges.added == 0 and orderedChanges.missing == 0 message "Exact duplicate differences"
empty orderedShort = original
append orderedShort row r
compare orderedMissing = original with orderedShort as "ORDERED_MISSING" ordered
compare orderedAdded = orderedShort with original as "ORDERED_ADDED" ordered
assert orderedMissing.missing == 2 and orderedAdded.added == 2 message "Positional row coverage"
group sums = rows include ["CATEGORY", "TIME"]
assert count(sums) == 1 message "Group count"
for total in sums
  assert total.SIGNEDDATA == 1 message "Exact native sum"
  assert initial(total.MATCONN) message "Excluded fields must stay blank"
end
group allkeys = rows all
assert count(allkeys) == 2 message "All native grouping keys"
group excluded = rows exclude ["MATCONN"]
compare comparison = sums with excluded as "GROUP_COMPARE"
assert comparison.changed == 0 message "Grouping mismatch"
index ix = rows by ["TIME", "MATCONN"] many
lookup first = ix where TIME = "period_A" and MATCONN = "A" policy first missing error
lookup last = ix where TIME = "period_A" and MATCONN = "A" policy last missing error
assert first.SIGNEDDATA == signed("0.3333333") message "First precedence"
assert last.SIGNEDDATA == signed("0.3333334") message "Last precedence"
first.SIGNEDDATA = 99
lookup retained = ix where TIME = "period_A" and MATCONN = "A" policy first missing error
assert retained.SIGNEDDATA == signed("0.3333333") message "Private lookup copy"
match both = ix where TIME = "period_A" and MATCONN = "A"
assert count(both) == 2 message "One-to-many match"
lookup missing = ix where TIME = "absent" and MATCONN = "A" policy first missing initial
assert not found(missing) message "Missing state"
assert initial(missing) message "Missing native initial row"
assert found(retained) message "Found state captured per lookup"
sort rows stable by TIME asc, MATCONN asc, SIGNEDDATA desc
deduplicate rows adjacent by ["TIME", "MATCONN"]
assert count(rows) == 2 message "Deduplication"
find correction = rows where TIME = "period_A" and MATCONN = "A" search binary missing error
native residual = correction.SIGNEDDATA
residual = signed("0.0000001")
correction.SIGNEDDATA = correction.SIGNEDDATA + residual
assert correction.SIGNEDDATA == signed("0.3333335") message "Live residual correction"
divide correction.SIGNEDDATA by 0 using float onzero keep
assert correction.SIGNEDDATA == signed("0.3333335") message "Zero divisor keeps native value"
divide correction.SIGNEDDATA by 2 using float onzero keep
assert correction.SIGNEDDATA == signed("0.1666668") message "Float then native assignment rounding"
copy different = rows
for difference in different
  if difference.MATCONN == "A"
    difference.CATEGORY = "Other"
  else
    difference.SIGNEDDATA = difference.SIGNEDDATA + signed("0.0000001")
  end
end
compare differences = rows with different as "NATIVE_DIFFERENCES"
assert differences.added == 1 and differences.missing == 1 and differences.changed == 1 message "All dimensions and exact signed amount comparison"
extend working = rows with RATIO decimal, NOTE text, FLAG boolean
for w in working
  w.RATIO = decimal("0.000000000000000000000000000000001")
  assert w.RATIO > 0 message "Intermediate precision"
  w.NOTE = "É · São"
  w.FLAG = true
end
project projected = working fields ["CATEGORY", "TIME", "MATCONN", "SIGNEDDATA"]
compare roundtrip = rows with projected as "PROJECTION_COMPARE"
assert roundtrip.changed == 0 message "Projection preserves native values"
cast high = rows with SIGNEDDATA decimal
for h in high
  h.SIGNEDDATA = decimal("1.123456789012345678901234567890123")
end
cast final = high with SIGNEDDATA signed
for f in final
  assert f.SIGNEDDATA == signed("1.1234568") message "Explicit seven-decimal boundary"
end
filter filtered = rows as candidate where candidate.MATCONN == "B"
assert count(filtered) == 1 message "Filtering"
empty accumulated = rows
append accumulated from filtered
for d in accumulated
  delete d
end
assert count(accumulated) == 0 message "Delete current row"
for id in ["A", "B"]
  assert is_in(id, ["A", "B"]) message "Member list iterator"
end
assert matches("Abcd", "A*") message "Pattern"
assert slice("Abcd", 1, 2) == "bc" message "Slice"
assert round(decimal("1.25"), 1, "half_even") == decimal("1.2") message "Explicit rounding mode"
checkpoint "native operations" start outputs ["ORIGINAL", "EMPTY"]
publish original as "ORIGINAL"
publish accumulated as "EMPTY"
checkpoint "native operations" finish outputs ["ORIGINAL", "EMPTY"]
show working as "WORKING"
message "NATIVE_SCRIPT_OK"`;
test('v2 native table language compiles deterministically and preserves exact author text',()=>{
 const abap=Script.compile(nativeScript);
 assert.equal(Script.unpack(abap).text,nativeScript);
 assert.match(abap,/zcl_bn_table=>group/);assert.match(abap,/NEW zcl_bn_index/);
 assert.match(abap,/BINARY SEARCH/);assert.match(abap,/CATCH cx_sy_zerodivide/);
 assert.equal(abap.split('\n').every(s=>s.length<=255),true);
});
test('v2 uses explicit numeric and financial boundary contracts',()=>{
 const abap=Script.compile('script version 2\ntable rows columns SIGNEDDATA signed, TIME member\nresult rows as "OUTPUT" kind delta');
 assert.match(abap,/signed_boundary/);assert.match(abap,/kind = `delta`/);
 assert.match(Script.compile('let x = 1'),/CONV decfloat34/);
 assert.match(Script.compile('script version 2\nlet x = 1'),/CONV uj_signeddata/);
});
test('v2 dynamic lists and row property access retain native metadata calls',()=>{
 const source='script version 2\nreference model refs = DEMREVID\ndimension d = refs-CATEGORY\nmembers rows = d ["Actual"]\nfor row in rows\nlet description = d-EVDESCRIPTION(row.ID)\nrow.ID = "Actual"\nlet prior = offset("period", -1)\ndata facts = refs where TIME = [prior] limit 10\nend';
 const abap=Script.compile(source);
 assert.match(abap,/member = CONV string/);assert.match(abap,/io->reference_model/);
 assert.equal(Script.unpack(abap).text,source);
});
test('v2 rejects ambiguous index, sort, mutations and implicit financial publication',()=>{
 const prefix='script version 2\ntable rows columns TIME member, SIGNEDDATA signed\n';
 for(const suffix of ['sort rows by TIME asc','index ix = rows by ["TIME"]','result rows as "OUTPUT"',
 'index ix = rows by ["TIME"] many\nlookup r = ix where SIGNEDDATA = 1 policy first missing initial',
 'for r in rows\nappend rows row r\nend','delete r','break','deduplicate rows adjacent by []']){
  assert.throws(()=>Script.compile(prefix+suffix),/Script line/,suffix);
 }
 assert.throws(()=>Script.compile('dataset rows = "seed" named "FULL"'),/Script line/);
});
