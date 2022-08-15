import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:gtfs_db/src/gtfs_service.dart';
import 'package:gtfs_db/gtfs_db.dart';
import 'package:test/test.dart';

void main() {
  group('Decoding proto data', () {
    test('Decode Vilnius proto data without error', () async {
      print('Hello');
      final bytes = await File('test/vilnius.zip').readAsBytes();


      // if (file.existsSync()) {
      //   file.deleteSync();
      // }

      final connection = LazyDatabase(() {
        final file = File('db-vilnius.sqlite');
        return NativeDatabase(file);
      });

      final db = AppDatabase(connection);

      await GTFSImportService().importRegionGTFS(
        bytes,
        db,
        'https://www.stops.lt/vilnius/gtfs_realtime.pb',
      );
    });
  });
}
