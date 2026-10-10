// Author-facing explanations only: never modify a Script statement.
function annotate(script, title, explanation) {
  const lines = script.split(/\r?\n/);
  if (lines.some(line => line === '// DEMREVID003 business-rule notes')) return script;
  const out = [lines.shift(), '// DEMREVID003 business-rule notes', '// ' + title];
  for (const paragraph of explanation.split(/\n+/).filter(Boolean)) {
    const words = paragraph.split(/\s+/); let text = '';
    for (const word of words) {
      if ((text + ' ' + word).length > 105) { out.push('// ' + text); text = ''; }
      text += (text ? ' ' : '') + word;
    }
    if (text) out.push('// ' + text);
  }
  out.push('// Complete working tables stay in SAP; displayed previews are not calculation inputs.', '');
  let depth = 0; const seen = new Set();
  function note(key, text) { if (!seen.has(key)) { seen.add(key); out.push('// ' + text); } }
  for (const line of lines) {
    const text = line.trim();
    if (text === 'end') depth--;
    if (/^dataset /.test(text)) {
      const m = text.match(/^dataset (\w+) = "([^"]+)" named "([^"]+)"/);
      if (m) out.push('// Read the complete ' + m[3] + ' working table retained by ' + m[2] + '.');
    }
    if (/^data raw_source =/.test(text)) note('read', 'Read authorized model facts, including the selected reference periods; fail rather than use partial inputs.');
    if (/^project complete_source_data/.test(text)) note('schema', 'Keep all model dimensions and the signed amount so later stages retain the original calculation grain.');
    if (/^dimension /.test(text)) note('metadata', 'Read actual stored dimension metadata for member mappings; do not invent member IDs.');
    if (/^filter /.test(text) && depth === 0) note(text, 'Select the records required by this business block; retain their original signs and dimensions.');
    if (/^group /.test(text) && depth === 0) note(text, 'Sum signed amounts using the stated include/exclude dimension list and the original grouping semantics.');
    if (/^sort .* unstable by /.test(text)) note('sort', 'Preserve the original sort keys and tie behavior used by subsequent lookups.');
    if (/^index /.test(text)) note('index', 'Index the complete working table; matching rows and first-match lookup precedence remain explicit.');
    if (/^(find|lookup) .*missing initial/.test(text)) note('lookup', 'A missing lookup returns initial values; the following found checks and fallback branches control the outcome.');
    if (/^(find|lookup) .*ACCOUNT = "ACCOUNT_NA"/.test(text)) note('account-default', 'This lookup uses the default account member; keep its position in the original lookup waterfall.');
    if (/^(find|lookup) .*MATCONN = "MATCONN_NA"/.test(text)) note('material-default', 'Look up the default material member; surrounding found checks determine when this branch is used.');
    if (/numeric_text\(/.test(text)) note('num03', 'Format the numeric mapping as the original three-digit product code, then check the stored member table.');
    if (/^divide .* using float onzero keep/.test(text)) note('division', 'Use the original floating-point division; a zero denominator leaves the numerator unchanged.');
    if (/SIGNEDDATA.*\(1 -/.test(text)) note('rounding', 'Apply the remaining ratio difference to the selected first row, preserving the original rounding correction.');
    if (/offset\(/.test(text)) note('period', 'Resolve fiscal offsets through frozen TIME metadata, not by parsing the period name.');
    if (/^defaults /.test(text)) note('defaults', 'Fill initial dimensions with their original NA members; GEO_DRIVERS uses GDRVS_NA.');
    if (/^changes .*mode legacy/.test(text)) note('changes', 'Build the legacy CT_DATA change set: changed records contain replacement amounts; disappeared records receive zero clears.');
    if (/^copy final_replacement/.test(text)) note('replacement', 'Keep the complete newly calculated output separate from the existing output read at initialization.');
    if (/^publish /.test(text)) note('publish', 'Retain complete native datasets for downstream stages; publication here does not post financial data.');
    if (/^show /.test(text)) note('show', 'Display a bounded sample for review; source totals and complete SAP working datasets remain separate.');
    out.push(line);
    if (/^(for|if) /.test(text)) depth++;
  }
  return out.join('\n');
}
function generatedLogic(source) {
  return source.split('\n* @bn-generated\n')[1].split(/\r?\n/)
    .filter(line => !/^\s*\* @bn-line /.test(line)).join('\n');
}
module.exports = {annotate, generatedLogic};
