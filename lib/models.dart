/// Core data models for UrbanEx.

/// All the "magic numbers" behind the three scoring formulas, gathered in
/// one place so they're easy to tune against your assignment's rubric
/// without hunting through the scoring methods themselves. Every constant
/// says which score it affects and what it represents.
class ScoringTuning {
  // --- Where should I live? (livabilityScore) -----------------------
  /// Mean income (RM/month) treated as "as good as it gets" when scaling
  /// the income component to 0-100. Districts at or above this earn full
  /// marks on income; below it scales linearly.
  static const double incomeScaleMax = 12000;

  /// Poverty rate (%) treated as "worst case" when scaling the poverty
  /// component - 0% poverty scores 100, this value or above scores 0.
  static const double povertyRateWorstCase = 25;

  /// Population density (people/km²) treated as "very crowded" when
  /// scoring the "low population" priority - higher density than this
  /// scores 0 on that component.
  static const double densityWorstCase = 10000;

  /// Crimes per 1,000 residents (state-level approximation) treated as
  /// "very unsafe" when scoring the "low crime rate" priority.
  static const double crimeRateWorstCase = 30;

  /// Default (unweighted) component weights - each priority chip
  /// multiplies its own component's weight (see [priorityWeightBoost]).
  static const double baseIncomeWeight = 1;
  static const double basePovertyWeight = 1;
  static const double baseAmenitiesWeight = 1;
  static const double baseDensityWeight = 0.6;
  static const double baseSafetyWeight = 1;

  /// How much a matching priority chip multiplies that component's base
  /// weight by (applied instead of the base weight, not on top of it).
  /// Each priority gets its own named constant so they can be tuned
  /// independently.
  static const double lowPovertyWeightBoost = 2.2;
  static const double lowPopulationWeightBoost = 2.2;
  static const double govServicesWeightBoost = 2.0;
  static const double lowCrimeWeightBoost = 2.4;
  static const double entertainmentIncomeWeight = 1.6; // proxy: higher-income areas tend to have more amenities/entertainment

  // --- Where to study? (studyScore) -----------------------------------
  /// Schools per 10,000 residents treated as "excellent provision" when
  /// scaling the school-density component to 0-100.
  static const double schoolsPer10kScaleMax = 6;

  /// Relative weights combining the school-density score, amenities, and
  /// poverty rate into the final study score.
  static const double studySchoolWeight = 2.4;
  static const double studyAmenitiesWeight = 1.0;
  static const double studyPovertyWeight = 0.8;

  // --- Where to open a business? (businessScore) -----------------------
  /// Population density (people/km²) treated as "prime footfall" when
  /// scaling the density component to 0-100 for business viability.
  static const double businessDensityScaleMax = 8000;

  static const double baseBusinessWeight = 1.0;
  static const double highIncomeWeightBoost = 2.2;
  static const double highDensityWeightBoost = 2.2;
  static const double highSpendingWeightBoost = 2.0;
  static const double businessPowerWeight = 0.6;
}

/// One point on a multi-year trend line (e.g. income over time). Real
/// data.gov.my rows for the district/state itself have [isEstimated] set
/// to false; points borrowed from a broader aggregate (used only to keep
/// a very sparse trend chart meaningful) are marked true so the UI can
/// draw them differently and disclose them.
class TrendPoint {
  final int year;
  final double value;
  final bool isEstimated;

  const TrendPoint({required this.year, required this.value, this.isEstimated = false});
}

/// A single administrative district with live indicators pulled from
/// data.gov.my: income + amenities (hies_district / hh_access_amenities),
/// population (population_district), and real school counts
/// (schools_district). Only land area is a static reference lookup
/// (used solely to derive population density, since land area itself
/// has no live open-data API in Malaysia).
class DistrictData {
  final String state;
  final String district;

  final double? incomeMean; // RM/month, from hies_district
  final double? incomeMedian; // RM/month, from hies_district
  final double? povertyRate; // %, from hies_district
  final double? electricityAccess; // %, from hh_access_amenities
  final double? waterAccess; // %, from hh_access_amenities
  final double? population; // headcount, from population_district
  final double? areaKm2; // static reference lookup

  // Live from schools_district (Ministry of Education, via data.gov.my).
  final double? primarySchools;
  final double? secondarySchools;
  final double? tertiarySchools;

  // Live from crime_district, aggregated to the district's STATE (police
  // districts don't line up with administrative districts, so this is
  // applied uniformly to every district within that state). This is an
  // approximation: true state population isn't exposed by the Open API,
  // so it's derived from the summed population of the districts this app
  // tracks in that state, not the state's actual full population.
  final double? stateCrimesPerCapita; // crimes per 1,000 residents (approx.)

  /// Which of the fields above were NOT this district's own live row but
  /// were filled in from a broader fallback (state average, or the
  /// state's "All Districts" aggregate) so the UI can show a real number
  /// with a caveat instead of a bare "No data". Values used here match
  /// the field names: 'income', 'electricity', 'water', 'crime'.
  final Set<String> estimatedFields;

  DistrictData({
    required this.state,
    required this.district,
    this.incomeMean,
    this.incomeMedian,
    this.povertyRate,
    this.electricityAccess,
    this.waterAccess,
    this.population,
    this.areaKm2,
    this.primarySchools,
    this.secondarySchools,
    this.tertiarySchools,
    this.stateCrimesPerCapita,
    this.estimatedFields = const {},
  });

