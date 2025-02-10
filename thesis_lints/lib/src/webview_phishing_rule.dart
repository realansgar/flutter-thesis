import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

class WebViewPhishingRule extends DartLintRule {
  final TypeChecker _navigationDelegateChecker;
  final TypeChecker _webviewControllerChecker;
  WebViewPhishingRule()
      : _navigationDelegateChecker = TypeChecker.fromName("NavigationDelegate", packageName: 'webview_flutter'),
        _webviewControllerChecker = TypeChecker.fromName("WebViewController", packageName: 'webview_flutter'),
        super(
          code: LintCode(
            name: "webview_phishing",
            problemMessage: "Webview Phishing: loadRequest without setting an onNavigationRequest callback to check navigations inside the webview.",
            errorSeverity: ErrorSeverity.ERROR,
          ),
        );
  @override
  void run(CustomLintResolver resolver, ErrorReporter reporter, CustomLintContext context) async {
    bool onNavigationRequestFound = false;
    List<MethodInvocation> loadRequestInvocations = [];
    context.registry.addMethodInvocation((node) {
      final methodElement = node.methodName.staticElement;
      final typeElement = methodElement?.enclosingElement3;
      if (typeElement == null) return;
      if (!_webviewControllerChecker.isExactly(typeElement)) return;
      if (methodElement?.name != "loadRequest") return;
      loadRequestInvocations.add(node);
    });
    context.registry.addNamedExpression((node) {
      final parameterElement = node.staticParameterElement;
      if (parameterElement == null) return;
      if (parameterElement.name != "onNavigationRequest") return;
      final parentElement = parameterElement.enclosingElement3;
      if (parentElement is! ConstructorElement) return;
      if (!_navigationDelegateChecker.isExactly(parentElement.enclosingElement3)) return;
      onNavigationRequestFound = true;
    });
    context.addPostRunCallback(() {
      if (onNavigationRequestFound) return;
      for (final invocation in loadRequestInvocations) {
        reporter.atNode(invocation, code);
      }
    });
  }
}
