sap.ui.define([], function () {
  "use strict";
  var marker = "* BPC Notebook Script v1\n";
  function failure(line, message) {
    var error = new Error("Script line " + line + ": " + message);
    error.line = line; throw error;
  }
  function literal(value) {
    // Small ABAP literals also keep generated source within SAP's line width.
    var chunks = Array.from(String(value)).join("").match(/.{1,60}/gu) || [""];
    var encoded = chunks.map(function (s) { return "`" + s.replace(/`/g, "``") + "`"; }).join(" && ");
    return chunks.length === 1 ? encoded : "CONV string( " + encoded + " )";
  }
  function tokens(text, line) {
    var result = [], i = 0;
    while (i < text.length) {
      if (/\s/.test(text[i])) { i++; continue; }
      if (text[i] === "#") { break; }
      var rest = text.slice(i), match;
      if (text[i] === '"') {
        match = rest.match(/^"(?:[^"\\]|\\.)*"/);
        if (!match) { failure(line, "Unclosed text literal"); }
        var value;
        try { value = JSON.parse(match[0]); } catch (_) { failure(line, "Invalid text escape"); }
        if (/[\r\n\u0000]/.test(value)) { failure(line, "Text literals cannot contain line breaks or null characters"); }
        result.push({type:"text", value:value}); i += match[0].length; continue;
      }
      match = rest.match(/^\d+(?:\.\d+)?(?:[eE][+-]?\d+)?/);
      if (match) { result.push({type:"number", value:match[0]}); i += match[0].length; continue; }
      match = rest.match(/^[A-Za-z_][A-Za-z0-9_]*/);
      if (match) { result.push({type:"name", value:match[0]}); i += match[0].length; continue; }
      match = rest.match(/^(?:==|!=|<=|>=|[=+*/%<>()\[\],.\-])/);
      if (!match) { failure(line, "Unexpected character " + text[i]); }
      result.push({type:"symbol", value:match[0]}); i += match[0].length;
    }
    return result;
  }
  function compile(text) {
    text = String(text);
    var body = [], symbols = Object.create(null), blocks = [], serial = 0, line = 1, parts, at;
    function emit(code) { body.push(code); }
    function fresh() { return "bn_s" + (++serial); }
    function peek() { return parts[at] && parts[at].value; }
    function take(value) {
      if (value !== undefined && peek() !== value) { failure(line, "Expected " + value); }
      if (!parts[at]) { failure(line, "Unexpected end of statement"); }
      return parts[at++];
    }
    function name() {
      var token = take();
      if (token.type !== "name") { failure(line, "Expected a name"); }
      return token.value;
    }
    function lookup(id, kind) {
      var item = symbols[id];
      if (!item || kind && item.kind !== kind) { failure(line, "Unknown " + (kind || "variable") + " " + id); }
      return item;
    }
    function declare(id, kind, code) {
      if (symbols[id]) { failure(line, "Name already declared: " + id); }
      var item = {kind:kind, code:code || fresh()}; symbols[id] = item; return item;
    }
    function resource() {
      var values = [name()];
      while (peek() === "-") { take("-"); values.push(name()); }
      if (values.length > 3) { failure(line, "Use MODEL-DIMENSION or MODEL-DIMENSION-PROPERTY"); }
      return values;
    }
    function dimension(values) {
      if (values.length === 1 && symbols[values[0]]) { return lookup(values[0], "dimension").code; }
      if (values.length > 2) { failure(line, "Expected MODEL-DIMENSION"); }
      if (values.length === 2 && symbols[values[0]]) { values = [lookup(values[0],"model").resource,values[1]]; }
      var code = fresh();
      emit("DATA(" + code + ") = io->bpc_dimension( name = " + literal(values[values.length - 1]) +
        (values.length === 2 ? " model_name = " + literal(values[0]) : "") + " ).");
      return code;
    }
    function field(row, property) {
      var code = "<" + fresh() + ">";
      emit("FIELD-SYMBOLS " + code + " TYPE any.");
      emit("UNASSIGN " + code + ".");
      emit("ASSIGN COMPONENT " + literal(property.toUpperCase()) + " OF STRUCTURE " + row.code + " TO " + code + ".");
      emit("IF sy-subrc <> 0.");
      emit("  RAISE EXCEPTION TYPE zcx_bn EXPORTING code = 'BPC_SCRIPT_FIELD' detail = " + literal("Missing field: " + property) + ".");
      emit("ENDIF.");
      return {code:code, kind:"field"};
    }
    var precedence = {or:1, and:2, "==":3, "!=":3, "<":3, ">":3, "<=":3, ">=":3, "+":4, "-":4, "*":5, "/":5, "%":5};
    function condition(value) {
      if (value.kind !== "boolean") { failure(line, "A condition must compare values or use a boolean"); }
      return value.code + " = abap_true";
    }
    function expression(minimum) {
      minimum = minimum || 0;
      var token = take(), left;
      if (token.type === "text") { left = {kind:"string", code:literal(token.value)}; }
      else if (token.type === "number") { left = {kind:"number", code:"CONV decfloat34( " + literal(token.value) + " )"}; }
      else if (token.value === "true" || token.value === "false") {
        left = {kind:"boolean", code:token.value === "true" ? "abap_true" : "abap_false"};
      } else if (token.value === "(") { left = expression(); take(")"); }
      else if (token.value === "[" ) {
        var entries = [];
        while (peek() !== "]") {
          var entry = take();
          if (entry.type !== "text") { failure(line, "Member lists contain quoted IDs"); }
          entries.push("( CONV string( " + literal(entry.value) + " ) )");
          if (peek() !== ",") { break; } take(",");
        }
        take("]"); left = {kind:"ids", code:"VALUE zcl_bn_types=>tt_ids( " + entries.join(" ") + " )"};
      } else if (token.value === "-" || token.value === "not") {
        var operand = expression(6);
        if (token.value === "not") { left = {kind:"boolean",code:"xsdbool( NOT ( " + condition(operand) + " ) )"}; }
        else {
          if (operand.kind !== "number" && operand.kind !== "field") { failure(line, "Minus requires a number"); }
          left = {kind:"number",code:"( 0 - " + operand.code + " )"};
        }
      } else if (token.type === "name") {
        var id = token.value;
        if (peek() === "(" && ["input","member","range","selection","number","text","count","concat"].indexOf(id) >= 0) {
          take("(");
          if (["input","member","range","selection"].indexOf(id) >= 0) {
            var key = take(); if (key.type !== "text") { failure(line, "Parameter names must be quoted"); }
            left = {kind:id === "range" || id === "selection" ? "ids" : "string",code:"io->" + id + "( " + literal(key.value) + " )"};
            if (id === "range") {
              var iterator = fresh();
              left.code = "VALUE zcl_bn_types=>tt_ids( FOR " + iterator + " IN " + left.code + " ( CONV string( " + iterator + " ) ) )";
            }
          } else {
            var argument = expression();
            if (id === "count") {
              if (argument.kind !== "table" && argument.kind !== "ids") { failure(line, "count requires a table or member list"); }
              left = {kind:"number",code:"CONV decfloat34( lines( " + argument.code + " ) )"};
            } else if (id === "concat") {
              take(","); var second = expression();
              left = {kind:"string",code:"CONV string( CONV string( " + argument.code + " ) && CONV string( " + second.code + " ) )"};
            } else {
              if (["table","ids","row","dimension","model"].indexOf(argument.kind) >= 0) { failure(line, "Convert a scalar value"); }
              left = {kind:id === "number" ? "number" : "string",code:"CONV " + (id === "number" ? "decfloat34" : "string") + "( " + argument.code + " )"};
            }
          }
          take(")");
        } else if (peek() === "-" && symbols[id] && ["dimension","model"].indexOf(symbols[id].kind) >= 0 ||
          peek() === "-" && !symbols[id]) {
          var qualified = [id]; take("-"); qualified.push(name());
          if (peek() === "-") { take("-"); qualified.push(name()); }
          var adapter, property;
          if (qualified.length === 2 && symbols[id]) { adapter = lookup(id,"dimension").code; property = qualified[1]; }
          else if (qualified.length === 3) { adapter = dimension(qualified.slice(0,2)); property = qualified[2]; }
          else { failure(line, "Property access is DIMENSION_ALIAS-PROPERTY(member) or MODEL-DIMENSION-PROPERTY(member)"); }
          take("("); var member = expression(); take(")");
          if (member.kind !== "string") { failure(line, "Property member must be text"); }
          left = {kind:"string",code:adapter + "->property( member = " + member.code + " name = " + literal(property) + " )"};
        } else if (peek() === ".") { take("."); left = field(lookup(id,"row"), name()); }
        else { left = lookup(id); }
      } else { failure(line, "Expected a value"); }
      while (precedence[peek()] && precedence[peek()] > minimum) {
        var op = take().value, right = expression(precedence[op]);
        if (op === "and" || op === "or") {
          left = {kind:"boolean",code:"xsdbool( ( " + condition(left) + " ) " + op.toUpperCase() + " ( " + condition(right) + " ) )"};
        } else if (precedence[op] === 3) {
          if (["table","ids","row","dimension","model"].indexOf(left.kind) >= 0 ||
            ["table","ids","row","dimension","model"].indexOf(right.kind) >= 0) { failure(line, "Compare scalar values"); }
          left = {kind:"boolean",code:"xsdbool( " + left.code + " " + ({"==":"=","!=":"<>"}[op] || op) + " " + right.code + " )"};
        } else {
          if (["number","field"].indexOf(left.kind) < 0 || ["number","field"].indexOf(right.kind) < 0) {
            failure(line, "Arithmetic requires numbers; use number(input(...)) to convert text");
          }
          left = {kind:"number",code:"( " + left.code + " " + (op === "%" ? "MOD" : op) + " " + right.code + " )"};
        }
      }
      return left;
    }
    function dynamicTable(id, reference) {
      var item = declare(id,"table","<" + fresh() + ">");
      emit("FIELD-SYMBOLS " + item.code + " TYPE STANDARD TABLE.");
      emit("ASSIGN " + reference + "->* TO " + item.code + ".");
      return item;
    }
    text.split(/\r\n|\n|\r/).forEach(function (sourceLine, index) {
      line = index + 1; parts = tokens(sourceLine,line); at = 0;
      if (!parts.length) { return; }
      emit("* @bn-line " + line);
      var command = name(), id, value, item;
      if (command === "dimension") {
        id = name(); take("="); var values = resource();
        item = declare(id,"dimension",dimension(values)); item.resource = values;
      } else if (command === "model") {
        id = name(); take("="); var model = name(); item = declare(id,"model"); item.resource = model;
        emit("DATA(" + item.code + ") = io->bpc_model( " + literal(model) + " ).");
      } else if (command === "members") {
        id = name(); take("="); var dim = dimension(resource()), ids = "";
        if (peek() === "[") { value = expression(); ids = "ids = " + value.code; }
        var ref = fresh(); emit("DATA(" + ref + ") = " + dim + "->member_data( " + ids + " )."); dynamicTable(id,ref);
      } else if (command === "data") {
        id = name(); take("="); var source = name(), adapter;
        if (symbols[source]) { adapter = lookup(source,"model").code; }
        else { adapter = fresh(); emit("DATA(" + adapter + ") = io->bpc_model( " + literal(source) + " )."); }
        var filters = fresh(), limit = 100000;
        emit("DATA " + filters + " TYPE zcl_bn_bpc=>tt_filters.");
        if (peek() === "where") {
          take("where");
          do {
            var filter = name(); take("="); value = expression(2);
            if (value.kind !== "ids") { failure(line, "Filters require a member list, selection(...), or range(...)"); }
            emit("APPEND VALUE #( dimension = " + literal(filter) + " members = " + value.code + " ) TO " + filters + ".");
            if (peek() !== "and") { break; } take("and");
          } while (true);
        }
        if (peek() === "limit") {
          take("limit"); var max = take(); limit = Number(max.value);
          if (max.type !== "number" || !Number.isInteger(limit) || limit < 1 || limit > 1000000) { failure(line, "Limit must be an integer from 1 to 1000000"); }
        }
        ref = fresh(); emit("DATA(" + ref + ") = " + adapter + "->read_data( filters = " + filters + " max_rows = " + limit + " )."); dynamicTable(id,ref);
      } else if (command === "table") {
        item = declare(name(),"table"); emit("DATA " + item.code + " TYPE zcl_bn_context=>tt_rows.");
      } else if (command === "read") {
        id = name(); take("="); var dependency = take();
        if (dependency.type !== "text") { failure(line, "Dependency ID must be quoted"); }
        item = declare(id,"table"); emit("DATA(" + item.code + ") = io->read( " + literal(dependency.value) + " ).");
      } else if (command === "append") {
        item = lookup(name(),"table"); take("key"); take("="); var keyValue = expression(); take("amount"); take("="); value = expression();
        if (keyValue.kind !== "string" || value.kind !== "number") { failure(line, "append requires a text key and numeric amount"); }
        emit("APPEND VALUE #( key = " + keyValue.code + " amount = " + value.code + " ) TO " + item.code + ".");
      } else if (command === "let") {
        id = name(); take("="); value = expression();
        if (["number","string","boolean","ids"].indexOf(value.kind) < 0) { failure(line, "let requires a scalar or member list"); }
        item = declare(id,value.kind);
        emit("DATA(" + item.code + ") = " + value.code + ".");
      } else if (command === "for") {
        id = name(); take("in"); item = lookup(name(),"table");
        var row = declare(id,"row","<" + fresh() + ">");
        emit("FIELD-SYMBOLS " + row.code + " TYPE any."); emit("LOOP AT " + item.code + " ASSIGNING " + row.code + ".");
        blocks.push({kind:"for",id:id,line:line});
      } else if (command === "if") {
        value = expression(); emit("IF " + condition(value) + "."); blocks.push({kind:"if",line:line});
      } else if (command === "else") {
        var block = blocks[blocks.length - 1];
        if (!block || block.kind !== "if" || block.otherwise) { failure(line, "else requires an open if"); }
        block.otherwise = true; emit("ELSE.");
      } else if (command === "end") {
        block = blocks.pop(); if (!block) { failure(line, "No open loop or if"); }
        emit(block.kind === "for" ? "ENDLOOP." : "ENDIF."); if (block.id) { delete symbols[block.id]; }
      } else if (command === "show" || command === "emit") {
        item = lookup(name(),"table");
        if (command === "emit") { emit("io->emit( " + item.code + " )."); }
        else {
          take("as"); var label = take(); if (label.type !== "text") { failure(line, "Output name must be quoted"); }
          emit("io->emit_table( name = " + literal(label.value) + " rows = " + item.code + " ).");
        }
      } else if (command === "message") {
        value = expression();
        if (["number","string","boolean","field"].indexOf(value.kind) < 0) { failure(line, "message requires a scalar"); }
        emit("io->message( CONV string( " + value.code + " ) ).");
      } else if (symbols[command]) {
        item = lookup(command);
        if (peek() === ".") { take("."); item = field(lookup(command,"row"), name()); }
        take("="); value = expression();
        if (["field","number","string","boolean"].indexOf(item.kind) < 0 ||
          ["number","string","boolean","field"].indexOf(value.kind) < 0) { failure(line, "Assign scalar values only"); }
        if (item.kind !== "field" && item.kind !== value.kind) { failure(line, "Assignment changes the variable type"); }
        emit(item.code + " = " + value.code + ".");
      } else { failure(line, "Unknown statement " + command); }
      if (at !== parts.length) { failure(line, "Unexpected " + peek()); }
    });
    if (blocks.length) { failure(blocks[blocks.length-1].line, "Missing end"); }
    var bytes = new TextEncoder().encode(text), binary = "";
    bytes.forEach(function (b) { binary += String.fromCharCode(b); });
    var encoded = btoa(binary).match(/.{1,120}/g) || [""];
    var output = marker + encoded.map(function (s) { return "* @bn-source " + s; }).join("\n") +
      "\n* @bn-generated\n" + body.join("\n");
    if (output.length > 60000) { failure(1,"Generated cell exceeds the 60000-character SAP source limit"); }
    // Wrap only generated ABAP between tokens, never inside literals or author text.
    output = output.split("\n").map(function (s) {
      if (s.length <= 240 || s[0] === "*") { return s; }
      var quoted = false, start = 0, cut = -1, lines = [];
      for (var i = 0; i < s.length; i++) {
        if (s[i] === "`") { if (quoted && s[i+1] === "`") { i++; } else { quoted = !quoted; } }
        if (!quoted && s[i] === " ") { cut = i; }
        if (i-start >= 220 && cut > start) { lines.push(s.slice(start,cut)); start = cut+1; cut = -1; }
      }
      lines.push(s.slice(start)); return lines.join("\n");
    }).join("\n");
    if (output.length > 60000) { failure(1,"Generated cell exceeds the 60000-character SAP source limit"); }
    return output;
  }
  function unpack(source) {
    if (source.slice(0,marker.length) !== marker) { return {language:"abap",text:source}; }
    var end = source.indexOf("\n* @bn-generated\n"), encoded = "";
    if (end < 0) { return {language:"abap",text:source}; }
    var lines = source.slice(marker.length,end).split("\n");
    if (lines.some(function (s) { return !/^\* @bn-source [A-Za-z0-9+/=]*$/.test(s); })) { return {language:"abap",text:source}; }
    lines.forEach(function (s) { encoded += s.slice(13); });
    try {
      var binary = atob(encoded), bytes = Uint8Array.from(binary,function (s) { return s.charCodeAt(0); });
      var text = new TextDecoder("utf-8",{fatal:true}).decode(bytes);
      if (compile(text) === source) { return {language:"script",text:text}; }
    } catch (_) { /* Edited generated ABAP remains editable as ABAP. */ }
    return {language:"abap",text:source};
  }
  function sourceLine(source, generatedLine) {
    if (unpack(source).language !== "script") { return generatedLine; }
    var line = 1;
    source.split("\n").slice(0,generatedLine).forEach(function (s) {
      var match = s.match(/^\* @bn-line (\d+)$/); if (match) { line = Number(match[1]); }
    }); return line;
  }
  function prettyPrint(text) {
    compile(text); // Reject incomplete syntax before changing the author text.
    var depth = 0, eol = text.indexOf("\r\n") >= 0 ? "\r\n" : "\n";
    var formatted = text.split(/\r\n|\n/).map(function (line, index) {
      if (!line.trim()) { return line; }
      var parts = tokens(line,index+1), command = parts[0] && parts[0].value;
      if (command === "end" || command === "else") { depth--; }
      var result = "  ".repeat(depth) + line.replace(/^[ \t]*/,"");
      if (command === "for" || command === "if" || command === "else") { depth++; }
      return result;
    }).join(eol);
    compile(formatted);
    return formatted;
  }
  return {compile:compile,unpack:unpack,sourceLine:sourceLine,tokens:tokens,prettyPrint:prettyPrint};
});
