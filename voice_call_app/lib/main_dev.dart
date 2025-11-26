import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sun_internet_call_app/main.dart' show SunInternetCallApp;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: "assets/env/.env.dev");

  runApp(const SunInternetCallApp());
}
