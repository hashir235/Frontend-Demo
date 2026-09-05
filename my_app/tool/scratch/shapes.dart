import "dart:convert"; import "dart:io";
import "package:my_app/features/formulas/model/formula_expression.dart";

void main() {
  final m = jsonDecode(File("assets/formulas/catalogue.json").readAsStringSync()) as Map<String,dynamic>;
  final f = (m["formulas"] as List).cast<String>();
  var fabEnvelope = 0, estEnvelope = 0;
  final odd = <String>[];

  for (final src in f) {
    final e = FormulaExpression.parse(src);
    final vars = e.variables;
    final hasFeet = vars.contains("feet");
    final margin = vars.where((v) => v == "cm" || v.startsWith("cm_")).toList();

    // Fabrication envelope: Divide( Plus(core, cm), feet )
    if (hasFeet && e is FormulaBinary && e.op == "/" &&
        e.right is FormulaVariable && (e.right as FormulaVariable).name == "feet" &&
        e.left is FormulaBinary && (e.left as FormulaBinary).op == "+" &&
        (e.left as FormulaBinary).right is FormulaVariable &&
        ((e.left as FormulaBinary).right as FormulaVariable).name == "cm") {
      fabEnvelope++;
      continue;
    }
    // Estimation envelope: Plus(core, cm_X)
    if (!hasFeet && margin.length == 1 && e is FormulaBinary && e.op == "+" &&
        e.right is FormulaVariable && (e.right as FormulaVariable).name == margin.first) {
      estEnvelope++;
      continue;
    }
    odd.add(src);
  }

  print("formulas               : ${f.length}");
  print("fabrication envelope   : $fabEnvelope   (core + cm) / feet");
  print("estimation envelope    : $estEnvelope   core + cm_SECTION");
  print("neither                : ${odd.length}");
  for (final o in odd) { print("    $o"); }
}
