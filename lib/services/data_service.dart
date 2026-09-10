import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models.dart';
import '../static_geo_data.dart';

/// Fetches and merges live datasets from the Malaysian government Open API
/// (https://developer.data.gov.my). Datasets used:
///
///  - `hies_district`        -> mean/median household income + poverty rate
///  - `population_district`  -> total population per district
///  - `hh_access_amenities`  -> % electricity access + % piped water access
///  - `schools_district`     -> real number of primary/secondary/tertiary
///                              public schools per district (Ministry of
///                              Education) - replaces the old "Where to
///                              study" proxy with a genuine figure
///  - `forest_reserve_state` -> permanent forest reserve area per state
///                              (hectares) - replaces the old static lookup
///  - `crime_district`       -> recorded crimes, aggregated to state level
///                              (police districts don't map 1:1 to
///                              administrative districts) - powers a new
///                              "Safety" indicator
///
/// All are combined into [DistrictData] / [StateInfraData] objects and
/// cached in memory for the lifetime of the app session.
///
/// FALLBACK STRATEGY: data.gov.my doesn't have a row for every
/// district/year combination. Rather than showing a bare "No data" any
/// time a specific district's row is missing, every field below falls
/// back - in order - to the most specific real figure still available
/// (the state's official aggregate, then the average of the districts
/// this app tracks in that state, then a national average as a last
/// resort for crime). A field only ever shows "No data" when none of
/// those exist either. Fallback values are tagged in
/// [DistrictData.estimatedFields] / [StateInfraData.estimatedFields] so
/// the UI can disclose "state average" etc. rather than presenting an
/// estimate as if it were the district's own figure.
class DataService {
  DataService._();
  static final DataService instance = DataService._();

  static const _base = 'https://api.data.gov.my/data-catalogue';

  List<DistrictData>? _districtCache;
  List<StateInfraData>? _stateCache;
  Map<String, double>? _crimeByStateCache;
  Map<String, Map<String, double>>? _stateAmenitiesCache;
  String? _lastError;
  DateTime? _lastRefreshed;

  /// When the live datasets were last actually fetched from data.gov.my
  /// (not merely read from the in-memory cache). Null until the first
  /// successful fetch. Shown on the Settings screen, with a manual
  /// "Refresh live data now" action that forces a new fetch.
  DateTime? get lastRefreshed => _lastRefreshed;

  String? get lastError => _lastError;