  DistrictData copyWith({
    double? incomeMean,
    double? incomeMedian,
    double? povertyRate,
    double? electricityAccess,
    double? waterAccess,
    double? population,
    double? areaKm2,
    double? primarySchools,
    double? secondarySchools,
    double? tertiarySchools,
    double? stateCrimesPerCapita,
    Set<String>? estimatedFields,
  }) {
    return DistrictData(
      state: state,
      district: district,
      incomeMean: incomeMean ?? this.incomeMean,
      incomeMedian: incomeMedian ?? this.incomeMedian,
      povertyRate: povertyRate ?? this.povertyRate,
      electricityAccess: electricityAccess ?? this.electricityAccess,
      waterAccess: waterAccess ?? this.waterAccess,
      population: population ?? this.population,
      areaKm2: areaKm2 ?? this.areaKm2,
      primarySchools: primarySchools ?? this.primarySchools,
      secondarySchools: secondarySchools ?? this.secondarySchools,
      tertiarySchools: tertiarySchools ?? this.tertiarySchools,
      stateCrimesPerCapita: stateCrimesPerCapita ?? this.stateCrimesPerCapita,
      // Estimated tags accumulate - once a field has been filled in from a
      // fallback it should keep reading as estimated even if a later
      // copyWith() call (for an unrelated field) doesn't repeat the tag.
      estimatedFields: {...this.estimatedFields, ...?estimatedFields},
    );
  }

  double? get populationDensity {
    if (population == null || areaKm2 == null || areaKm2 == 0) return null;
    return population! / areaKm2!;
  }

  /// Total real schools of any level in the district - a genuine,
  /// directly-relevant education-access figure (as opposed to a proxy).
  double? get totalSchools {
    if (primarySchools == null && secondarySchools == null && tertiarySchools == null) return null;
    return (primarySchools ?? 0) + (secondarySchools ?? 0) + (tertiarySchools ?? 0);
  }

  /// Schools per 10,000 residents, for the given [stage] ('primary',
  /// 'secondary', or 'tertiary') - the actual metric used by studyScore.
  double? schoolsPer10k(String stage) {
    final count = stage == 'primary'
        ? primarySchools
        : stage == 'secondary'
        ? secondarySchools
        : tertiarySchools;
    if (count == null || population == null || population == 0) return null;
    return count / population! * 10000;
  }

  String get key => '$state|$district';

  /// Overall "Where should I live" livability score (0-100), optionally
  /// weighted by the user's selected priorities. Tunable via
  /// [ScoringTuning] - see that class for what each constant controls.
  double livabilityScore({Set<String> priorities = const {}}) {
    final income = _clamp01((incomeMean ?? 4500) / ScoringTuning.incomeScaleMax) * 100;
    final povertyScore = _clamp01(1 - ((povertyRate ?? 5) / ScoringTuning.povertyRateWorstCase)) * 100;
    final amenities = ((electricityAccess ?? 95) + (waterAccess ?? 90)) / 2;
    final density = populationDensity ?? 800;
    // Lower density scores higher when the user prioritises "low population".
    final densityScore = _clamp01(1 - (density / ScoringTuning.densityWorstCase)) * 100;
    // Fewer crimes per capita (relative to other states) scores higher.
    final safetyScore = _clamp01(1 - ((stateCrimesPerCapita ?? 8) / ScoringTuning.crimeRateWorstCase)) * 100;

    double incomeWeight = ScoringTuning.baseIncomeWeight;
    double povertyWeight = ScoringTuning.basePovertyWeight;
    double amenitiesWeight = ScoringTuning.baseAmenitiesWeight;
    double densityWeight = ScoringTuning.baseDensityWeight;
    double safetyWeight = ScoringTuning.baseSafetyWeight;

    if (priorities.contains('Low poverty rate')) povertyWeight = ScoringTuning.lowPovertyWeightBoost;
    if (priorities.contains('Low population')) densityWeight = ScoringTuning.lowPopulationWeightBoost;
    if (priorities.contains('Government services nearby')) amenitiesWeight = ScoringTuning.govServicesWeightBoost;
    if (priorities.contains('Entertainment')) incomeWeight = ScoringTuning.entertainmentIncomeWeight;
    if (priorities.contains('Low crime rate')) safetyWeight = ScoringTuning.lowCrimeWeightBoost;

    final totalWeight = incomeWeight + povertyWeight + amenitiesWeight + densityWeight + safetyWeight;
    final score = (income * incomeWeight +
        povertyScore * povertyWeight +
        amenities * amenitiesWeight +
        densityScore * densityWeight +
        safetyScore * safetyWeight) /
        totalWeight;
    return score.clamp(0, 100);
  }

  /// "Where to study" score - built from REAL school-density figures
  /// (schools per 10,000 residents, from the Ministry of Education via
  /// data.gov.my) for the selected education stage, plus amenities as a
  /// secondary factor. Tunable via [ScoringTuning].
  ///
  /// Note: the "International"/"Private"/"Government" priority chips have
  /// no live signal - this dataset only covers PUBLIC institutions - so
  /// they don't change the score. They're kept as informational filters
  /// only (see the note shown under those chips in the UI).
  double studyScore({required String stage, Set<String> priorities = const {}}) {
    final density = schoolsPer10k(stage) ?? 0;
    final schoolScore = _clamp01(density / ScoringTuning.schoolsPer10kScaleMax) * 100;
    final amenities = ((electricityAccess ?? 95) + (waterAccess ?? 90)) / 2;
    final povertyScore = _clamp01(1 - ((povertyRate ?? 5) / ScoringTuning.povertyRateWorstCase)) * 100;

    final totalWeight = ScoringTuning.studySchoolWeight + ScoringTuning.studyAmenitiesWeight + ScoringTuning.studyPovertyWeight;
    final score = (schoolScore * ScoringTuning.studySchoolWeight +
        amenities * ScoringTuning.studyAmenitiesWeight +
        povertyScore * ScoringTuning.studyPovertyWeight) /
        totalWeight;
    return score.clamp(0, 100);
  }

