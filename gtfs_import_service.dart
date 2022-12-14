import 'dart:convert';

import 'package:archive/archive_io.dart';
import 'package:csv/csv.dart';
import 'package:drift/drift.dart';
import 'package:gtfs_db/gtfs_db.dart';

class _CsvRowValues {
  final Map<String, int> headerIndexLookup;
  final List<String> row;

  _CsvRowValues({required this.headerIndexLookup, required this.row});

  T _parseValue<T>(String value) {
    switch (T) {
      case String:
        return value as T;
      case int:
        return int.parse(value) as T;
      case double:
        return double.parse(value) as T;
      case bool:
        return (value == '1') as T;
    }

    throw ArgumentError.value(
      value,
      'Unable to map to type $T',
    );
  }

  T getRequiredValue<T>(String name) {
    final index = headerIndexLookup[name];
    if (index == null) {
      throw ArgumentError.notNull(name);
    }

    final value = row[index];
    if (value.trim() == '') {
      throw ArgumentError.value(
        value,
        '$name can not be empty, because it is required',
      );
    }

    return _parseValue<T>(value);
  }

  Value<T?> getValue<T>(String name) {
    final index = headerIndexLookup[name];
    if (index == null) {
      return const Value.absent();
    }

    final value = row[index];
    if (value.trim() == '') {
      return const Value.absent();
    }

    return Value.ofNullable(_parseValue<T>(value));
  }
}

class GTFSImportService {
  Future<void> importRegionGTFS(
    List<int> bytes,
    AppDatabase appDatabase,
    String? gtfsRealtimeUrl,
  ) {
    final archive = ZipDecoder().decodeBytes(
      bytes,
      verify: true,
    );
    return GTFSImportService().insertGTFSArchive(
      archive,
      appDatabase,
      gtfsRealtimeUrl,
    );
  }

  Future<void> insertGTFSArchive(
    Archive archive,
    AppDatabase appDatabase,
    String? gtfsRealtimeUrl,
  ) async {
    await _insertFeedInfo(appDatabase, gtfsRealtimeUrl);
    await _insertAgency(archive, appDatabase);
    await _insertStops(archive, appDatabase);
    await _insertRoutes(archive, appDatabase);
    await _insertCalendar(archive, appDatabase);
    await _insertShapes(archive, appDatabase);
    await _insertCalendarDates(archive, appDatabase);
    await _insertTrips(archive, appDatabase);
    await _insertStopTimes(archive, appDatabase);

    await appDatabase.customStatement('PRAGMA optimize;');
    await appDatabase.customStatement('VACUUM;');
  }

  Iterable<T> _mapFileRowsToInserts<T>(
    Archive archive,
    String fileName,
    T Function(_CsvRowValues rowValues) insertMapper, {
    bool isRequired = true,
  }) {
    final file = archive.findFile(fileName);

    if (file == null) {
      if (isRequired) {
        throw ArgumentError.notNull('$fileName is required in GTFS file');
      } else {
        return [];
      }
    }

    final bytes = file.content as List<int>;
    final data = utf8.decode(bytes);

    final rowsAsListOfValues =
        const CsvToListConverter(eol: '\n', shouldParseNumbers: false)
            .convert(data)
            .map((l) => List<String>.from(l));

    final Map<String, int> headerIndexLookup = rowsAsListOfValues.first
        .asMap()
        .map((key, value) => MapEntry(value, key));

    return rowsAsListOfValues.skip(1).map(
      (r) {
        final rowValues = _CsvRowValues(
          headerIndexLookup: headerIndexLookup,
          row: r,
        );

        return insertMapper(rowValues);
      },
    );
  }

