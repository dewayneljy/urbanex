import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models.dart';
import 'supabase_config.dart';

/// Device-only preferences still live in SharedPreferences (dark mode,
/// onboarding, text scale, first-launch date, "show top rated" toggle) -
/// there's nothing to sync for those, they're per-install settings.
///
/// Everything that used to be "local data" (accounts, favorites,
/// applications, feedback, notifications, district news/reviews/issues)
/// now lives in Supabase (see supabase/schema.sql) so it's shared across
/// devices and accounts instead of being stuck on one phone. The public
/// method names/signatures here are kept the same as before on purpose,
/// so every screen that already calls LocalStoreService keeps working
/// unmodified.
class LocalStoreService {
  LocalStoreService._() {
    // Keeps Profile's "signed in as ..." UI (and anything else watching
    // currentUserRevision) in sync with Supabase's own session changes,
    // now that sign-in/out is handled by supabase.auth directly instead
    // of a local setCurrentUser() call.
    supabase.auth.onAuthStateChange.listen((_) {
      currentUserRevision.value++;
    });
  }
  static final LocalStoreService instance = LocalStoreService._();

  static const _kDarkMode = 'urbanex_dark_mode';
  static const _kIdentity = 'urbanex_identity';
  static const _kOnboarded = 'urbanex_onboarded';
  static const _kFirstLaunch = 'urbanex_first_launch';
  static const _kTextScale = 'urbanex_text_scale';
  static const _kShowTopRated = 'urbanex_show_top_rated';

  static final ValueNotifier<int> homeConfigRevision = ValueNotifier<int>(0);
  static final ValueNotifier<int> favoritesRevision = ValueNotifier<int>(0);
  static final ValueNotifier<int> identityRevision = ValueNotifier<int>(0);
  static final ValueNotifier<int> currentUserRevision = ValueNotifier<int>(0);
  static final ValueNotifier<int> usersRevision = ValueNotifier<int>(0);
  static final ValueNotifier<int> applicationsRevision = ValueNotifier<int>(0);
  static final ValueNotifier<int> feedbackRevision = ValueNotifier<int>(0);
  static final ValueNotifier<int> notificationsRevision = ValueNotifier<int>(0);
  static final ValueNotifier<int> districtNewsRevision = ValueNotifier<int>(0);
  static final ValueNotifier<int> districtReviewsRevision = ValueNotifier<int>(0);
  static final ValueNotifier<int> districtIssuesRevision = ValueNotifier<int>(0);

  // --- Favorites (Supabase) --------------------------------------------
  // Now scoped to the signed-in account (favorites.user_id) instead of
  // being one shared per-device list. Favoriting requires being signed
  // in - screens that call toggleFavorite/isFavorite while signed out
  // should prompt sign-in first (see AuthScreen), the same way applying
  // to a school/business already does.