  Future<List<DistrictData>> getDistricts({bool forceRefresh = false}) async {
    if (_districtCache != null && !forceRefresh) return _districtCache!;
    if (forceRefresh) {
      _crimeByStateCache = null; // force the crime sub-fetch to run again too
      _stateAmenitiesCache = null;
    }
    final merged = <String, DistrictData>{};

    // Seed with every district we track statically so the UI has full
    // coverage even if a particular live field fails to fetch.
    for (final state in kDistrictsByState.keys) {
      for (final district in kDistrictsByState[state]!) {
        merged['$state|$district'] = DistrictData(
          state: state,
          district: district,
          areaKm2: districtAreaKm2[district],
        );
      }
    }

    try {
      final income = await _fetch('hies_district', extra: 'sort=-date&limit=1000');
      for (final row in income) {
        final state = row['state']?.toString();
        final district = row['district']?.toString();
        if (state == null || district == null) continue;
        final k = '$state|$district';
        if (!merged.containsKey(k)) continue; // only keep districts we track
        final existing = merged[k]!;
        // First (latest date, due to sort=-date) row wins per district.
        if (existing.incomeMean != null) continue;
        merged[k] = existing.copyWith(
          incomeMean: _num(row['income_mean']),
          incomeMedian: _num(row['income_median']),
          povertyRate: _num(row['poverty']),
        );
      }
    } catch (e) {
      _lastError = 'income: $e';
    }

    // Fallback: any district still missing income after the live fetch
    // gets the average of the OTHER tracked districts in its own state
    // that did get a real row, rather than a bare "No data". A district
    // is only left as "No data" if its whole state has no income figure
    // to average either.
    _fillMissingWithStateAverage(
      merged,
      getter: (d) => d.incomeMean,
      apply: (d, avg) => d.copyWith(incomeMean: avg, estimatedFields: {'income'}),
    );
    _fillMissingWithStateAverage(
      merged,
      getter: (d) => d.incomeMedian,
      apply: (d, avg) => d.copyWith(incomeMedian: avg, estimatedFields: {'income'}),
    );
    _fillMissingWithStateAverage(
      merged,
      getter: (d) => d.povertyRate,
      apply: (d, avg) => d.copyWith(povertyRate: avg, estimatedFields: {'income'}),
    );

    try {
      final pop = await _fetch(
        'population_district',
        extra: 'filter=overall@sex,overall@age,overall@ethnicity&sort=-date&limit=1000',
      );
      for (final row in pop) {
        final state = row['state']?.toString();
        final district = row['district']?.toString();
        if (state == null || district == null) continue;
        final k = '$state|$district';
        if (!merged.containsKey(k)) continue;
        final existing = merged[k]!;
        if (existing.population != null) continue;
        merged[k] = existing.copyWith(population: _num(row['population']));
      }
    } catch (e) {
      _lastError = 'population: $e';
    }
    // Population is deliberately NOT backfilled with an average: a
    // per-district headcount is exactly the kind of figure that a
    // neighbouring district's number can't stand in for, so a genuine
    // gap here is left as "No data" rather than a misleading guess.

    try {
      final amenities = await _fetch('hh_access_amenities', extra: 'sort=-date&limit=1000');
      for (final row in amenities) {
        final state = row['state']?.toString();
        final district = row['district']?.toString();
        if (state == null || district == null) continue;
        final k = '$state|$district';
        if (!merged.containsKey(k)) continue;
        final existing = merged[k]!;
        if (existing.electricityAccess != null) continue;
        merged[k] = existing.copyWith(
          electricityAccess: _num(row['electricity']),
          waterAccess: _num(row['water']),
        );
      }
    } catch (e) {
      _lastError = 'amenities: $e';
    }

    // Fallback for amenities, most-specific first: the state's official
    // "All Districts" aggregate row, then (only if that's missing too)
    // the average of the tracked districts in that state that do have a
    // figure.
    final stateAmenities = await _fetchStateAmenities();
    for (final k in merged.keys.toList()) {
      final d = merged[k]!;
      if (d.electricityAccess != null && d.waterAccess != null) continue;
      final row = stateAmenities[d.state];
      if (row == null) continue;
      merged[k] = d.copyWith(
        electricityAccess: d.electricityAccess ?? row['electricity'],
        waterAccess: d.waterAccess ?? row['water'],
        estimatedFields: {'electricity', 'water'},
      );
    }
    _fillMissingWithStateAverage(
      merged,
      getter: (d) => d.electricityAccess,
      apply: (d, avg) => d.copyWith(electricityAccess: avg, estimatedFields: {'electricity'}),
    );
    _fillMissingWithStateAverage(
      merged,
      getter: (d) => d.waterAccess,
      apply: (d, avg) => d.copyWith(waterAccess: avg, estimatedFields: {'water'}),
    );

    // Real school counts, summed per (state, district, stage) for the
    // most recent year present in the response. The dataset breaks each
    // stage down further by school 'type' (e.g. national/vernacular), so
    // multiple rows must be SUMMED rather than "first wins".
    try {
      final schools = await _fetch('schools_district', extra: 'sort=-date&limit=4000');
      final latestDatePerKey = <String, String>{};
      final totalsPerKey = <String, double>{};
      for (final row in schools) {
        final state = row['state']?.toString();
        final district = row['district']?.toString();
        final stage = row['stage']?.toString();
        final date = row['date']?.toString() ?? '';
        if (state == null || district == null || stage == null) continue;
        final k = '$state|$district|$stage';
        if (!merged.containsKey('$state|$district')) continue;
        final knownDate = latestDatePerKey[k];
        if (knownDate == null) {
          latestDatePerKey[k] = date;
        } else if (date != knownDate) {
          continue; // older year for this key - skip, we only want the latest
        }
        totalsPerKey[k] = (totalsPerKey[k] ?? 0) + (_num(row['schools']) ?? 0);
      }
      for (final entry in totalsPerKey.entries) {
        final parts = entry.key.split('|');
        final dk = '${parts[0]}|${parts[1]}';
        final stage = parts[2];
        final existing = merged[dk];
        if (existing == null) continue;
        merged[dk] = existing.copyWith(
          primarySchools: stage == 'primary' ? entry.value : null,
          secondarySchools: stage == 'secondary' ? entry.value : null,
          tertiarySchools: stage == 'tertiary' ? entry.value : null,
        );
      }
    } catch (e) {
      _lastError = 'schools: $e';
    }
    // Schools are not backfilled with an average: a district genuinely
    // having zero schools of a given stage is a real, meaningful figure
    // in its own right (already handled by DistrictData.totalSchools
    // treating a missing single stage as 0 when at least one stage did
    // report), so guessing a non-zero count here would misinform rather
    // than help.

    // Crime, aggregated to state level and turned into a rough per-capita
    // figure using the summed population of the districts we track in
    // that state (state-level population isn't exposed via the Open API,
    // so this is an approximation - documented in the UI).
    try {
      final crimeByState = await _fetchLatestYearCrimeByState();
      final popByState = <String, double>{};
      for (final d in merged.values) {
        if (d.population != null) {
          popByState[d.state] = (popByState[d.state] ?? 0) + d.population!;
        }
      }
      final perCapitaByState = <String, double>{};
      for (final state in crimeByState.keys) {
        final pop = popByState[state];
        if (pop == null || pop == 0) continue;
        perCapitaByState[state] = crimeByState[state]! / pop * 1000;
      }

      // Fallback: a state with no crime figure of its own (dataset gap,
      // or no tracked population to divide by) gets the national average
      // per-capita rate across the states that DO have one, so the
      // safety indicator still reads as a real number with a caveat
      // instead of silently defaulting the score formula's built-in 8.
      final nationalAvg = perCapitaByState.values.isNotEmpty
          ? perCapitaByState.values.reduce((a, b) => a + b) / perCapitaByState.values.length
          : null;

      for (final state in kAllStates) {
        final perCapita = perCapitaByState[state];
        final isEstimate = perCapita == null && nationalAvg != null;
        final value = perCapita ?? nationalAvg;
        if (value == null) continue;
        final matchingKeys = merged.keys.where((k) => k.startsWith('$state|')).toList();
        for (final k in matchingKeys) {
          merged[k] = merged[k]!.copyWith(
            stateCrimesPerCapita: value,
            estimatedFields: isEstimate ? {'crime'} : {},
          );
        }
      }
    } catch (e) {
      _lastError = 'crime: $e';
    }

    _districtCache = merged.values.toList();
    _lastRefreshed = DateTime.now();
    return _districtCache!;
  }

