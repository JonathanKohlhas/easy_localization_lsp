import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:easy_localization_lsp/analysis/translation_call.dart';

class TranslationVisitor extends GeneralizingAstVisitor<void> {
  List<MethodInvocation> list = [];

  @override
  visitExpression(Expression node) {
    super.visitExpression(node);
    if (node
        case MethodInvocation(
          methodName: SimpleIdentifier(name: "tr" || "plural"),
          target: SimpleStringLiteral(),
          // TODO(JonathanKohlhas): What about string interpolation?
        )) {
      list.add(node);
    }
  }
}
