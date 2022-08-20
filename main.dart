
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:gtfs_db/gtfs_db.dart';

import 'gtfs_import_service.dart';

void main() async {
  final regions = [
    _Region(
      id: 'vilnius',
      name: 'Vilnius',
      gtfsFile: 'gtfs/vilnius.zip',
      gtfsRealtimeUrl: 'https://api.allorigins.win/raw?url=https://www.stops.lt/vilnius/gtfs_realtime.pb',
    ),
    _Region(
      id: 'kaunas',
      name: 'Kaunas',
      gtfsFile: 'gtfs/kaunas.zip',
      gtfsRealtimeUrl: 'https://api.allorigins.win/raw?url=https://www.stops.lt/kaunas/gtfs_realtime_full.pb',
    ),
    _Region(
      id: 'klaipeda',
      name: 'Klaipėda',
      gtfsFile: 'gtfs/klaipeda.zip',
      gtfsRealtimeUrl: 'https://api.allorigins.win/raw?url=https://www.stops.lt/klaipeda/gtfs_realtime.pb',
    ),
    _Region(
      id: 'panevezys',
      name: 'Panevėžys',
      gtfsFile: 'gtfs/panevezys.zip',
      gtfsRealtimeUrl: 'https://api.allorigins.win/raw?url=https://www.stops.lt/panevezys/gtfs_realtime.pb',
    ),
    _Region(
      id: 'druskininkai',
      name: 'Druskininkai',
      gtfsFile: 'gtfs/druskininkai.zip',
      gtfsRealtimeUrl: null,
    ),
  ];

  await Directory('db').delete(recursive: true);

  for (final region in regions) {
    print('Loading ${region.name}');
    final bytes = await File(region.gtfsFile).readAsBytes();

    final connection = LazyDatabase(() {
      final file = File('db/${region.id}.sqlite');
      return NativeDatabase(file);
    });

    final db = AppDatabase(connection);

    await GTFSImportService().importRegionGTFS(
      bytes,
      db,
      region.gtfsRealtimeUrl,
    );

    await db.close();
  }
}

class _Region {
  final String id;
  final String name;
  final String gtfsFile;
  final String? gtfsRealtimeUrl;

  _Region({
    required this.id,
    required this.name,
    required this.gtfsFile,
    required this.gtfsRealtimeUrl,
  });
}
