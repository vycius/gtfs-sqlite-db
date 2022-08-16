import 'package:drift/drift.dart';
import 'package:gtfs_db/src/tables.dart';

part 'db.g.dart';

@DriftDatabase(
  tables: [
    FeedInfo,
    Agency,
    Stops,
    TransitRoutes,
    Calendar,
    Trips,
    StopTimes,
    Shapes,
    CalendarDates,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (_) async {
          await customStatement('PRAGMA foreign_keys = ON;');
          await customStatement('PRAGMA auto_vacuum = FULL;');
        },
        onCreate: (m) async {
          await m.createAll();
          await m.createIndex(
            Index(
              'trips_route_id_index',
              'CREATE INDEX trips_route_id_index ON ${trips.route_id.tableName} (${trips.route_id.name})',
            ),
          );
          await m.createIndex(
            Index(
              'trips_service_id_index',
              'CREATE INDEX trips_service_id_index ON ${trips.service_id.tableName} (${trips.service_id.name})',
            ),
          );
          await m.createIndex(
            Index(
              'stop_times_trip_id_index',
              'CREATE INDEX stop_times_trip_id_index ON ${stopTimes.trip_id.tableName} (${stopTimes.trip_id.name})',
            ),
          );
          await m.createIndex(
            Index(
              'stop_times_stop_id_index',
              'CREATE INDEX stop_times_stop_id_index ON ${stopTimes.stop_id.tableName} (${stopTimes.stop_id.name})',
            ),
          );
        },
      );
}