  Future<List<StateInfraData>> getStates({bool forceRefresh = false}) async {
    if (_stateCache != null && !forceRefresh) return _stateCache!;

    final byState = <String, List<DistrictData>>{};
    final districts = await getDistricts(forceRefresh: forceRefresh);
    for (final d in districts) {
      byState.putIfAbsent(d.state, () => []).add(d);
    }

    // Reuses the same "All Districts" aggregate already fetched (and
    // cached) for the per-district fallback above, so state screens and
    // district screens agree on the same figure instead of doing two
    // separate network round-trips for the same data.
    final stateRow = await _fetchStateAmenities();

    // Live forest reserve area per state (hectares -> km2).
    Map<String, double> forestKm2 = {};
    try {
      final forest = await _fetch('forest_reserve_state', extra: 'sort=-date&limit=100');
      final seenDate = <String, String>{};
      for (final row in forest) {
        final state = row['state']?.toString();
        final date = row['date']?.toString() ?? '';
        if (state == null || !kAllStates.contains(state)) continue; // skip "Peninsular Malaysia" aggregate
        if (seenDate.containsKey(state) && seenDate[state] != date) continue;
        seenDate[state] = date;
        final hectares = _num(row['area']) ?? 0;
        forestKm2[state] = hectares / 100; // 1 km2 = 100 ha
      }
    } catch (e) {
      _lastError = 'forest reserve: $e';
    }

    final crimeByState = await _fetchLatestYearCrimeByState();
    final popByState = <String, double>{
      for (final state in byState.keys)
        state: byState[state]!.map((d) => d.population).whereType<double>().fold<double>(0, (a, b) => a + b),
    };
    final perCapitaByState = <String, double>{
      for (final state in crimeByState.keys)
        if ((popByState[state] ?? 0) > 0) state: crimeByState[state]! / popByState[state]! * 1000,
    };
    final nationalAvgPerCapita = perCapitaByState.values.isNotEmpty
        ? perCapitaByState.values.reduce((a, b) => a + b) / perCapitaByState.values.length
        : null;

    final result = <StateInfraData>[];
    for (final state in kAllStates) {
      final estimated = <String>{};

      double? elec = stateRow[state]?['electricity'];
      double? water = stateRow[state]?['water'];
      if (elec == null || water == null) {
        final ds = byState[state] ?? [];
        final elecVals = ds.map((d) => d.electricityAccess).whereType<double>().toList();
        final waterVals = ds.map((d) => d.waterAccess).whereType<double>().toList();
        if (elecVals.isNotEmpty) elec ??= elecVals.reduce((a, b) => a + b) / elecVals.length;
        if (waterVals.isNotEmpty) water ??= waterVals.reduce((a, b) => a + b) / waterVals.length;
      }

      final trackedPop = (byState[state] ?? [])
          .map((d) => d.population)
          .whereType<double>()
          .fold<double>(0, (a, b) => a + b);
      final crimes = crimeByState[state];
      double? crimesPerCapita = (crimes != null && trackedPop > 0) ? crimes / trackedPop * 1000 : null;
      if (crimesPerCapita == null && nationalAvgPerCapita != null) {
        crimesPerCapita = nationalAvgPerCapita;
        estimated.add('crime');
      }

      final liveForest = forestKm2[state];
      final forest = liveForest ?? stateForestReserveKm2[state];
      if (liveForest == null && forest != null) estimated.add('forest');

      result.add(StateInfraData(
        state: state,
        electricityAccess: elec,
        waterAccess: water,
        forestReserveKm2: forest,
        totalCrimes: crimes,
        crimesPerCapita: crimesPerCapita,
        estimatedFields: estimated,
      ));
    }
    _stateCache = result;
    return result;
  }

