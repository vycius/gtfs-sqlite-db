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
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON;');
        },
      );
}