  /// "Where to open a business" score - built from income (spending
  /// power proxy), population density (footfall proxy) and electricity
  /// reliability. Tunable via [ScoringTuning].
  double businessScore({Set<String> priorities = const {}}) {
    final income = _clamp01((incomeMean ?? 4500) / ScoringTuning.incomeScaleMax) * 100;
    final density = populationDensity ?? 800;
    final densityScore = _clamp01(density / ScoringTuning.businessDensityScaleMax) * 100;
    final power = electricityAccess ?? 95;

    double incomeWeight = priorities.contains('High income') ? ScoringTuning.highIncomeWeightBoost : ScoringTuning.baseBusinessWeight;
    double densityWeight = priorities.contains('High density') ? ScoringTuning.highDensityWeightBoost : ScoringTuning.baseBusinessWeight;
    double spendingWeight = priorities.contains('High spending rate') ? ScoringTuning.highSpendingWeightBoost : ScoringTuning.baseBusinessWeight;

    final totalWeight = incomeWeight + densityWeight + spendingWeight + ScoringTuning.businessPowerWeight;
    final score = (income * incomeWeight +
        densityScore * densityWeight +
        income * spendingWeight + // spending rate proxied by income
        power * ScoringTuning.businessPowerWeight) /
        totalWeight;
    return score.clamp(0, 100);
  }

  double _clamp01(double v) => v.clamp(0, 1);
}

/// Aggregated state-level infrastructure & safety indicators for the
/// "How is the infrastructure?" flow.
class StateInfraData {
  final String state;
  final double? electricityAccess; // %, from hh_access_amenities (district='All Districts' or averaged)
  final double? waterAccess; // %, from hh_access_amenities
  final double? forestReserveKm2; // live from forest_reserve_state, falls back to a static estimate
  final double? totalCrimes; // live, from crime_district (latest year, summed)
  final double? crimesPerCapita; // crimes per 1,000 residents (approx., from tracked districts)

  /// Which fields above came from a fallback rather than a direct live
  /// row for this state: 'forest' (static reference lookup instead of
  /// the live dataset) or 'crime' (national average instead of a
  /// state-specific figure).
  final Set<String> estimatedFields;

  StateInfraData({
    required this.state,
    this.electricityAccess,
    this.waterAccess,
    this.forestReserveKm2,
    this.totalCrimes,
    this.crimesPerCapita,
    this.estimatedFields = const {},
  });

  double get score {
    final e = electricityAccess ?? 90;
    final w = waterAccess ?? 85;
    return ((e + w) / 2).clamp(0, 100);
  }

  bool get isFlagged => score < 75;
}

/// A saved favourite entry (either a state or a district).
class FavoriteEntry {
  final String type; // 'state' or 'district'
  final String state;
  final String? district;
  final double score;

  FavoriteEntry({
    required this.type,
    required this.state,
    this.district,
    required this.score,
  });

  String get id => type == 'state' ? 'state:$state' : 'district:$state:$district';
  String get title => type == 'state' ? state : (district ?? state);
  String get subtitle => state;

  Map<String, dynamic> toJson() => {
    'type': type,
    'state': state,
    'district': district,
    'score': score,
  };

  factory FavoriteEntry.fromJson(Map<String, dynamic> json) => FavoriteEntry(
    type: json['type'] as String,
    state: json['state'] as String,
    district: json['district'] as String?,
    score: (json['score'] as num).toDouble(),
  );
}


/// A locally-stored account (registered on this device only - UrbanEx has
/// no backend server, so "logging in" simply unlocks the app on this
/// device using credentials saved via SharedPreferences). The password is
/// never stored in plain text - only a salted SHA-256 hash, produced by
/// AuthService.
class UserAccount {
  final String email; // stored lowercase, used as the unique key
  final String name;
  final String passwordHash;
  final String salt;
  final DateTime createdAt;
  final bool isAdmin;

  UserAccount({
    required this.email,
    required this.name,
    required this.passwordHash,
    required this.salt,
    required this.createdAt,
    this.isAdmin = false,
  });

  /// Returns a copy of this account with the given fields replaced -
  /// used by admin actions (e.g. toggling admin status) that need to
  /// update one field without touching the password hash/salt.
  UserAccount copyWith({bool? isAdmin}) => UserAccount(
    email: email,
    name: name,
    passwordHash: passwordHash,
    salt: salt,
    createdAt: createdAt,
    isAdmin: isAdmin ?? this.isAdmin,
  );

  Map<String, dynamic> toJson() => {
    'email': email,
    'name': name,
    'passwordHash': passwordHash,
    'salt': salt,
    'createdAt': createdAt.toIso8601String(),
    'isAdmin': isAdmin,
  };

  factory UserAccount.fromJson(Map<String, dynamic> json) => UserAccount(
    email: json['email'] as String,
    name: json['name'] as String,
    passwordHash: json['passwordHash'] as String,
    salt: json['salt'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    // Defaults to false so accounts saved before this field existed
    // (by an older version of the app) still load correctly.
    isAdmin: json['isAdmin'] as bool? ?? false,
  );
}

class FeedbackEntry {
  final String id; // timestamp-based, unique enough for a single-device list
  final String category;
  final String? name;
  final String? email;
  final String message;
  final DateTime submittedAt;
  final bool read;

  /// The actual signed-in account's email at the moment of submission -
  /// separate from [email] above (which is just a free-text "reply-to"
  /// field the person typed and could leave blank or change). This is
  /// what a reply notification is addressed to; [email] is only ever
  /// shown to the admin as a display convenience.
  final String? submittedByEmail;

