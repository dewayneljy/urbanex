import '../models.dart';
import 'auth_service.dart';
import 'local_store_service.dart';

/// Handles an admin posting, editing, or deleting a district news
/// update, and (for a new post) deciding whether it needs to notify
/// anyone. Mirrors the shape of ApplicationService: local-only,
/// admin-gated, never throws across the UI boundary.
class NewsService {
  NewsService._();
  static final NewsService instance = NewsService._();

  Future<AuthResult> postNews({
    required String state,
    required String district,
    required String title,
    required String body,
  }) async {
    try {
      final gate = await _requireAdmin();
      if (gate != null) return gate;
      if (title.trim().isEmpty || body.trim().isEmpty) {
        return const AuthResult.fail('Please fill in both a title and a message.');
      }
      final admin = await LocalStoreService.instance.getCurrentUser();
      if (admin == null) {
        return const AuthResult.fail('Only an admin can post district news.');
      }

      final news = DistrictNews(
        id: '${DateTime.now().microsecondsSinceEpoch}',
        state: state,
        district: district,
        title: title.trim(),
        body: body.trim(),
        postedAt: DateTime.now(),
        postedByEmail: admin.email,
      );
      await LocalStoreService.instance.addDistrictNews(news);

      // District news reaches whoever has this district favorited on
      // this device. Favorites in UrbanEx are a single per-device list,
      // not tied to one signed-in account, so there's no way to know
      // which specific account "did" the favoriting - everyone who uses
      // this device shares the same favorites. What we *can* make
      // independent is each viewer's notification: rather than one
      // shared entry everyone sees (and which would go stale/inconsistent
      // once any one of them reads or the app tries to track read state
      // per person on a single record), we deliver a separate,
      // identically-worded notification to the guest identity and to
      // every registered account. Each copy has its own id, so reading,
      // marking read, or (if a delete affordance is ever added) removing
      // one has no effect on anyone else's copy.
      final isFavorited = await LocalStoreService.instance.isFavorite('district:$state:$district');
      if (isFavorited) {
        final accounts = await LocalStoreService.instance.getUsers();
        final recipients = <String>{NotificationEntry.guestViewerKey, ...accounts.map((a) => a.email)};
        final now = DateTime.now();
        await LocalStoreService.instance.addNotifications([
          for (final recipient in recipients)
            NotificationEntry(
              id: '${now.microsecondsSinceEpoch}-news-$recipient',
              type: 'district_news',
              title: 'News for $district',
              body: news.title,
              createdAt: now,
              recipientEmail: recipient,
              relatedDistrictState: state,
              relatedDistrictName: district,
              relatedNewsId: news.id,
            ),
        ]);
      }

      return const AuthResult.ok();
    } catch (_) {
      return const AuthResult.fail('Something went wrong posting this update. Please try again.');
    }
  }

  /// Edits an existing news entry in place (title, body, and/or which
  /// district it's for). Doesn't re-send a favorite notification - this
  /// is a correction to something already posted, not a new update -
  /// but it does update any notification already sent for this post, so
  /// it doesn't go on showing the old, now-wrong, title/body/district.
  Future<AuthResult> updateNews({
    required DistrictNews existing,
    required String state,
    required String district,
    required String title,
    required String body,
  }) async {
    try {
      final gate = await _requireAdmin();
      if (gate != null) return gate;
      if (title.trim().isEmpty || body.trim().isEmpty) {
        return const AuthResult.fail('Please fill in both a title and a message.');
      }

      final updated = DistrictNews(
        id: existing.id,
        state: state,
        district: district,
        title: title.trim(),
        body: body.trim(),
        postedAt: existing.postedAt,
        postedByEmail: existing.postedByEmail,
      );
      await LocalStoreService.instance.updateDistrictNews(updated);
      await LocalStoreService.instance.updateNotificationsForNews(
        existing.id,
        title: updated.title,
        body: updated.body,
        state: state,
        district: district,
      );
      return const AuthResult.ok();
    } catch (_) {
      return const AuthResult.fail('Something went wrong saving this update. Please try again.');
    }
  }

  /// Permanently removes a news entry, along with any notification that
  /// was sent for it - otherwise that notification would sit there
  /// unread forever, and tapping it would lead to a post that's gone.
  Future<AuthResult> deleteNews(String id) async {
    try {
      final gate = await _requireAdmin();
      if (gate != null) return gate;
      await LocalStoreService.instance.deleteDistrictNews(id);
      await LocalStoreService.instance.deleteNotificationsForNews(id);
      return const AuthResult.ok();
    } catch (_) {
      return const AuthResult.fail('Something went wrong deleting this update. Please try again.');
    }
  }

  /// Returns a failure [AuthResult] if the signed-in account isn't an
  /// admin, or null to proceed.
  Future<AuthResult?> _requireAdmin() async {
    if (!await AuthService.instance.currentUserIsAdmin()) {
      return const AuthResult.fail('Only an admin can manage district news.');
    }
    return null;
  }
}


