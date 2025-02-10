import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:collection/collection.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

T? _getParameterExpression<T extends Expression>(InstanceCreationExpression node, String parameterName) {
  final expression = node.argumentList.arguments
      .whereType<NamedExpression>()
      .firstWhereOrNull((element) => element.staticParameterElement?.name == parameterName)
      ?.expression;
  if (expression is T) return expression;
  return null;
}

class TextFieldObscurePasswordRule extends DartLintRule {
  final TypeChecker _textFieldChecker;
  final TypeChecker _textFormFieldChecker;
  TextFieldObscurePasswordRule()
      : _textFieldChecker = TypeChecker.fromName("TextField", packageName: 'flutter'),
        _textFormFieldChecker = TypeChecker.fromName("TextFormField", packageName: 'flutter'),
        super(
          code: LintCode(
            name: "textfield_obscure_password",
            problemMessage: "TextField Obscure Password: Passwords should be obscured to prevent copying and potential leakage to unauthorized apps.",
            errorSeverity: ErrorSeverity.ERROR,
          ),
        );
  @override
  void run(CustomLintResolver resolver, ErrorReporter reporter, CustomLintContext context) async {
    context.registry.addInstanceCreationExpression((node) {
      final typeElement = node.staticType?.element;
      if (typeElement == null) return;
      if (!(_textFieldChecker.isExactly(typeElement) || _textFormFieldChecker.isExactly(typeElement))) return;
      final decorationInstanceCreation = _getParameterExpression<InstanceCreationExpression>(node, "decoration");
      if (decorationInstanceCreation == null) return;
      final labelText = _getParameterExpression<StringLiteral>(decorationInstanceCreation, "labelText");
      final hintText = _getParameterExpression<StringLiteral>(decorationInstanceCreation, "hintText");
      final helperText = _getParameterExpression<StringLiteral>(decorationInstanceCreation, "helperText");
      if (![labelText, hintText, helperText].any((e) => e?.stringValue?.toLowerCase().contains("password") ?? false)) return;
      final obscureText = _getParameterExpression(node, "obscureText");
      if (obscureText != null && obscureText is! BooleanLiteral) return;
      if (obscureText == null || (obscureText as BooleanLiteral).value == false) {
        reporter.atNode(node, code);
      }
    });
  }
}