  final String? adminReply;
  final DateTime? repliedAt;
  final String? repliedByEmail;

  FeedbackEntry({
    required this.id,
    required this.category,
    this.name,
    this.email,
    required this.message,
    required this.submittedAt,
    this.read = false,
    this.submittedByEmail,
    this.adminReply,
    this.repliedAt,
    this.repliedByEmail,
  });

  bool get hasReply => adminReply != null && adminReply!.trim().isNotEmpty;

  FeedbackEntry copyWith({
    bool? read,
    String? adminReply,
    DateTime? repliedAt,
    String? repliedByEmail,
  }) => FeedbackEntry(
    id: id,
    category: category,
    name: name,
    email: email,
    message: message,
    submittedAt: submittedAt,
    read: read ?? this.read,
    submittedByEmail: submittedByEmail,
    adminReply: adminReply ?? this.adminReply,
    repliedAt: repliedAt ?? this.repliedAt,
    repliedByEmail: repliedByEmail ?? this.repliedByEmail,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'category': category,
    'name': name,
    'email': email,
    'message': message,
    'submittedAt': submittedAt.toIso8601String(),
    'read': read,
    'submittedByEmail': submittedByEmail,
    'adminReply': adminReply,
    'repliedAt': repliedAt?.toIso8601String(),
    'repliedByEmail': repliedByEmail,
  };

  factory FeedbackEntry.fromJson(Map<String, dynamic> json) => FeedbackEntry(
    id: json['id'] as String,
    category: json['category'] as String,
    name: json['name'] as String?,
    email: json['email'] as String?,
    message: json['message'] as String,
    submittedAt: DateTime.parse(json['submittedAt'] as String),
    read: json['read'] as bool? ?? false,
    submittedByEmail: json['submittedByEmail'] as String?,
    adminReply: json['adminReply'] as String?,
    repliedAt: json['repliedAt'] != null ? DateTime.parse(json['repliedAt'] as String) : null,
    repliedByEmail: json['repliedByEmail'] as String?,
  );
}

/// An in-app notification for one of three things UrbanEx can tell a
/// person about: an admin replying to their feedback, their school/
/// business application being approved or rejected, or news being
/// posted for a district they've favorited.
///
/// [recipientEmail] is null for district-news notifications specifically
/// - favorites in UrbanEx are a single per-device list, not tied to one
/// signed-in account (there's no server to scope them per-user), so a
/// district-news notification is addressed to "whoever uses this device"
/// rather than one account. Feedback-reply and application-status
/// notifications DO have a real account behind them (you must be signed
/// in to submit an application, and feedback now records the signed-in
/// submitter too), so those use a real [recipientEmail].
class NotificationEntry {
  final String id;
  final String type; // 'feedback_reply' | 'application_status' | 'district_news'
  final String title;
  final String body;
  final DateTime createdAt;
  final bool read;
  final String? recipientEmail;
  final String? relatedFeedbackId;
  final String? relatedApplicationId;
  final String? relatedDistrictState;
  final String? relatedDistrictName;
  // Links a 'district_news' notification back to the specific DistrictNews
  // post it was created for, so an edit/delete of that post can find and
  // update/remove exactly this notification instead of every notification
  // ever sent for that district. Null on notifications created before this
  // field existed, or on other notification types.
  final String? relatedNewsId;
  // Viewer keys (account email, or [guestViewerKey] for a signed-out
  // visitor) who have read this notification. This only matters for
  // notifications created before per-viewer delivery existed, where
  // recipientEmail is null and the same stored entry is shown to every
  // viewer on the device (see NewsService.postNews for how new district
  // news notifications avoid this by creating one independent entry per
  // viewer instead). Without this, an old shared entry read as a guest
  // would appear read in the admin's list too, and vice versa.
  final List<String> readBy;

  /// Only set on 'application_status' notifications: 'approved' or
  /// 'rejected' - lets the UI pick a checkmark vs. cross icon without
  /// having to parse [title]/[body] text. Null for every other type, and
  /// for application-status notifications created before this field
  /// existed (those fall back to a neutral icon).
  final String? applicationStatus;

  static const String guestViewerKey = '__guest__';

  NotificationEntry({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.read = false,
    this.recipientEmail,
    this.relatedFeedbackId,
    this.relatedApplicationId,
    this.relatedDistrictState,
    this.relatedDistrictName,
    this.relatedNewsId,
    this.readBy = const [],
    this.applicationStatus,
  });

  /// The read state that should actually be shown to [viewerEmail] (or
  /// to a guest, if null) - see the note on [readBy] for why a single
  /// shared `read` flag isn't enough for device-wide notifications.
  bool isReadFor(String? viewerEmail) {
    if (recipientEmail != null) return read;
    return readBy.contains(viewerEmail ?? guestViewerKey);
  }

  NotificationEntry copyWith({
    bool? read,
    String? title,
    String? body,
    String? relatedDistrictState,
    String? relatedDistrictName,
    List<String>? readBy,
  }) => NotificationEntry(
    id: id,
    type: type,
    title: title ?? this.title,
    body: body ?? this.body,
    createdAt: createdAt,
    read: read ?? this.read,
    recipientEmail: recipientEmail,
    relatedFeedbackId: relatedFeedbackId,
    relatedApplicationId: relatedApplicationId,
    relatedDistrictState: relatedDistrictState ?? this.relatedDistrictState,
    relatedDistrictName: relatedDistrictName ?? this.relatedDistrictName,
    relatedNewsId: relatedNewsId,
    readBy: readBy ?? this.readBy,
    applicationStatus: applicationStatus,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'title': title,
    'body': body,
    'createdAt': createdAt.toIso8601String(),
    'read': read,
    'recipientEmail': recipientEmail,
    'relatedFeedbackId': relatedFeedbackId,
    'relatedApplicationId': relatedApplicationId,
    'relatedDistrictState': relatedDistrictState,
    'relatedDistrictName': relatedDistrictName,
    'relatedNewsId': relatedNewsId,
    'readBy': readBy,
    'applicationStatus': applicationStatus,
  };

