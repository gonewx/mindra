import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mindra/core/database/database_helper.dart';

void main() {
  group('Database Tests', () {
    setUpAll(() async {
      // Initialize FFI
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    test('Database initialization should work', () async {
      final db = await DatabaseHelper.database;
      expect(db, isNotNull);
      expect(db.isOpen, isTrue);
    });

    test('Media items table should exist', () async {
      final db = await DatabaseHelper.database;
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='media_items'",
      );
      expect(tables.isNotEmpty, isTrue);
    });

    test('Should be able to insert and retrieve media items', () async {
      final testItem = {
        'id': 'test-id-1',
        'title': 'Test Media',
        'description': 'Test Description',
        'file_path': '/test/path.mp3',
        'type': 'audio',
        'category': '测试',
        'duration': 300,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'play_count': 0,
        'is_favorite': 0,
      };

      // Insert test item
      await DatabaseHelper.insertMediaItem(testItem);

      // Retrieve items
      final items = await DatabaseHelper.getMediaItems();
      expect(items.isNotEmpty, isTrue);
      expect(items.any((item) => item['id'] == 'test-id-1'), isTrue);
    });

    tearDownAll(() async {
      await DatabaseHelper.clearAllData();
      await DatabaseHelper.closeDatabase();
    });
  });
}