  Future<void> _insertAgency(
    Archive archive,
    AppDatabase appDatabase,
  ) {
    final agencyInserts = _mapFileRowsToInserts(
      archive,
      'agency.txt',
      (rowValues) {
        return AgencyCompanion.insert(
          agency_id: rowValues.getRequiredValue('agency_id'),
          agency_name: rowValues.getRequiredValue('agency_name'),
          agency_url: rowValues.getRequiredValue('agency_url'),
          agency_timezone: rowValues.getRequiredValue('agency_timezone'),
          agency_lang: rowValues.getValue('agency_lang'),
          agency_phone: rowValues.getValue('agency_phone'),
          agency_fare_url: rowValues.getValue('agency_fare_url'),
          agency_email: rowValues.getValue('agency_email'),
        );
      },
    );

    return appDatabase.batch((batch) {
      batch.insertAll(appDatabase.agency, agencyInserts);
    });
  }

  Future<void> _insertFeedInfo(
    AppDatabase appDatabase,
    String? gtfsRealtimeUrl,
  ) {
    final feedInfoInserts = [
      FeedInfoCompanion.insert(
        feed_publisher_name: 'Stops.lt',
        feed_publisher_url: 'https://www.stops.lt/',
        feed_lang: 'lit',
        default_lang: Value('lit'),
        agency_gtfs_realtime_url: Value(gtfsRealtimeUrl),
      ),
    ];

    return appDatabase.batch((batch) {
      batch.insertAll(appDatabase.feedInfo, feedInfoInserts);
    });
  }

  Future<void> _insertStops(Archive archive, AppDatabase appDatabase) {
    final stopInserts = _mapFileRowsToInserts(
      archive,
      'stops.txt',
      (rowValues) {
        return StopsCompanion.insert(
          stop_id: rowValues.getRequiredValue('stop_id'),
          stop_code: rowValues.getValue('stop_code'),
          stop_name: rowValues.getRequiredValue('stop_name'),
          stop_desc: rowValues.getValue('stop_desc'),
          stop_lat: rowValues.getRequiredValue('stop_lat'),
          stop_lon: rowValues.getRequiredValue('stop_lon'),
          zone_id: rowValues.getValue('zone_id'),
          stop_url: rowValues.getValue('stop_url'),
          location_type: rowValues.getValue('location_type'),
          parent_station: rowValues.getValue('parent_station'),
          stop_timezone: rowValues.getValue('stop_timezone'),
          wheelchair_boarding: rowValues.getValue('wheelchair_boarding'),
          level_id: rowValues.getValue('level_id'),
          platform_code: rowValues.getValue('platform_code'),
        );
      },
    );

    return appDatabase.batch((batch) {
      batch.insertAll(appDatabase.stops, stopInserts);
    });
  }

  Future<void> _insertRoutes(Archive archive, AppDatabase appDatabase) {
    final stopInserts = _mapFileRowsToInserts(
      archive,
      'routes.txt',
      (rowValues) {
        return TransitRoutesCompanion.insert(
          route_id: rowValues.getRequiredValue('route_id'),
          agency_id: rowValues.getValue('agency_id'),
          route_short_name: rowValues.getValue('route_short_name'),
          route_long_name: rowValues.getRequiredValue('route_long_name'),
          route_desc: rowValues.getValue('route_desc'),
          route_type: rowValues.getRequiredValue('route_type'),
          route_url: rowValues.getValue('route_url'),
          route_color: rowValues.getValue('route_color'),
          route_text_color: rowValues.getValue('route_text_color'),
          route_sort_order: rowValues.getValue('route_sort_order'),
        );
      },
    );

    return appDatabase.batch((batch) {
      batch.insertAll(appDatabase.transitRoutes, stopInserts);
    });
  }

  Future<void> _insertCalendar(Archive archive, AppDatabase appDatabase) {
    final calendarInserts = _mapFileRowsToInserts(
      archive,
      'calendar.txt',
      (rowValues) {
        return CalendarCompanion.insert(
          service_id: rowValues.getRequiredValue('service_id'),
          monday: rowValues.getRequiredValue('monday'),
          tuesday: rowValues.getRequiredValue('tuesday'),
          wednesday: rowValues.getRequiredValue('wednesday'),
          thursday: rowValues.getRequiredValue('thursday'),
          friday: rowValues.getRequiredValue('friday'),
          saturday: rowValues.getRequiredValue('saturday'),
          sunday: rowValues.getRequiredValue('sunday'),
          start_date: rowValues.getRequiredValue('start_date'),
          end_date: rowValues.getRequiredValue('end_date'),
        );
      },
    );

    return appDatabase.batch((batch) {
      batch.insertAll(appDatabase.calendar, calendarInserts);
    });
  }

