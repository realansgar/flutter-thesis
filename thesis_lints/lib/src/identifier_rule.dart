import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

class StaticObjectRule extends DartLintRule {
  final String package;
  final String type;
  final String identifier;
  final TypeChecker _typeChecker;
  final TypeChecker _libaryChecker;
  StaticObjectRule({required String risk, required this.package, required this.type, required this.identifier})
      : _typeChecker = TypeChecker.fromName(type, packageName: package),
        _libaryChecker = TypeChecker.fromPackage(package),
        super(
          code: LintCode(
            name: "staticobject_${package}_${type}_$identifier",
            problemMessage: "$risk: $package $type $identifier",
            errorSeverity: ErrorSeverity.ERROR,
          ),
        );
  @override
  void run(CustomLintResolver resolver, ErrorReporter reporter, CustomLintContext context) async {
    context.registry.addSimpleIdentifier((node) {
      final typeElement = node.staticType?.element;
      final element = node.staticElement;
      if (typeElement == null || element == null) return;
      if (!_typeChecker.isExactly(typeElement)) return;
      // object referenced by identifier should actually come from library, not just happen to match type&name
      if (!_libaryChecker.isExactly(element)) return;
      if (node.staticElement?.name != identifier) return;
      reporter.atNode(node, code);
    });
  }
}