  factory NotificationEntry.fromJson(Map<String, dynamic> json) => NotificationEntry(
    id: json['id'] as String,
    type: json['type'] as String,
    title: json['title'] as String,
    body: json['body'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    read: json['read'] as bool? ?? false,
    recipientEmail: json['recipientEmail'] as String?,
    relatedFeedbackId: json['relatedFeedbackId'] as String?,
    relatedApplicationId: json['relatedApplicationId'] as String?,
    relatedDistrictState: json['relatedDistrictState'] as String?,
    relatedDistrictName: json['relatedDistrictName'] as String?,
    relatedNewsId: json['relatedNewsId'] as String?,
    readBy: (json['readBy'] as List?)?.map((e) => e as String).toList() ?? const [],
    applicationStatus: json['applicationStatus'] as String?,
  );
}

/// A short news update an admin has posted for a specific district,
/// shown on that district's detail page. Purely editorial content typed
/// by an admin - not pulled from any live news API (Malaysia's open data
/// portal doesn't expose one).
class DistrictNews {
  final String id;
  final String state;
  final String district;
  final String title;
  final String body;
  final DateTime postedAt;
  final String postedByEmail;

  DistrictNews({
    required this.id,
    required this.state,
    required this.district,
    required this.title,
    required this.body,
    required this.postedAt,
    required this.postedByEmail,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'state': state,
    'district': district,
    'title': title,
    'body': body,
    'postedAt': postedAt.toIso8601String(),
    'postedByEmail': postedByEmail,
  };

  factory DistrictNews.fromJson(Map<String, dynamic> json) => DistrictNews(
    id: json['id'] as String,
    state: json['state'] as String,
    district: json['district'] as String,
    title: json['title'] as String,
    body: json['body'] as String,
    postedAt: DateTime.parse(json['postedAt'] as String),
    postedByEmail: json['postedByEmail'] as String,
  );
}

/// A 0-5 star rating with an optional written comment and optional
/// photo, left by a signed-in user on a specific district. Mirrors
/// [DistrictNews] in shape (state + district + timestamp), but authored
/// by ordinary users rather than admins, and deletable by its own
/// author as well as by an admin.
class DistrictReview {
  final String id;
  final String state;
  final String district;
  final String authorEmail;
  final String authorName;
  final int rating; // 0-5
  final String comment;
  final UploadedDocument? image;
  final DateTime createdAt;

