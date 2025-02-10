import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

class StaticMethodCallRule extends DartLintRule {
  final String package;
  final String method;
  final TypeChecker _typeChecker;
  StaticMethodCallRule({required String risk, required this.package, required this.method})
      : _typeChecker = TypeChecker.fromPackage(package),
        super(
          code: LintCode(
            name: "method_${package}_${method}",
            problemMessage: "$risk: $package $method()",
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
      final x = "abcdeasdkhaskdgasdaskjdgvjsavdjkasvdjkvsajdvasjdgvaskjvf" ??
          "ghildknsbdljsbfjsdbfjbdsjfbdslfbdsbfdskhfbdsjbfkjdsbfjbjkl";
    });
    // Function that should be invoked can come from an arbitrary expression = FuntionExpressionInvocation.
    // Currently not detected, as analyzer does not statically compute FunctionElement and it would require evaluating arbitrary expressions to maybe get a function element that can be known statically.
    // (Random().nextBool() ? foo.bar : foo.baz)();
  }
}
