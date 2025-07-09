// Stub implementation for non-web platforms
import 'dart:typed_data';

// Mock classes for non-web platforms
class Storage {
  final Map<String, String> _storage = {};

  String? operator [](String key) => _storage[key];
  void operator []=(String key, String value) => _storage[key] = value;
  void remove(String key) => _storage.remove(key);
}

class Blob {
  Blob(List<Uint8List> data, String mimeType);
}

class Url {
  static String createObjectUrl(Blob blob) => '';
  static void revokeObjectUrl(String url) {}
}

class Window {
  final Storage localStorage = Storage();
}

final window = Window();
