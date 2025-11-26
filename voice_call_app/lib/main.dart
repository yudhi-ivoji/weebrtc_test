import 'package:flutter/material.dart';

import 'config/app_config.dart';
import 'pages/voice_call_page.dart';

class SunInternetCallApp extends StatelessWidget {
  const SunInternetCallApp({super.key});

  @override
  Widget build(BuildContext context) {
    final config = AppConfig();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: config.appTitle,
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const VoiceCallPage(),
    );
  }
}
