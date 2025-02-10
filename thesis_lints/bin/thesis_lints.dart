
import 'package:thesis_lints/thesis_lints.dart';

void main() {
  var lint_names = lints.map((lint) => lint.code.name);
  print(lint_names);
}