  Future<void> _insertTrips(Archive archive, AppDatabase appDatabase) {
    final tripsInserts = _mapFileRowsToInserts(
      archive,
      'trips.txt',
      (rowValues) {
        return TripsCompanion.insert(
          route_id: rowValues.getRequiredValue('route_id'),
          service_id: rowValues.getRequiredValue('service_id'),
          trip_id: rowValues.getRequiredValue('trip_id'),
          trip_headsign: rowValues.getValue('trip_headsign'),
          trip_short_name: rowValues.getValue('trip_short_name'),
          direction_id: rowValues.getValue('direction_id'),
          block_id: rowValues.getValue('block_id'),
          shape_id: rowValues.getRequiredValue('shape_id'),
          wheelchair_accessible: rowValues.getValue('wheelchair_accessible'),
          bikes_allowed: rowValues.getValue('bikes_allowed'),
        );
      },
    );

    return appDatabase.batch((batch) {
      batch.insertAll(appDatabase.trips, tripsInserts);
    });
  }

  Future<void> _insertShapes(Archive archive, AppDatabase appDatabase) {
    final tripsInserts = _mapFileRowsToInserts(
      archive,
      'shapes.txt',
      (rowValues) {
        return ShapesCompanion.insert(
          shape_id: rowValues.getRequiredValue('shape_id'),
          shape_pt_lat: rowValues.getRequiredValue('shape_pt_lat'),
          shape_pt_lon: rowValues.getRequiredValue('shape_pt_lon'),
          shape_pt_sequence: rowValues.getRequiredValue('shape_pt_sequence'),
          shape_dist_traveled: rowValues.getValue('shape_dist_traveled'),
        );
      },
    );

    return appDatabase.batch((batch) {
      batch.insertAll(appDatabase.shapes, tripsInserts);
    });
  }

  Future<void> _insertStopTimes(
    Archive archive,
    AppDatabase appDatabase,
  ) {
    final tripsInserts = _mapFileRowsToInserts(
      archive,
      'stop_times.txt',
      (rowValues) {
        return StopTimesCompanion.insert(
          trip_id: rowValues.getRequiredValue('trip_id'),
          arrival_time: rowValues.getRequiredValue('arrival_time'),
          departure_time: rowValues.getRequiredValue('departure_time'),
          stop_id: rowValues.getRequiredValue('stop_id'),
          stop_sequence: rowValues.getRequiredValue('stop_sequence'),
          stop_headsign: rowValues.getValue('stop_headsign'),
          pickup_type: rowValues.getValue('pickup_type'),
          drop_off_type: rowValues.getValue('drop_off_type'),
          continuous_pickup: rowValues.getValue('continuous_pickup'),
          continuous_drop_off: rowValues.getValue('continuous_drop_off'),
          shape_dist_traveled: rowValues.getValue('shape_dist_traveled'),
          timepoint: rowValues.getValue('timepoint'),
        );
      },
    );

    return appDatabase.batch((batch) {
      batch.insertAll(appDatabase.stopTimes, tripsInserts);
    });
  }

  Future<void> _insertCalendarDates(
    Archive archive,
    AppDatabase appDatabase,
  ) {
    final tripsInserts = _mapFileRowsToInserts(
      archive,
      'calendar_dates.txt',
      (rowValues) {
        return CalendarDatesCompanion.insert(
          service_id: rowValues.getRequiredValue('service_id'),
          date: rowValues.getRequiredValue('date'),
          exception_type: rowValues.getRequiredValue('exception_type'),
        );
      },
    );

    return appDatabase.batch((batch) {
      batch.insertAll(appDatabase.calendarDates, tripsInserts);
    });
  }
}