  /// The official state-level "All Districts" row from hh_access_amenities
  /// (electricity/water %), cached for the session and shared by both
  /// [getDistricts] (per-district fallback) and [getStates].
  Future<Map<String, Map<String, double>>> _fetchStateAmenities() async {
    if (_stateAmenitiesCache != null) return _stateAmenitiesCache!;
    final result = <String, Map<String, double>>{};
    try {
      final amenities = await _fetch(
        'hh_access_amenities',
        extra: 'filter=All Districts@district&sort=-date&limit=200',
      );
      for (final row in amenities) {
        final state = row['state']?.toString();
        if (state == null) continue;
        result.putIfAbsent(state, () => {
          'electricity': _num(row['electricity']) ?? 0,
          'water': _num(row['water']) ?? 0,
        });
      }
    } catch (e) {
      _lastError = 'state amenities: $e';
    }
    _stateAmenitiesCache = result;
    return result;
  }

  /// Sums crime_district's most recent year of data by state (raw
  /// counts across every police district, category, and type).
  Future<Map<String, double>> _fetchLatestYearCrimeByState() async {
    if (_crimeByStateCache != null) return _crimeByStateCache!;
    final result = <String, double>{};
    try {
      final rows = await _fetch('crime_district', extra: 'sort=-date&limit=6000');
      final latestDatePerState = <String, String>{};
      for (final row in rows) {
        final state = row['state']?.toString();
        final date = row['date']?.toString() ?? '';
        if (state == null || !kAllStates.contains(state)) continue;
        final knownDate = latestDatePerState[state];
        if (knownDate == null) {
          latestDatePerState[state] = date;
        } else if (date != knownDate) {
          continue;
        }
        result[state] = (result[state] ?? 0) + (_num(row['crimes']) ?? 0);
      }
    } catch (e) {
      _lastError = 'crime: $e';
    }
    _crimeByStateCache = result;
    return result;
  }