  DistrictReview({
    required this.id,
    required this.state,
    required this.district,
    required this.authorEmail,
    required this.authorName,
    required this.rating,
    required this.comment,
    this.image,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'state': state,
    'district': district,
    'authorEmail': authorEmail,
    'authorName': authorName,
    'rating': rating,
    'comment': comment,
    'image': image?.toJson(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory DistrictReview.fromJson(Map<String, dynamic> json) => DistrictReview(
    id: json['id'] as String,
    state: json['state'] as String,
    district: json['district'] as String,
    authorEmail: json['authorEmail'] as String,
    authorName: json['authorName'] as String,
    rating: json['rating'] as int? ?? 0,
    comment: json['comment'] as String? ?? '',
    image: json['image'] != null ? UploadedDocument.fromJson(json['image'] as Map<String, dynamic>) : null,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

/// A bug/issue reported by a user from a specific district's page - a
/// district-scoped counterpart to the general Contact & feedback form,
/// so an admin can tell at a glance which district (if any) a report
/// relates to. Submission can be anonymous, same as general feedback.
class DistrictIssueReport {
  final String id;
  final String state;
  final String district;
  final String category; // 'Bug' | 'Incorrect data' | 'Other'
  final String description;
  final String? reporterName;
  final String? reporterEmail;
  final DateTime submittedAt;
  final bool read;
  final bool resolved;

  DistrictIssueReport({
    required this.id,
    required this.state,
    required this.district,
    required this.category,
    required this.description,
    this.reporterName,
    this.reporterEmail,
    required this.submittedAt,
    this.read = false,
    this.resolved = false,
  });

  DistrictIssueReport copyWith({bool? read, bool? resolved}) => DistrictIssueReport(
    id: id,
    state: state,
    district: district,
    category: category,
    description: description,
    reporterName: reporterName,
    reporterEmail: reporterEmail,
    submittedAt: submittedAt,
    read: read ?? this.read,
    resolved: resolved ?? this.resolved,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'state': state,
    'district': district,
    'category': category,
    'description': description,
    'reporterName': reporterName,
    'reporterEmail': reporterEmail,
    'submittedAt': submittedAt.toIso8601String(),
    'read': read,
    'resolved': resolved,
  };

  factory DistrictIssueReport.fromJson(Map<String, dynamic> json) => DistrictIssueReport(
    id: json['id'] as String,
    state: json['state'] as String,
    district: json['district'] as String,
    category: json['category'] as String? ?? 'Other',
    description: json['description'] as String? ?? '',
    reporterName: json['reporterName'] as String?,
    reporterEmail: json['reporterEmail'] as String?,
    submittedAt: DateTime.parse(json['submittedAt'] as String),
    read: json['read'] as bool? ?? false,
    resolved: json['resolved'] as bool? ?? false,
  );
}

/// One partner listed in a Partnership-type business application.
class BusinessPartner {
  final String fullName;
  final String idType; // 'MyKad' | 'Passport' | 'Other'
  final String idNumber;
  final String email;
  final String phone;

  BusinessPartner({
    required this.fullName,
    required this.idType,
    required this.idNumber,
    required this.email,
    required this.phone,
  });

  Map<String, dynamic> toJson() => {
    'fullName': fullName,
    'idType': idType,
    'idNumber': idNumber,
    'email': email,
    'phone': phone,
  };

  factory BusinessPartner.fromJson(Map<String, dynamic> json) => BusinessPartner(
    fullName: json['fullName'] as String? ?? '',
    idType: json['idType'] as String? ?? 'MyKad',
    idNumber: json['idNumber'] as String? ?? '',
    email: json['email'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
  );
}

/// One parent/guardian listed on a school application. Mirrors
/// [BusinessPartner]'s "add another" pattern - a school application
/// always has at least one (Parent/Guardian 1), with more added via
/// "Add another parent/guardian".
class Guardian {
  final String fullName;
  final String relationship; // 'Father' | 'Mother' | 'Guardian' | 'Other'
  final String phone;
  final String email;
  final String occupation;

  Guardian({
    required this.fullName,
    required this.relationship,
    required this.phone,
    required this.email,
    required this.occupation,
  });

  Map<String, dynamic> toJson() => {
    'fullName': fullName,
    'relationship': relationship,
    'phone': phone,
    'email': email,
    'occupation': occupation,
  };

  factory Guardian.fromJson(Map<String, dynamic> json) => Guardian(
    fullName: json['fullName'] as String? ?? '',
    relationship: json['relationship'] as String? ?? 'Guardian',
    phone: json['phone'] as String? ?? '',
    email: json['email'] as String? ?? '',
    occupation: json['occupation'] as String? ?? '',
  );
}

/// A document attached to a school/business application - via camera,
/// gallery, or the file picker. Stores the actual file bytes
/// (base64-encoded, so it survives round-tripping through local
/// shared_preferences storage as JSON) alongside the label it was
/// attached under and its original filename, so an admin reviewing the
/// application can open and view the real file instead of just seeing
/// its name.
///
/// [base64Data] is null when the file was too large to keep in local
/// storage, or when reading its bytes failed - the filename is always
/// kept either way so the attachment still shows up in the list.
class UploadedDocument {
  final String label;
  final String fileName;
  final String? base64Data;
  final String? mimeType;

  UploadedDocument({
    required this.label,
    required this.fileName,
    this.base64Data,
    this.mimeType,
  });

  Map<String, dynamic> toJson() => {
    'label': label,
    'fileName': fileName,
    'base64Data': base64Data,
    'mimeType': mimeType,
  };

  factory UploadedDocument.fromJson(Map<String, dynamic> json) => UploadedDocument(
    label: json['label'] as String? ?? '',
    fileName: json['fileName'] as String? ?? '',
    base64Data: json['base64Data'] as String?,
    mimeType: json['mimeType'] as String?,
  );
}

/// A user-submitted application tied to a specific district: either a
/// student applying to study there (category 'school') or someone
/// registering a business there (category 'business'). Submitted from a
/// district's detail page, and reviewed from the admin dashboard.
/// Purely local, like everything else in this app - there's no backend
/// to actually process a real school placement or business registration;
/// this records the submission and its status so it can be tracked.
class ListingApplication {
  final String id;
  final String category; // 'school' or 'business'
  final String name; // applicant's full name (school) or business name
  final String subtype; // education stage (school) or business category (business)
  final String state;
  final String? district;
  final String contact; // phone or email the admin can reach the applicant on
  final String description;
  final String applicantEmail;
  final String applicantName;
  final DateTime submittedAt;
  final String status; // 'pending' | 'approved' | 'rejected'
  final String? reviewNote;
  final DateTime? reviewedAt;

  /// For school applications only: the education track the app matched
  /// (or the applicant picked, when more than one track fit) this
  /// application to, described using the district's real recorded
  /// school-count data. Null for business applications.
  final String? matchedOption;

  /// The supporting documents the applicant attached, each with its
  /// actual file bytes (see [UploadedDocument]) so an admin can open and
  /// view the real file rather than just its name.
  final List<UploadedDocument> documents;

  // --- Extended business-registration fields --------------------------
  // All optional: null/empty/false on school applications, and on any
  // business application submitted before this expanded form existed
  // (fromJson below defaults them so old saved data still loads fine).

  /// Legal business structure: 'Sole Proprietorship' | 'Partnership' |
  /// 'Private Limited Company (Sdn. Bhd.)'.
  final String? businessType;

  final String? addressLine1;
  final String? addressLine2;
  final String? addressCity;
  final String? addressState;
  final String? addressPostcode;

  final String? ownerIdType; // 'MyKad' | 'Passport' | 'Other'
  final String? ownerIdNumber;
  final String? ownerEmail;
  final String? ownerPhone;
  final String? ownerResidentialAddress;
  final String? ownerNationality; // 'Malaysian' | 'Permanent Resident' | 'Other'

  /// Only populated when [businessType] is 'Partnership'.
  final List<BusinessPartner> partners;

  final bool requiresLicence;
  final String? licenceType;
  final String? licenceNumber;
  final UploadedDocument? licenceDocument;

  final bool declarationInfoAccurate;
  final bool declarationAgreeTerms;
  final bool declarationUnderstandVerification;

  // --- Extended school-application fields ------------------------------
  // All optional: null/empty/false on business applications, and on any
  // school application submitted before this expanded form existed
  // (fromJson below defaults them so old saved data still loads fine).

  final String? studentDob;
  final String? studentGender;
  final String? studentNationality; // 'Malaysian' | 'Permanent Resident' | 'Other'
  final String? studentIdType; // 'MyKad' | 'Birth Certificate' | 'Passport' | 'Other'
  final String? studentIdNumber;
  final String? studentEmail;
  final String? studentPhone;

  /// 'Primary School' | 'Secondary School' | 'International School' |
  /// 'Private School' | 'Vocational School'.
  final String? schoolType;

  final List<Guardian> guardians;

  final String? studentAddressLine1;
  final String? studentAddressLine2;
  final String? studentAddressCity;
  final String? studentAddressState;
  final String? studentAddressPostcode;

  final String? previousSchool;
  final String? previousLevel;
  final String? previousAchievements;
  final UploadedDocument? academicResultsDocument;

  /// Only set on school applications - separate from
  /// [declarationInfoAccurate] and [declarationAgreeTerms] above, which
  /// are shared with the business form's declaration checkboxes.
  final bool declarationAuthorizedToSubmit;

  ListingApplication({
    required this.id,
    required this.category,
    required this.name,
    required this.subtype,
    required this.state,
    this.district,
    required this.contact,
    required this.description,
    required this.applicantEmail,
    required this.applicantName,
    required this.submittedAt,
    this.status = 'pending',
    this.reviewNote,
    this.reviewedAt,
    this.matchedOption,
    this.documents = const [],
    this.businessType,
    this.addressLine1,
    this.addressLine2,
    this.addressCity,
    this.addressState,
    this.addressPostcode,
    this.ownerIdType,
    this.ownerIdNumber,
    this.ownerEmail,
    this.ownerPhone,
    this.ownerResidentialAddress,
    this.ownerNationality,
    this.partners = const [],
    this.requiresLicence = false,
    this.licenceType,
    this.licenceNumber,
    this.licenceDocument,
    this.declarationInfoAccurate = false,
    this.declarationAgreeTerms = false,
    this.declarationUnderstandVerification = false,
    this.studentDob,
    this.studentGender,
    this.studentNationality,
    this.studentIdType,
    this.studentIdNumber,
    this.studentEmail,
    this.studentPhone,
    this.schoolType,
    this.guardians = const [],
    this.studentAddressLine1,
    this.studentAddressLine2,
    this.studentAddressCity,
    this.studentAddressState,
    this.studentAddressPostcode,
    this.previousSchool,
    this.previousLevel,
    this.previousAchievements,
    this.academicResultsDocument,
    this.declarationAuthorizedToSubmit = false,
  });

  /// Returns a copy with the review outcome updated - used by the admin
  /// dashboard's approve/reject/reset-to-pending actions. Every other
  /// field (including all the extended business fields) is carried
  /// through unchanged.
  ListingApplication copyWith({
    String? status,
    String? reviewNote,
    DateTime? reviewedAt,
  }) => ListingApplication(
    id: id,
    category: category,
    name: name,
    subtype: subtype,
    state: state,
    district: district,
    contact: contact,
    description: description,
    applicantEmail: applicantEmail,
    applicantName: applicantName,
    submittedAt: submittedAt,
    status: status ?? this.status,
    reviewNote: reviewNote ?? this.reviewNote,
    reviewedAt: reviewedAt ?? this.reviewedAt,
    matchedOption: matchedOption,
    documents: documents,
    businessType: businessType,
    addressLine1: addressLine1,
    addressLine2: addressLine2,
    addressCity: addressCity,
    addressState: addressState,
    addressPostcode: addressPostcode,
    ownerIdType: ownerIdType,
    ownerIdNumber: ownerIdNumber,
    ownerEmail: ownerEmail,
    ownerPhone: ownerPhone,
    ownerResidentialAddress: ownerResidentialAddress,
    ownerNationality: ownerNationality,
    partners: partners,
    requiresLicence: requiresLicence,
    licenceType: licenceType,
    licenceNumber: licenceNumber,
    licenceDocument: licenceDocument,
    declarationInfoAccurate: declarationInfoAccurate,
    declarationAgreeTerms: declarationAgreeTerms,
    declarationUnderstandVerification: declarationUnderstandVerification,
    studentDob: studentDob,
    studentGender: studentGender,
    studentNationality: studentNationality,
    studentIdType: studentIdType,
    studentIdNumber: studentIdNumber,
    studentEmail: studentEmail,
    studentPhone: studentPhone,
    schoolType: schoolType,
    guardians: guardians,
    studentAddressLine1: studentAddressLine1,
    studentAddressLine2: studentAddressLine2,
    studentAddressCity: studentAddressCity,
    studentAddressState: studentAddressState,
    studentAddressPostcode: studentAddressPostcode,
    previousSchool: previousSchool,
    previousLevel: previousLevel,
    previousAchievements: previousAchievements,
    academicResultsDocument: academicResultsDocument,
    declarationAuthorizedToSubmit: declarationAuthorizedToSubmit,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'category': category,
    'name': name,
    'subtype': subtype,
    'state': state,
    'district': district,
    'contact': contact,
    'description': description,
    'applicantEmail': applicantEmail,
    'applicantName': applicantName,
    'submittedAt': submittedAt.toIso8601String(),
    'status': status,
    'reviewNote': reviewNote,
    'reviewedAt': reviewedAt?.toIso8601String(),
    'matchedOption': matchedOption,
    'documents': documents.map((d) => d.toJson()).toList(),
    'businessType': businessType,
    'addressLine1': addressLine1,
    'addressLine2': addressLine2,
    'addressCity': addressCity,
    'addressState': addressState,
    'addressPostcode': addressPostcode,
    'ownerIdType': ownerIdType,
    'ownerIdNumber': ownerIdNumber,
    'ownerEmail': ownerEmail,
    'ownerPhone': ownerPhone,
    'ownerResidentialAddress': ownerResidentialAddress,
    'ownerNationality': ownerNationality,
    'partners': partners.map((p) => p.toJson()).toList(),
    'requiresLicence': requiresLicence,
    'licenceType': licenceType,
    'licenceNumber': licenceNumber,
    'licenceDocument': licenceDocument?.toJson(),
    'declarationInfoAccurate': declarationInfoAccurate,
    'declarationAgreeTerms': declarationAgreeTerms,
    'declarationUnderstandVerification': declarationUnderstandVerification,
    'studentDob': studentDob,
    'studentGender': studentGender,
    'studentNationality': studentNationality,
    'studentIdType': studentIdType,
    'studentIdNumber': studentIdNumber,
    'studentEmail': studentEmail,
    'studentPhone': studentPhone,
    'schoolType': schoolType,
    'guardians': guardians.map((g) => g.toJson()).toList(),
    'studentAddressLine1': studentAddressLine1,
    'studentAddressLine2': studentAddressLine2,
    'studentAddressCity': studentAddressCity,
    'studentAddressState': studentAddressState,
    'studentAddressPostcode': studentAddressPostcode,
    'previousSchool': previousSchool,
    'previousLevel': previousLevel,
    'previousAchievements': previousAchievements,
    'academicResultsDocument': academicResultsDocument?.toJson(),
    'declarationAuthorizedToSubmit': declarationAuthorizedToSubmit,
  };

  factory ListingApplication.fromJson(Map<String, dynamic> json) => ListingApplication(
    id: json['id'] as String,
    category: json['category'] as String,
    name: json['name'] as String,
    subtype: json['subtype'] as String,
    state: json['state'] as String,
    district: json['district'] as String?,
    contact: json['contact'] as String,
    description: json['description'] as String,
    applicantEmail: json['applicantEmail'] as String,
    applicantName: json['applicantName'] as String,
    submittedAt: DateTime.parse(json['submittedAt'] as String),
    status: json['status'] as String? ?? 'pending',
    reviewNote: json['reviewNote'] as String?,
    reviewedAt: json['reviewedAt'] != null ? DateTime.parse(json['reviewedAt'] as String) : null,
    matchedOption: json['matchedOption'] as String?,
    documents: (json['documents'] as List<dynamic>?)
        ?.map((e) => e is String
            // Backward compatibility with applications saved before
            // documents stored real file bytes - old entries are plain
            // strings like "Label (attached: filename)".
            ? UploadedDocument(label: e, fileName: e)
            : UploadedDocument.fromJson(e as Map<String, dynamic>))
        .toList() ?? const [],
    businessType: json['businessType'] as String?,
    addressLine1: json['addressLine1'] as String?,
    addressLine2: json['addressLine2'] as String?,
    addressCity: json['addressCity'] as String?,
    addressState: json['addressState'] as String?,
    addressPostcode: json['addressPostcode'] as String?,
    ownerIdType: json['ownerIdType'] as String?,
    ownerIdNumber: json['ownerIdNumber'] as String?,
    ownerEmail: json['ownerEmail'] as String?,
    ownerPhone: json['ownerPhone'] as String?,
    ownerResidentialAddress: json['ownerResidentialAddress'] as String?,
    ownerNationality: json['ownerNationality'] as String?,
    partners: (json['partners'] as List<dynamic>?)
        ?.map((e) => BusinessPartner.fromJson(e as Map<String, dynamic>))
        .toList() ?? const [],
    requiresLicence: json['requiresLicence'] as bool? ?? false,
    licenceType: json['licenceType'] as String?,
    licenceNumber: json['licenceNumber'] as String?,
    licenceDocument: json['licenceDocument'] != null
        ? UploadedDocument.fromJson(json['licenceDocument'] as Map<String, dynamic>)
        : null,
    declarationInfoAccurate: json['declarationInfoAccurate'] as bool? ?? false,
    declarationAgreeTerms: json['declarationAgreeTerms'] as bool? ?? false,
    declarationUnderstandVerification: json['declarationUnderstandVerification'] as bool? ?? false,
    studentDob: json['studentDob'] as String?,
    studentGender: json['studentGender'] as String?,
    studentNationality: json['studentNationality'] as String?,
    studentIdType: json['studentIdType'] as String?,
    studentIdNumber: json['studentIdNumber'] as String?,
    studentEmail: json['studentEmail'] as String?,
    studentPhone: json['studentPhone'] as String?,
    schoolType: json['schoolType'] as String?,
    guardians: (json['guardians'] as List<dynamic>?)
        ?.map((e) => Guardian.fromJson(e as Map<String, dynamic>))
        .toList() ?? const [],
    studentAddressLine1: json['studentAddressLine1'] as String?,
    studentAddressLine2: json['studentAddressLine2'] as String?,
    studentAddressCity: json['studentAddressCity'] as String?,
    studentAddressState: json['studentAddressState'] as String?,
    studentAddressPostcode: json['studentAddressPostcode'] as String?,
    previousSchool: json['previousSchool'] as String?,
    previousLevel: json['previousLevel'] as String?,
    previousAchievements: json['previousAchievements'] as String?,
    academicResultsDocument: json['academicResultsDocument'] != null
        ? UploadedDocument.fromJson(json['academicResultsDocument'] as Map<String, dynamic>)
        : null,
    declarationAuthorizedToSubmit: json['declarationAuthorizedToSubmit'] as bool? ?? false,
  );
}





