import 'package:flutter/material.dart';
import '../models.dart';
import '../services/data_service.dart';
import '../services/local_store_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'district_detail_screen.dart';
import 'my_submissions_screen.dart';

/// Everything UrbanEx can notify someone about: an admin's reply to
/// their feedback, a decision on their school/business application, or
/// news posted for a district they've favorited. Visible to guests too
/// (district news isn't tied to an account - see NotificationEntry).
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationEntry> _notifications = [];
  String? _currentEmail;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    LocalStoreService.notificationsRevision.addListener(_load);
    LocalStoreService.currentUserRevision.addListener(_load);
  }

  @override
  void dispose() {
    LocalStoreService.notificationsRevision.removeListener(_load);
    LocalStoreService.currentUserRevision.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final email = await LocalStoreService.instance.getCurrentUserEmail();
    final notifications = await LocalStoreService.instance.getNotificationsFor(email);
    if (!mounted) return;
    setState(() {
      _currentEmail = email;
      _notifications = notifications;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n.read).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: () => LocalStoreService.instance.markAllNotificationsRead(_currentEmail),
              child: const Text('Mark all read'),
            ),
        ],
      ),
      bottomNavigationBar: const GlobalBottomNav(),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            "Nothing here yet. You'll see admin replies, application decisions, and news for districts "
                "you've favorited show up in this list.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ),
      )
          : RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: _notifications.map((n) => _NotificationTile(entry: n, onTap: () => _handleTap(n))).toList(),
        ),
      ),
    );
  }

  Future<void> _handleTap(NotificationEntry entry) async {
    if (!entry.read) {
      await LocalStoreService.instance.markNotificationRead(entry.id, true, viewerEmail: _currentEmail);
    }
    if (!mounted) return;

    switch (entry.type) {
      case 'feedback_reply':
        _showReplyDetail(entry);
        break;
      case 'application_status':
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MySubmissionsScreen()));
        break;
      case 'district_news':
        _openDistrict(entry);
        break;
    }
  }

  Future<void> _showReplyDetail(NotificationEntry entry) async {
    FeedbackEntry? original;
    if (entry.relatedFeedbackId != null) {
      final all = await LocalStoreService.instance.getFeedback();
      for (final f in all) {
        if (f.id == entry.relatedFeedbackId) {
          original = f;
          break;
        }
      }
    }
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reply to your feedback'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (original != null) ...[
              Text('Your message', style: TextStyle(color: Colors.grey.shade500, fontSize: 11.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(original.message, style: const TextStyle(fontSize: 13.5)),
              const SizedBox(height: 14),
            ],
            Text('Reply', style: TextStyle(color: Colors.grey.shade500, fontSize: 11.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(entry.body, style: const TextStyle(fontSize: 13.5)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _openDistrict(NotificationEntry entry) async {
    if (entry.relatedDistrictState == null || entry.relatedDistrictName == null) return;

    // If this notification is linked to a specific news post, make sure
    // that post still exists before treating the notification as valid.
    // Deleting a post also deletes its notification (see NewsService),
    // so this only fires for notifications that predate that link, or
    // for one that somehow survived a delete - either way, self-heal
    // instead of sending the user to a district page with nothing to
    // show for it.
    if (entry.relatedNewsId != null) {
      final news = await LocalStoreService.instance.getNewsForDistrict(entry.relatedDistrictState!, entry.relatedDistrictName!);
      final stillExists = news.any((n) => n.id == entry.relatedNewsId);
      if (!stillExists) {
        await LocalStoreService.instance.deleteNotification(entry.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This update was removed by an admin')),
        );
        return;
      }
    }

    final districts = await DataService.instance.getDistricts();
    DistrictData? match;
    for (final d in districts) {
      if (d.state == entry.relatedDistrictState && d.district == entry.relatedDistrictName) {
        match = d;
        break;
      }
    }
    if (!mounted) return;
    if (match == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't find that district")));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => DistrictDetailScreen(district: match!)));
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationEntry entry;
  final VoidCallback onTap;
  const _NotificationTile({required this.entry, required this.onTap});

  IconData get _icon {
    switch (entry.type) {
      case 'feedback_reply':
        return Icons.reply_outlined;
      case 'application_status':
        return Icons.assignment_turned_in_outlined;
      case 'district_news':
        return Icons.newspaper_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  String get _relativeTime {
    final diff = DateTime.now().difference(entry.createdAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        color: entry.read ? null : AppColors.brand.withOpacity(0.04),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: entry.read ? Colors.grey.shade200 : AppColors.brand.withOpacity(0.15),
            child: Icon(_icon, color: entry.read ? Colors.grey.shade600 : AppColors.brandDark),
          ),
          title: Text(entry.title, style: TextStyle(fontWeight: entry.read ? FontWeight.w500 : FontWeight.bold)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.body, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(_relativeTime, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ],
          ),
          isThreeLine: true,
          trailing: entry.read
              ? const Icon(Icons.chevron_right)
              : Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.brand, shape: BoxShape.circle)),
          onTap: onTap,
        ),
      ),
    );
  }
}


