# DEMREVID003 Script conversion

Work in progress on `codex/SSNG-3218-fixture-validation`.

The operational definition contains 21 visible Notebook Script stages. Complete native SAP working tables and retained metadata connect the stages; browser previews never supply calculation inputs. The business rules are in `cells/*.bns`, generated from the reviewed rules in `build.cjs`. There is no call to the model-specific allocation engine in the operational cells.

The native compiler and original-versus-Script checks must pass before this definition is offered as a replacement. Current blockers are recorded by `build-status.json`; an empty generated source means the cell has not compiled and the definition must not be uploaded.

`build-validation.cjs` constructs a separate nonposting validation notebook. Its fixture preparation and comparison cell use ABAP only to supply authorized complete inputs and call the original implementation as an independent oracle. Every operational stage remains Script. Comparison retains duplicate multiplicity and canonicalizes both complete tables by all dimensions and signed amount before exact ordered comparison.

Required checks: nonempty standard/fallback/rounding/negative/HSNS/connection carry fixtures, suppression on/off, zero clears for disappeared output records, then the known nonempty `Actual` / `2026.006` live input. Platform runtime checks alone do not prove calculation equivalence. Neither notebook publishes a financial posting result.
