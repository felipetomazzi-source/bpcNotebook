# bpcNotebook

A standalone SAPUI5 notebook for ABAP calculations with versioned source, typed inputs, explicit dependencies, frozen runs and persisted output previews.

```powershell
npm start
# Open http://127.0.0.1:4173 → Open allocation demo → Run all
npm test
npm run pack:sap
```

The local service **simulates two demo cell bodies**. Edited ABAP requires SAP. Native tables, service classes and the worker report were activated on **ABAP 7.52 SP04** in `$TMP`; native compiler/runtime-contract tests pass. **Background integration is not yet proven**: the client's ABAP Unit risk policy blocks background tests. The real SAP abapGit round trip passes for all 37 repository artifacts, including BSP/ICF and repository configuration. Transportable package installation, browser acceptance and trusted-user enablement remain. Production execution is blocked.

- [Design and runtime contract](docs/DESIGN.md)
- [Installation and remaining production requirements](docs/INSTALL.md)
- [API contract](docs/API.md)
- [Native activation/test evidence](docs/evidence/native-check.json)
- [Encoding conventions and SAP round-trip evidence](docs/evidence/ENCODING.md)

Package/BSP: `ZBPC_NOTEBOOK`. API: `/sap/bc/zbpc_notebook`. URL: `/sap/bc/ui5_ui5/sap/zbpc_notebook/index.html?sap-client=<client>`. BPCIO tile integration is documented; adjacent repositories were not modified.
