import 'dart:io';
import 'package:flutter/foundation.dart';

class APIConfig {
  static String get baseUrl {
    if (kIsWeb) {
      // Navegador
      return 'http://localhost:5000';
    } else if (Platform.isAndroid) {
      // Emulador Android
      return 'http://10.0.2.2:5000';
    } else if (Platform.isIOS) {
      return 'http://localhost:5000';
    } else if (Platform.isWindows) {
      return 'http://localhost:5000';
    } else {
      // Dispositivo físico
      return 'http://192.168.1.10:5000';
    }
  }
}
