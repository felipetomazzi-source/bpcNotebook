sap.ui.define([], function () {
  "use strict";
  var client = new URLSearchParams(window.location.search).get("sap-client");
  var local = !/^\/sap\//.test(window.location.pathname);
  var base = local ? "/api" : "/sap/bc/zbpc_notebook";
  function normalize(value) {
    if (!value || typeof value !== "object") {
      return value;
    }
    if (value.output && !value.output.runId) {
      value.output = null;
    }
    if (Array.isArray(value.inputs)) {
      value.inputs.forEach(function (p) {
        if (p.type === "number") {
          p.value = Number(p.value);
        }
        if (p.type === "boolean") {
          p.value = p.value === true || p.value === "true" || p.value === "X";
        }
      });
    }
    Object.keys(value).forEach(function (key) {
      if (key !== "inputs") {
        normalize(value[key]);
      }
    });
    return value;
  }
  function request(path, method, data) {
    method = method || "GET";
    var headers = { Accept: "application/json", "Content-Type": "application/json", "X-BPC-Notebook": "1" };
    var suffix = client
      ? (path.indexOf("?") >= 0 ? "&" : "?") + "sap-client=" + encodeURIComponent(client)
      : "";
    return fetch(base + path + suffix, {
      method: method,
      credentials: "same-origin",
      headers: headers,
      body: data ? JSON.stringify(data) : undefined,
    }).then(function (r) {
      return r.json().then(function (value) {
        if (!r.ok) {
          throw new Error(value.code + ": " + value.message);
        }
        return normalize(value);
      });
    });
  }
  return {
    local: local,
    key: function () {
      var bytes = new Uint8Array(16);
      window.crypto.getRandomValues(bytes);
      return Array.prototype.map
        .call(bytes, function (b) {
          return ("0" + b.toString(16)).slice(-2);
        })
        .join("");
    },
    init: function () {
      // Writes require a custom header; SAP handler rejects foreign Origin and exposes no CORS.
      return Promise.resolve();
    },
    request: request,
  };
});
