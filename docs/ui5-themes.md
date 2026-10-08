# Standard UI5 themes

BPC Notebook boots the SAP-hosted UI5 distribution at `https://ui5.sap.com/1.120.41/resources/sap-ui-core.js` in both local and BSP deployments. The endpoint currently reports runtime 1.120.40. The application requires UI5 1.120 or newer; SAP NPL's installed 1.52.18 does not provide Horizon. This application-level bootstrap leaves the system UI5 installation unchanged and requires browser access to ui5.sap.com.

The default is SAP Evening Horizon (`sap_horizon_dark`). The Appearance selector also offers SAP Morning Horizon (`sap_horizon`). Both use SAP's supplied library themes. Standard controls own their typography, colors, borders, focus, selection and interaction states. The purple brand avatar uses the standard `Accent5` color. Buttons retain the theme's standard action colors.

The stylesheet contains layout rules and a monospace font for ABAP source only. Standard Panels provide cell and review surfaces, OverflowToolbars handle actions on narrow screens, and CustomListItems contain wrapping Text controls so full notebook names remain visible. The application continues to use its existing SAP backend, repository mappings and BSP pages.

SAP theme documentation: https://learning.sap.com/courses/learning-the-basics-of-sap-fiori/using-the-ui-theme-designer_e269f16a-7009-4467-9b6f-4d3dd689da32

Verification includes the deployed dark and light themes, 390px and desktop viewports, the existing application tests, and an actual abapGit import followed by SAP serialization and byte comparison. Theme screenshots are in `docs/evidence/horizon-dark.png` and `docs/evidence/horizon-light.png`.

Cell source uses the standard sap.ui.codeeditor.CodeEditor in ABAP mode with visible line numbers. SAP's editor highlights ABAP keywords, types, operators, strings, numeric literals and comments. Its default palette follows the application theme (Nord Dark in Evening Horizon and Tomorrow in Morning Horizon). Live edits update the notebook source and invalidate previous outputs; programmatic initialization does not mark the notebook as changed. Screenshots are in docs/evidence/abap-editor-dark.png and docs/evidence/abap-editor-light.png.
