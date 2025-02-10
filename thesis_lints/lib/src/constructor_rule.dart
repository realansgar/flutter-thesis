import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

class ConstructorRule extends DartLintRule {
  final String package;
  final String type;
  final String? constructor;
  final TypeChecker _typeChecker;
  ConstructorRule({required String risk, required this.package, required this.type, this.constructor})
      : _typeChecker = TypeChecker.fromName(type, packageName: package),
        super(
          code: LintCode(
            name: "constructor_${package}_$type${constructor != null ? "_$constructor" : ""}",
            problemMessage: "$risk: $package new $type${constructor != null ? ".$constructor" : ""}()",
            errorSeverity: ErrorSeverity.ERROR,
          ),
        );
  @override
  void run(CustomLintResolver resolver, ErrorReporter reporter, CustomLintContext context) async {
    context.registry.addInstanceCreationExpression((node) {
      final typeElement = node.staticType?.element;
      if (typeElement == null) return;
      if (!_typeChecker.isExactly(typeElement)) return;
      if (constructor != "*" && constructor != node.constructorName.name?.staticElement?.name) return;
      reporter.atNode(node, code);
    });
  }
}
