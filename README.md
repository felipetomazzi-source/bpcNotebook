# bpcNotebook

A standalone SAPUI5 notebook for ABAP calculations with versioned source, typed inputs, explicit dependencies, frozen runs and persisted output previews.

```powershell
npm start
# Open http://127.0.0.1:4173 → Open allocation demo → Run all
npm test
npm run pack:sap
```

The local service **simulates two demo cell bodies**. The SAP DEV version is deployed on the connected ABAP system, client **001**, with access enabled for **DEVELOPER**. The browser allocation demo completed as a real SAP background job and produced CC100 = **66,000**. Code was pushed to `main` and pulled through SAP abapGit using transport `NPLK900126`. All **38** repository artifacts pass actual SAP import/serialization comparison. Automated dangerous ABAP Unit tests remain blocked by the client risk policy. Production execution remains blocked.

[Open the deployed SAP notebook](http://vhcalnplci:8000/sap/bc/ui5_ui5/sap/zbpc_notebook/index.html?sap-client=001). Log in as DEVELOPER, choose **Open allocation demo**, then **Run all** and select **allocate**.

- [Design and runtime contract](docs/DESIGN.md)
- [Installation and remaining production requirements](docs/INSTALL.md)
- [API contract](docs/API.md)
- [Native activation/test evidence](docs/evidence/native-check.json)
- [Encoding conventions and SAP round-trip evidence](docs/evidence/ENCODING.md)

Package/BSP: `ZBPC_NOTEBOOK`. API: `/sap/bc/zbpc_notebook`. URL: `/sap/bc/ui5_ui5/sap/zbpc_notebook/index.html?sap-client=<client>`. BPCIO tile integration is documented; adjacent repositories were not modified.
