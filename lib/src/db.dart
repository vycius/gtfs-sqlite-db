import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:gtfs_db/src/tables.dart';
import 'package:provider/provider.dart';

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

  static AppDatabase get(BuildContext context) {
    return Provider.of<AppDatabase>(
      context,
      listen: false,
    );
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON;');
          await customStatement('PRAGMA auto_vacuum = FULL;');
        },
      );
}
