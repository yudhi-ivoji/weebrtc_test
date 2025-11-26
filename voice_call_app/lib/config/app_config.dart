import 'package:flutter_dotenv/flutter_dotenv.dart' show dotenv;

class AppConfig {
  static final AppConfig _instance = AppConfig._internal();

  factory AppConfig() => _instance;

  AppConfig._internal();

  String get serverUrl => dotenv.env['SERVER_URL'] ?? '';
  String get appTitle => dotenv.env['APP_TITLE'] ?? 'SUN Voice';
  String get flavor => dotenv.env['FLAVOR'] ?? 'dev';

  // WebRTC
  String get stunUrl => dotenv.env['STUN_URL'] ?? '';
  String get turnUrl => dotenv.env['TURN_URL'] ?? '';
  String get turnUsername => dotenv.env['TURN_USERNAME'] ?? '';
  String get turnPassword => dotenv.env['TURN_PASSWORD'] ?? '';
}
