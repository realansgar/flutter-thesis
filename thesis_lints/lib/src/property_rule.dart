import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

class PropertyRule extends DartLintRule {
  final String package;
  final String type;
  final String property;
  final TypeChecker _typeChecker;
  PropertyRule({required String risk, required this.package, required this.type, required this.property})
      : _typeChecker = TypeChecker.fromName(type, packageName: package),
        super(
          code: LintCode(
            name: "property_${package}_${type}_$property",
            problemMessage: "$risk: $package $type.$property",
            errorSeverity: ErrorSeverity.ERROR,
          ),
        );
  @override
  void run(CustomLintResolver resolver, ErrorReporter reporter, CustomLintContext context) async {
    context.registry.addPropertyAccess((node) {
      final typeElement = node.realTarget.staticType?.element;
      if (typeElement == null) return;
      if (!_typeChecker.isExactly(typeElement)) return;
      if (node.propertyName.staticElement == null && node.propertyName.name == property ||
          node.propertyName.staticElement?.name == property) {
        reporter.atNode(node, code);
      }
    });
    context.registry.addPrefixedIdentifier((node) {
      final typeElement = node.prefix.staticType?.element;
      if (typeElement == null) return;
      if (!_typeChecker.isExactly(typeElement)) return;
      if (node.identifier.staticElement == null && node.identifier.name == property ||
          node.identifier.staticElement?.name == property) {
        reporter.atNode(node, code);
      }
    });
    // Dart has destructuring of Objects inside arbitrarily nested DartPatterns using an ObjectPattern. Currently not detected
    // var Foo(:bar) = Foo(bar: 'x');
    // bar == 'x';
  }
}
