import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:thesis_lints/src/identifier_rule.dart';
import 'package:thesis_lints/src/property_rule.dart';
import 'package:thesis_lints/src/constructor_rule.dart';
import 'package:thesis_lints/src/methodcall_rule.dart';
import 'package:thesis_lints/src/staticmethodcall_rule.dart';
import 'package:thesis_lints/src/textfield_obscure_password_rule.dart';
import 'package:thesis_lints/src/webview_phishing_rule.dart';
import 'package:sqlite3/sqlite3.dart';

// these lints only detect that an API is used, not if the supplied arguments are dangerous in any way
final lints = [
  ConstructorRule(risk: 'Path Traversal', package: 'dart:io', type: 'File', constructor: "*"),
  MethodCallRule(risk: 'Path Traversal', package: 'dart:io', type: 'File', method: 'copy'),
  MethodCallRule(risk: 'Path Traversal', package: 'dart:io', type: 'File', method: 'copySync'),
  MethodCallRule(risk: 'Path Traversal', package: 'dart:io', type: 'File', method: 'rename'),
  MethodCallRule(risk: 'Path Traversal', package: 'dart:io', type: 'File', method: 'renameSync'),
  ConstructorRule(risk: 'Path Traversal', package: 'dart:io', type: 'Directory', constructor: "*"),
  MethodCallRule(risk: 'Path Traversal', package: 'dart:io', type: 'Directory', method: 'rename'),
  MethodCallRule(risk: 'Path Traversal', package: 'dart:io', type: 'Directory', method: 'renameSync'),
  MethodCallRule(risk: 'Path Traversal', package: 'dart:io', type: 'Directory', method: 'createTemp'),
  MethodCallRule(risk: 'Path Traversal', package: 'dart:io', type: 'Directory', method: 'createTempSync'),
  PropertyRule(risk: 'Zip Slip', package: 'archive', type: 'ArchiveFile', property: 'name'),
  StaticObjectRule(risk: 'Broken Crypto', package: 'crypto', type: 'Hash', identifier: 'md5'),
  StaticObjectRule(risk: 'Broken Crypto', package: 'crypto', type: 'Hash', identifier: 'sha1'),
  StaticObjectRule(risk: 'Broken Crypto', package: 'encrypt', type: 'AESMode', identifier: 'ecb'),
  StaticObjectRule(risk: 'Broken Crypto', package: 'encrypt', type: 'AESMode', identifier: 'cbc'),
  ConstructorRule(risk: 'Insecure Randomness', package: 'dart:math', type: 'Random'),
  MethodCallRule(risk: 'Cleartext Communications', package: 'dart:_http', type: 'WebSocket', method: 'connect'),
  MethodCallRule(risk: 'Cleartext Communications', package: 'web_socket_channel', type: 'WebSocketChannel', method: 'connect'),
  StaticMethodCallRule(risk: 'Plaintext HTTP', package: 'http', method: 'head'),
  StaticMethodCallRule(risk: 'Plaintext HTTP', package: 'http', method: 'get'),
  StaticMethodCallRule(risk: 'Plaintext HTTP', package: 'http', method: 'post'),
  StaticMethodCallRule(risk: 'Plaintext HTTP', package: 'http', method: 'put'),
  StaticMethodCallRule(risk: 'Plaintext HTTP', package: 'http', method: 'patch'),
  StaticMethodCallRule(risk: 'Plaintext HTTP', package: 'http', method: 'delete'),
  StaticMethodCallRule(risk: 'Plaintext HTTP', package: 'http', method: 'read'),
  StaticMethodCallRule(risk: 'Plaintext HTTP', package: 'http', method: 'readBytes'),
  ConstructorRule(risk: 'Plaintext HTTP', package: 'flutter', type: 'Image', constructor: 'network'),
  ConstructorRule(risk: 'Content Resolver', package: 'android_content_provider', type: 'AndroidContentResolver'),
  MethodCallRule(risk: 'Content Resolver', package: 'receive_intent', type: 'ReceiveIntent', method: 'setResult'), // for returning data to attackers
  ConstructorRule(risk: 'Implicit Intent', package: 'android_intent_plus', type: 'AndroidIntent'),
  ConstructorRule(risk: 'Insecure Broadcast Receiver', package: 'flutter_broadcasts', type: 'BroadcastReceiver'),
  MethodCallRule(risk: 'Intent Redirection', package: 'android_intent_plus', type: 'AndroidIntent', method: 'parseAndLaunch'),
  ConstructorRule(risk: 'Exported Activities', package: 'go_router', type: 'GoRouter'), // all routes defined here are exposed via intent extra route by default
  ConstructorRule(risk: 'Secure Clipboard Handling', package: 'flutter', type: 'TextField'),
  MethodCallRule(risk: 'SQL Injection', package: 'sqflite_common', type: 'DatabaseExecutor', method: 'execute'),
  MethodCallRule(risk: 'SQL Injection', package: 'sqflite_common', type: 'DatabaseExecutor', method: 'rawQuery'),
  MethodCallRule(risk: 'SQL Injection', package: 'sqflite_common', type: 'DatabaseExecutor', method: 'rawUpdate'),
  MethodCallRule(risk: 'SQL Injection', package: 'sqflite_common', type: 'DatabaseExecutor', method: 'rawInsert'),
  MethodCallRule(risk: 'SQL Injection', package: 'sqflite_common', type: 'DatabaseExecutor', method: 'rawDelete'),
  PropertyRule(risk: 'Unsafe HostnameVerifier', package: 'dart:_http', type: 'HttpClient', property: 'badCertificateCallback'), // dangerous code pattern
  MethodCallRule(risk: 'Webview Unsafe URL Loading', package: 'webview_flutter', type: 'WebViewController', method: 'loadRequest'),
  PropertyRule(risk: 'Unsafe use of deep links', package: 'go_router', type: 'GoRouterState', property: 'uri'),
  MethodCallRule(risk: 'Cross-App Scripting', package: 'webview_flutter', type: 'WebViewController', method: 'loadHtmlString'),
  MethodCallRule(risk: 'Cross-App Scripting', package: 'webview_flutter', type: 'WebViewController', method: 'runJavaScript'),
  MethodCallRule(risk: 'Cross-App Scripting', package: 'webview_flutter', type: 'WebViewController', method: 'runJavaScriptReturningResult'),
  MethodCallRule(risk: 'Cross-App Scripting', package: 'webview_flutter', type: 'WebViewController', method: 'setJavaScriptMode'),
  MethodCallRule(risk: 'WebView Native Bridges', package: 'webview_flutter', type: 'WebViewController', method: 'addJavaScriptChannel'),
  MethodCallRule(risk: 'Insecure Machine-to-Machine communication setup', package: 'flutter_blue_plus', type: 'BluetoothCharacteristic', method: 'read'),
  MethodCallRule(risk: 'Insecure Machine-to-Machine communication setup', package: 'flutter_blue_plus', type: 'BluetoothCharacteristic', method: 'write'),
  MethodCallRule(risk: 'SQL Injection', package: 'sqflite_common', type: 'DatabaseExecutor', method: 'query'),
  MethodCallRule(risk: 'SQL Injection', package: 'sqflite_common', type: 'DatabaseExecutor', method: 'update'),
  MethodCallRule(risk: 'SQL Injection', package: 'sqflite_common', type: 'DatabaseExecutor', method: 'insert'),
  MethodCallRule(risk: 'SQL Injection', package: 'sqflite_common', type: 'DatabaseExecutor', method: 'delete'),
  WebViewPhishingRule(), // dangerous code pattern
  TextFieldObscurePasswordRule(), // dangerous code pattern
  StaticMethodCallRule(risk: 'Sensitive Data Stored in External Storage', package: 'path_provider', method: 'getExternalStorageDirectory'),
  StaticMethodCallRule(risk: 'Sensitive Data Stored in External Storage', package: 'path_provider', method: 'getExternalStorageDirectories'),
  StaticMethodCallRule(risk: 'Sensitive Data Stored in External Storage', package: 'path_provider', method: 'getExternalCacheDirectories'),
  ConstructorRule(risk: 'Secure Clipboard Handling', package: 'flutter', type: 'TextFormField'),
];

PluginBase createPlugin() => _ThesisLint();

class _ThesisLint extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => lints;
}

void _exportLintsToSqlite(String filename) {
  final db = sqlite3.open(filename);
  final insert = db.prepare('INSERT INTO lint_rule (name) VALUES (?)', persistent: true);
  for (var lint in lints) {
    insert.execute([lint.code.name]);
  }
  insert.dispose();
  db.dispose();
}

void main(List<String> args) {
  if (args.length == 2 && args[0] == 'export') {
    _exportLintsToSqlite(args[1]);
    print('Please connect the APIs in the db to the corresponding lints manually.');
  } else {
    print('Export dart lint rules to sqlite: dart thesis_lints.dart export <sqlite.db>. To scan a project, use dart run custom_lint.');
  }
}