  /// Fills a field on every district in [merged] that's missing it with
  /// the average of the OTHER tracked districts in the same state that
  /// do have a value. [apply] is responsible for tagging the result in
  /// [DistrictData.estimatedFields]. Districts in a state where nothing
  /// is available to average are left untouched (still "No data").
  void _fillMissingWithStateAverage(
      Map<String, DistrictData> merged, {
        required double? Function(DistrictData) getter,
        required DistrictData Function(DistrictData, double) apply,
      }) {
    final byState = <String, List<DistrictData>>{};
    for (final d in merged.values) {
      byState.putIfAbsent(d.state, () => []).add(d);
    }
    for (final state in byState.keys) {
      final ds = byState[state]!;
      final known = ds.map(getter).whereType<double>().toList();
      if (known.isEmpty) continue; // nothing in this state to average - leave as "No data"
      final avg = known.reduce((a, b) => a + b) / known.length;
      for (final d in ds) {
        if (getter(d) != null) continue; // already has a real figure
        merged[d.key] = apply(d, avg);
      }
    }
  }

  /// Multi-year income trend (mean income) for a single district, used to
  /// draw the sparkline on the district detail screen. When the district
  /// itself has fewer than 3 years of its own data - too sparse to read
  /// as a real trend - years missing from the district series are filled
  /// in from the state's own "All Districts" aggregate for that year and
  /// marked [TrendPoint.isEstimated], so the chart still shows a
  /// meaningful multi-year shape instead of one or two floating dots.
  Future<List<TrendPoint>> getIncomeTrend(String state, String district) async {
    final points = <int, TrendPoint>{};
    try {
      final rows = await _fetch(
        'hies_district',
        extra: 'filter=$state@state,$district@district&sort=date&limit=20',
      );
      for (final row in rows) {
        final year = _year(row['date']);
        final value = _num(row['income_mean']);
        if (year != null && value != null && value > 0) {
          points[year] = TrendPoint(year: year, value: value, isEstimated: false);
        }
      }
    } catch (_) {
      // fall through to the state-level backfill below
    }

    if (points.length < 3) {
      try {
        final rows = await _fetch(
          'hies_district',
          extra: 'filter=$state@state,All Districts@district&sort=date&limit=20',
        );
        for (final row in rows) {
          final year = _year(row['date']);
          final value = _num(row['income_mean']);
          if (year != null && value != null && value > 0 && !points.containsKey(year)) {
            points[year] = TrendPoint(year: year, value: value, isEstimated: true);
          }
        }
      } catch (_) {
        // leave whatever district-level points we already have
      }
    }

    final list = points.values.toList()..sort((a, b) => a.year.compareTo(b.year));
    return list;
  }

  /// Multi-year mean-income trend for a whole state (the "All Districts"
  /// aggregate row over time), used for the Trend panel on the state
  /// detail screen. Unlike the district version above, every point here
  /// is a genuine state-level figure, so none are marked estimated.
  Future<List<TrendPoint>> getStateIncomeTrend(String state) async {
    try {
      final rows = await _fetch(
        'hies_district',
        extra: 'filter=$state@state,All Districts@district&sort=date&limit=20',
      );
      final points = <int, TrendPoint>{};
      for (final row in rows) {
        final year = _year(row['date']);
        final value = _num(row['income_mean']);
        if (year != null && value != null && value > 0) {
          points[year] = TrendPoint(year: year, value: value, isEstimated: false);
        }
      }
      final list = points.values.toList()..sort((a, b) => a.year.compareTo(b.year));
      return list;
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetch(String id, {String extra = ''}) async {
    // State/district names used in filter values (e.g. "Kuala Lumpur",
    // "All Districts") contain spaces, which must be percent-encoded or
    // Uri.parse can mis-handle the query string and the filter silently
    // fails. '@' and ',' are left as-is - they're meaningful delimiters
    // in data.gov.my's own filter syntax, not raw data values.
    final safeExtra = extra.replaceAll(' ', '%20');
    final uri = Uri.parse('$_base?id=$id${safeExtra.isNotEmpty ? '&$safeExtra' : ''}');
    final res = await http.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode} for $id');
    }
    final decoded = jsonDecode(res.body);
    if (decoded is List) {
      return decoded.cast<Map<String, dynamic>>();
    }
    if (decoded is Map && decoded['data'] is List) {
      return (decoded['data'] as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  double? _num(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  int? _year(dynamic date) {
    final s = date?.toString();
    if (s == null || s.length < 4) return null;
    return int.tryParse(s.substring(0, 4));
  }
}