  Future<List<FavoriteEntry>> getFavorites() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return [];
    final rows = await supabase.from('favorites').select().eq('user_id', uid);
    return (rows as List).map((r) => FavoriteEntry(
      type: r['fav_type'] as String,
      state: r['state'] as String,
      district: r['district'] as String?,
      score: (r['score'] as num).toDouble(),
    )).toList();
  }

  (String, String, String?) _parseFavoriteId(String id) {
    if (id.startsWith('state:')) return ('state', id.substring(6), null);
    final rest = id.substring('district:'.length);
    final sep = rest.indexOf(':');
    return ('district', rest.substring(0, sep), rest.substring(sep + 1));
  }

  Future<void> toggleFavorite(FavoriteEntry entry) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('Sign in to save favorites.');
    }
    var query = supabase
        .from('favorites')
        .select('id')
        .eq('user_id', uid)
        .eq('fav_type', entry.type)
        .eq('state', entry.state);
    query = entry.district == null ? query.isFilter('district', null) : query.eq('district', entry.district as Object);
    final existing = await query.maybeSingle();

    if (existing != null) {
      await supabase.from('favorites').delete().eq('id', existing['id']);
    } else {
      await supabase.from('favorites').insert({
        'user_id': uid,
        'fav_type': entry.type,
        'state': entry.state,
        'district': entry.district,
        'score': entry.score,
      });
    }
    favoritesRevision.value++;
  }

  Future<bool> isFavorite(String id) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return false;
    final (type, state, district) = _parseFavoriteId(id);
    var query = supabase
        .from('favorites')
        .select('id')
        .eq('user_id', uid)
        .eq('fav_type', type)
        .eq('state', state);
    query = district == null ? query.isFilter('district', null) : query.eq('district', district as Object);
    final existing = await query.maybeSingle();
    return existing != null;
  }

  Future<void> removeFavorite(String id) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    final (type, state, district) = _parseFavoriteId(id);
    var query = supabase.from('favorites').delete().eq('user_id', uid).eq('fav_type', type).eq('state', state);
    query = district == null ? query.isFilter('district', null) : query.eq('district', district as Object);
    await query;
    favoritesRevision.value++;
  }

  Future<void> clearAllFavorites() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    await supabase.from('favorites').delete().eq('user_id', uid);
    favoritesRevision.value++;
  }

  // --- Device-only preferences (unchanged, SharedPreferences) ----------

  Future<bool> getDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kDarkMode) ?? false;
  }

  Future<void> setDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDarkMode, value);
  }

  Future<String?> getIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kIdentity);
  }

  Future<void> setIdentity(String identity) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kIdentity, identity);
    await prefs.setBool(_kOnboarded, true);
    identityRevision.value++;
  }

  Future<bool> hasOnboarded() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kOnboarded) ?? false;
  }

  Future<void> clearIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kIdentity);
    identityRevision.value++;
  }

  Future<DateTime> getOrSetFirstLaunchDate() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_kFirstLaunch);
    if (existing != null) return DateTime.parse(existing);
    final now = DateTime.now();
    await prefs.setString(_kFirstLaunch, now.toIso8601String());
    return now;
  }

  Future<double> getTextScale() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_kTextScale) ?? 1.0;
  }

  Future<void> setTextScale(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kTextScale, value);
  }

  Future<bool> getShowTopRated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kShowTopRated) ?? true;
  }

  Future<void> setShowTopRated(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kShowTopRated, value);
    homeConfigRevision.value++;
  }

  // --- Accounts (Supabase Auth + profiles) ------------------------------
  // See AuthService for register/login/logout, which now talk to
  // supabase.auth directly. These remain for admin listing/management
  // and for "who's signed in right now" lookups used across the app.

  UserAccount _userFromRow(Map<String, dynamic> row) => UserAccount(
    email: row['email'] as String,
    name: row['name'] as String,
    passwordHash: '', // Supabase Auth owns credentials now - not stored here.
    salt: '',
    createdAt: DateTime.parse(row['created_at'] as String),
    isAdmin: row['is_admin'] as bool? ?? false,
  );

  Future<List<UserAccount>> getUsers() async {
    final rows = await supabase.from('profiles').select();
    return (rows as List).map((r) => _userFromRow(r)).toList();
  }

  /// Updates an existing profile row (used by admin actions like
  /// toggling admin status). Creating a profile happens at registration
  /// time in AuthService, not here.
  Future<void> saveUser(UserAccount account) async {
    await supabase
        .from('profiles')
        .update({'name': account.name, 'is_admin': account.isAdmin})
        .eq('email', account.email);
    usersRevision.value++;
  }

  /// Deletes the profile row for [email]. NOTE: this does not remove the
  /// underlying Supabase Auth account - deleting an auth user requires
  /// the service_role key (a Supabase Edge Function), which a client-only
  /// app can't call safely. The person could still technically sign back
  /// in, just without a profile; treat this as "remove from directory",
  /// not a full account deletion, until an Edge Function is added.
  Future<void> deleteUser(String email) async {
    await supabase.from('profiles').delete().eq('email', email);
    usersRevision.value++;
  }

  Future<String?> getCurrentUserEmail() async => supabase.auth.currentUser?.email;

  Future<UserAccount?> getCurrentUser() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return null;
    final row = await supabase.from('profiles').select().eq('id', uid).maybeSingle();
    if (row == null) return null;
    return _userFromRow(row);
  }

  // --- Listing applications (Supabase) ----------------------------------
  // Row Level Security already scopes what a non-admin sees to their own
  // applications, and gives an admin everything - so getApplications()
  // needs no client-side filtering either way.

  Future<List<ListingApplication>> getApplications() async {
    final rows = await supabase.from('applications').select().order('submitted_at', ascending: false);
    return (rows as List).map((r) => ListingApplication.fromJson(r['payload'] as Map<String, dynamic>)).toList();
  }

  Future<void> saveApplication(ListingApplication application) async {
    final existing = await supabase.from('applications').select('id').eq('id', application.id).maybeSingle();

    final row = <String, dynamic>{
      'id': application.id,
      'category': application.category,
      'applicant_email': application.applicantEmail,
      'applicant_name': application.applicantName,
      'name': application.name,
      'state': application.state,
      'district': application.district,
      'status': application.status,
      'review_note': application.reviewNote,
      'reviewed_at': application.reviewedAt?.toIso8601String(),
      'submitted_at': application.submittedAt.toIso8601String(),
      'payload': application.toJson(),
    };

    if (existing == null) {
      // New submission - RLS requires applicant_id == the submitter.
      row['applicant_id'] = supabase.auth.currentUser!.id;
      await supabase.from('applications').insert(row);
    } else {
      // Status/note update (admin action) - applicant_id is left as-is.
      await supabase.from('applications').update(row).eq('id', application.id);
    }
    applicationsRevision.value++;
  }

  // --- Feedback (Supabase) -----------------------------------------------

  FeedbackEntry _feedbackFromRow(Map<String, dynamic> r) => FeedbackEntry(
    id: r['id'] as String,
    category: r['category'] as String,
    name: r['name'] as String?,
    email: r['email'] as String?,
    message: r['message'] as String,
    submittedAt: DateTime.parse(r['submitted_at'] as String),
    read: r['read'] as bool? ?? false,
    submittedByEmail: r['submitted_by_email'] as String?,
    adminReply: r['admin_reply'] as String?,
    repliedAt: r['replied_at'] != null ? DateTime.parse(r['replied_at'] as String) : null,
    repliedByEmail: r['replied_by_email'] as String?,
  );

  Future<List<FeedbackEntry>> getFeedback() async {
    final rows = await supabase.from('feedback').select().order('submitted_at', ascending: false);
    return (rows as List).map((r) => _feedbackFromRow(r)).toList();
  }

  Future<void> submitFeedback(FeedbackEntry entry) async {
    await supabase.from('feedback').insert({
      'id': entry.id,
      'category': entry.category,
      'name': entry.name,
      'email': entry.email,
      'message': entry.message,
      'submitted_at': entry.submittedAt.toIso8601String(),
      'read': entry.read,
      'submitted_by': supabase.auth.currentUser?.id,
      'submitted_by_email': entry.submittedByEmail,
    });
    feedbackRevision.value++;
  }

  Future<void> setFeedbackRead(String id, bool read) async {
    await supabase.from('feedback').update({'read': read}).eq('id', id);
    feedbackRevision.value++;
  }

  Future<void> replyToFeedback(String id, String reply, String repliedByEmail) async {
    await supabase.from('feedback').update({
      'admin_reply': reply,
      'replied_at': DateTime.now().toIso8601String(),
      'replied_by_email': repliedByEmail,
    }).eq('id', id);
    feedbackRevision.value++;
  }

  Future<void> deleteFeedback(String id) async {
    await supabase.from('feedback').delete().eq('id', id);
    feedbackRevision.value++;
  }

  // --- Notifications (Supabase) -------------------------------------------
  // Every notification now has a real recipient_id, and RLS already
  // limits what comes back to "mine, or everything if I'm an admin" - so
  // there's no more device-wide/guest-viewer case to reconcile client-side.

  NotificationEntry _notificationFromRow(Map<String, dynamic> r) => NotificationEntry(
    id: r['id'] as String,
    type: r['type'] as String,
    title: r['title'] as String,
    body: r['body'] as String,
    createdAt: DateTime.parse(r['created_at'] as String),
    read: r['read'] as bool? ?? false,
    recipientEmail: r['recipient_email'] as String?,
    relatedFeedbackId: r['related_feedback_id'] as String?,
    relatedApplicationId: r['related_application_id'] as String?,
    relatedDistrictState: r['related_district_state'] as String?,
    relatedDistrictName: r['related_district_name'] as String?,
    relatedNewsId: r['related_news_id'] as String?,
    applicationStatus: r['application_status'] as String?,
  );

  Future<List<NotificationEntry>> getAllNotifications() async {
    final rows = await supabase.from('notifications').select().order('created_at', ascending: false);
    return (rows as List).map((r) => _notificationFromRow(r)).toList();
  }

  /// [currentEmail] is kept only for signature compatibility with
  /// existing call sites - RLS already scopes rows to the signed-in
  /// account (or to everything, for an admin), so no client-side
  /// filtering by email is needed anymore. Returns nothing for a
  /// signed-out viewer, since notifications require a real account now.
  Future<List<NotificationEntry>> getNotificationsFor(String? currentEmail) async {
    if (supabase.auth.currentUser == null) return [];
    return getAllNotifications();
  }

  Future<void> _insertNotificationRow(NotificationEntry entry) async {
    // recipientEmail carries the target account's email; we need their
    // auth id for the FK/RLS check, so look their profile up by email.
    final recipient = await supabase.from('profiles').select('id').eq('email', entry.recipientEmail as String).maybeSingle();
    if (recipient == null) return; // no matching account - nothing to deliver
    await supabase.from('notifications').insert({
      'id': entry.id,
      'type': entry.type,
      'title': entry.title,
      'body': entry.body,
      'created_at': entry.createdAt.toIso8601String(),
      'read': entry.read,
      'recipient_id': recipient['id'],
      'recipient_email': entry.recipientEmail,
      'related_feedback_id': entry.relatedFeedbackId,
      'related_application_id': entry.relatedApplicationId,
      'related_district_state': entry.relatedDistrictState,
      'related_district_name': entry.relatedDistrictName,
      'related_news_id': entry.relatedNewsId,
      'application_status': entry.applicationStatus,
    });
  }

  Future<void> addNotification(NotificationEntry entry) async {
    await _insertNotificationRow(entry);
    notificationsRevision.value++;
  }

  Future<void> addNotifications(List<NotificationEntry> entries) async {
    for (final entry in entries) {
      await _insertNotificationRow(entry);
    }
    if (entries.isNotEmpty) notificationsRevision.value++;
  }

  Future<void> markNotificationRead(String id, bool read, {String? viewerEmail}) async {
    await supabase.from('notifications').update({'read': read}).eq('id', id);
    notificationsRevision.value++;
  }

  Future<void> markAllNotificationsRead(String? currentEmail) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    await supabase.from('notifications').update({'read': true}).eq('recipient_id', uid);
    notificationsRevision.value++;
  }

  Future<void> deleteNotification(String id) async {
    await supabase.from('notifications').delete().eq('id', id);
    notificationsRevision.value++;
  }

  Future<void> deleteAllNotificationsFor(String? currentEmail) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    await supabase.from('notifications').delete().eq('recipient_id', uid);
    notificationsRevision.value++;
  }

  Future<void> deleteNotificationsForNews(String newsId) async {
    await supabase.from('notifications').delete().eq('related_news_id', newsId);
    notificationsRevision.value++;
  }

  Future<void> updateNotificationsForNews(
    String newsId, {
    required String title,
    required String body,
    required String state,
    required String district,
  }) async {
    await supabase.from('notifications').update({
      'title': 'News for $district',
      'body': title,
      'related_district_state': state,
      'related_district_name': district,
    }).eq('related_news_id', newsId);
    notificationsRevision.value++;
  }

  // --- District news (Supabase) -------------------------------------------
  // Sample posts are seeded once via supabase/schema.sql (an admin-only
  // insert would fail RLS if attempted from the client on first launch),
  // so this just reads/writes the shared table.

  DistrictNews _newsFromRow(Map<String, dynamic> r) => DistrictNews(
    id: r['id'] as String,
    state: r['state'] as String,
    district: r['district'] as String,
    title: r['title'] as String,
    body: r['body'] as String,
    postedAt: DateTime.parse(r['posted_at'] as String),
    postedByEmail: r['posted_by_email'] as String,
  );

  Future<List<DistrictNews>> getDistrictNews() async {
    final rows = await supabase.from('district_news').select().order('posted_at', ascending: false);
    return (rows as List).map((r) => _newsFromRow(r)).toList();
  }

  Future<List<DistrictNews>> getNewsForDistrict(String state, String district) async {
    final rows = await supabase
        .from('district_news')
        .select()
        .eq('state', state)
        .eq('district', district)
        .order('posted_at', ascending: false);
    return (rows as List).map((r) => _newsFromRow(r)).toList();
  }

  Future<void> addDistrictNews(DistrictNews news) async {
    await supabase.from('district_news').insert({
      'id': news.id,
      'state': news.state,
      'district': news.district,
      'title': news.title,
      'body': news.body,
      'posted_at': news.postedAt.toIso8601String(),
      'posted_by': supabase.auth.currentUser?.id,
      'posted_by_email': news.postedByEmail,
    });
    districtNewsRevision.value++;
  }

  Future<void> updateDistrictNews(DistrictNews news) async {
    await supabase.from('district_news').update({
      'state': news.state,
      'district': news.district,
      'title': news.title,
      'body': news.body,
    }).eq('id', news.id);
    districtNewsRevision.value++;
  }

  Future<void> deleteDistrictNews(String id) async {
    await supabase.from('district_news').delete().eq('id', id);
    districtNewsRevision.value++;
  }

  // --- District reviews (Supabase) -----------------------------------------

  DistrictReview _reviewFromRow(Map<String, dynamic> r) => DistrictReview(
    id: r['id'] as String,
    state: r['state'] as String,
    district: r['district'] as String,
    authorEmail: r['author_email'] as String,
    authorName: r['author_name'] as String,
    rating: r['rating'] as int? ?? 0,
    comment: r['comment'] as String? ?? '',
    image: r['image'] != null ? UploadedDocument.fromJson(r['image'] as Map<String, dynamic>) : null,
    createdAt: DateTime.parse(r['created_at'] as String),
  );

  Future<List<DistrictReview>> getDistrictReviews() async {
    final rows = await supabase.from('district_reviews').select().order('created_at', ascending: false);
    return (rows as List).map((r) => _reviewFromRow(r)).toList();
  }

  Future<List<DistrictReview>> getReviewsForDistrict(String state, String district) async {
    final rows = await supabase
        .from('district_reviews')
        .select()
        .eq('state', state)
        .eq('district', district)
        .order('created_at', ascending: false);
    return (rows as List).map((r) => _reviewFromRow(r)).toList();
  }

  Future<void> addDistrictReview(DistrictReview review) async {
    await supabase.from('district_reviews').insert({
      'id': review.id,
      'state': review.state,
      'district': review.district,
      'author_id': supabase.auth.currentUser!.id,
      'author_email': review.authorEmail,
      'author_name': review.authorName,
      'rating': review.rating,
      'comment': review.comment,
      'image': review.image?.toJson(),
      'created_at': review.createdAt.toIso8601String(),
    });
    districtReviewsRevision.value++;
  }

  Future<void> deleteDistrictReview(String id) async {
    await supabase.from('district_reviews').delete().eq('id', id);
    districtReviewsRevision.value++;
  }

  // --- District issue reports (Supabase) ------------------------------------

  DistrictIssueReport _issueFromRow(Map<String, dynamic> r) => DistrictIssueReport(
    id: r['id'] as String,
    state: r['state'] as String,
    district: r['district'] as String,
    category: r['category'] as String? ?? 'Other',
    description: r['description'] as String? ?? '',
    reporterName: r['reporter_name'] as String?,
    reporterEmail: r['reporter_email'] as String?,
    submittedAt: DateTime.parse(r['submitted_at'] as String),
    read: r['read'] as bool? ?? false,
    resolved: r['resolved'] as bool? ?? false,
  );

  Future<List<DistrictIssueReport>> getDistrictIssueReports() async {
    final rows = await supabase.from('district_issues').select().order('submitted_at', ascending: false);
    return (rows as List).map((r) => _issueFromRow(r)).toList();
  }

  Future<void> submitDistrictIssueReport(DistrictIssueReport report) async {
    await supabase.from('district_issues').insert({
      'id': report.id,
      'state': report.state,
      'district': report.district,
      'category': report.category,
      'description': report.description,
      'reporter_name': report.reporterName,
      'reporter_email': report.reporterEmail,
      'reporter_id': supabase.auth.currentUser?.id,
      'submitted_at': report.submittedAt.toIso8601String(),
      'read': report.read,
      'resolved': report.resolved,
    });
    districtIssuesRevision.value++;
  }

  Future<void> setDistrictIssueReportRead(String id, bool read) async {
    await supabase.from('district_issues').update({'read': read}).eq('id', id);
    districtIssuesRevision.value++;
  }

  Future<void> setDistrictIssueReportResolved(String id, bool resolved) async {
    await supabase.from('district_issues').update({'resolved': resolved, 'read': true}).eq('id', id);
    districtIssuesRevision.value++;
  }

  Future<void> deleteDistrictIssueReport(String id) async {
    await supabase.from('district_issues').delete().eq('id', id);
    districtIssuesRevision.value++;
  }
}
