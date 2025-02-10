import 'dart:math';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';
import 'package:path_provider/path_provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart';
import 'package:sqflite/sqflite.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/material.dart';

void rename(String a) async {
  var x = await openDatabase("");
  x.rawQuery("");
  getExternalCacheDirectories();
}

void getExternalCacheDirectories() async {
  (await getExternalStorageDirectory())?.path;
}

void get() {
  NavigationDelegate(
    onNavigationRequest: (request) => NavigationDecision.navigate, 
  ); 
  final shouldObscure = true;
  WebViewController().loadRequest(Uri.parse("https://www.google.com"));
  TextField(
    decoration: InputDecoration(
      //labelText: " Password aaa",
      //helperText: " Password aaa",
      hintText: "password",
    ),
  );
  TextFormField();
}
 
class Foo extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final a = " ";
    final client = super.createHttpClient(context)
      ..badCertificateCallback = (cert, host, port) => a.isEmpty;
    return client;
  }
}

void main() async {
  get();
}