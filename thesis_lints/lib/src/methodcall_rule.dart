import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

class MethodCallRule extends DartLintRule {
  final String package;
  final String type;
  final String method;
  final TypeChecker _typeChecker;
  MethodCallRule({required String risk, required this.package, required this.type, required this.method})
      : _typeChecker = TypeChecker.fromName(type, packageName: package),
        super(
          code: LintCode(
            name: "method_${package}_${type}_${method}",
            problemMessage: "$risk: $package $type.$method()",
            errorSeverity: ErrorSeverity.ERROR,
          ),
        );
  @override
  void run(CustomLintResolver resolver, ErrorReporter reporter, CustomLintContext context) async {
    context.registry.addMethodInvocation((node) {
      final methodElement = node.methodName.staticElement;
      final typeElement = methodElement?.enclosingElement3;
      if (typeElement == null) return;
      if (!_typeChecker.isExactly(typeElement)) return;
      if (methodElement?.name != method) return;
      reporter.atNode(node, code);
    });
    // Function that should be invoked can come from an arbitrary expression = FuntionExpressionInvocation.
    // Currently not detected, as analyzer does not statically compute FunctionElement and it would require evaluating arbitrary expressions to maybe get a function element that can be known statically.
    // (Random().nextBool() ? foo.bar : foo.baz)();
  }
}
