import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models.dart';
import '../services/application_service.dart';
import '../services/auth_service.dart';
import '../services/local_store_service.dart';
import '../services/nav_service.dart';
import '../static_geo_data.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'admin_screen.dart';
import '../services/auth_screen.dart';
import 'my_submissions_screen.dart';
import 'notifications_screen.dart';

class _IdentityInfo {
  final IconData icon;
  final String subtitle;
  final String description;
  const _IdentityInfo(this.icon, this.subtitle, this.description);
}

const Map<String, _IdentityInfo> _identityInfo = {
  'Student': _IdentityInfo(
    Icons.school_outlined,
    'University, college or school',
    "Your home screen prioritizes finding great places to study, using real school-count data alongside income and safety.",
  ),
  'Professional': _IdentityInfo(
    Icons.work_outline,
    'Employed or working adult',
    'Your home screen prioritizes overall livability — housing affordability, safety, and infrastructure.',
  ),
  'Business Owner': _IdentityInfo(
    Icons.apartment_outlined,
    'Entrepreneur or self-employed',
    'Your home screen prioritizes finding strong locations to open or grow a business.',
  ),
  'Other': _IdentityInfo(
    Icons.groups_outlined,
    'Freelance, retired or exploring',
    'Your home screen shows a balanced mix of every UrbanEx feature.',
  ),
};

/// The Profile tab - identity, quick stats, and account-level actions.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _identity;
  int _favoritesCount = 0;
  DateTime? _firstLaunch;
  bool _loading = true;
  UserAccount? _account;
  int _pendingSubmissions = 0;
  int _unreadNotifications = 0;

  int get _trackedDistrictCount => kDistrictsByState.values.fold(0, (a, b) => a + b.length);

  @override
  void initState() {
    super.initState();
    _load();
    LocalStoreService.identityRevision.addListener(_load);
    LocalStoreService.favoritesRevision.addListener(_load);
    LocalStoreService.currentUserRevision.addListener(_load);
    LocalStoreService.applicationsRevision.addListener(_load);
    LocalStoreService.notificationsRevision.addListener(_load);
  }

  @override
  void dispose() {
    LocalStoreService.identityRevision.removeListener(_load);
    LocalStoreService.favoritesRevision.removeListener(_load);
    LocalStoreService.currentUserRevision.removeListener(_load);
    LocalStoreService.applicationsRevision.removeListener(_load);
    LocalStoreService.notificationsRevision.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final identity = await LocalStoreService.instance.getIdentity();
    final favorites = await LocalStoreService.instance.getFavorites();
    final firstLaunch = await LocalStoreService.instance.getOrSetFirstLaunchDate();
    final account = await LocalStoreService.instance.getCurrentUser();
    final mySubmissions = account == null ? <ListingApplication>[] : await ApplicationService.instance.getMine(account.email);
    final notifications = await LocalStoreService.instance.getNotificationsFor(account?.email);
    if (!mounted) return;
    setState(() {
      _identity = identity;
      _favoritesCount = favorites.length;
      _firstLaunch = firstLaunch;
      _account = account;
      _pendingSubmissions = mySubmissions.where((a) => a.status == 'pending').length;
      _unreadNotifications = notifications.where((n) => !n.read).length;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final info = _identityInfo[_identity];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Profile', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),

        // --- Header: avatar + name + member-since -----------------------
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: 42,
                backgroundColor: AppColors.brand,
                child: Icon(info?.icon ?? Icons.person_outline, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_account?.name ?? _identity ?? 'Set up your profile',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  if (_account?.isAdmin == true) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.brand.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('ADMIN', style: TextStyle(color: AppColors.brand, fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ],
              ),
              if (_account != null) ...[
                const SizedBox(height: 2),
                Text(_account!.email, style: TextStyle(color: Colors.grey.shade500, fontSize: 12.5)),
              ],
              if (_firstLaunch != null) ...[
                const SizedBox(height: 2),
                Text('Using UrbanEx since ${_formatDate(_firstLaunch!)}',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        // --- Account card: guest state vs. signed-in state ---------------
        // UrbanEx never requires an account - this card just offers one.
        Card(
          child: ListTile(
            leading: Icon(
              _account != null ? Icons.verified_user_outlined : Icons.login,
              color: AppColors.brand,
            ),
            title: Text(
              _account != null ? 'Signed in' : 'Not signed in',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              _account != null
                  ? 'Signed in as ${_account!.email}'
                  : 'Log in or register to personalize your profile',
            ),
            trailing: _account != null
                ? TextButton(onPressed: _logout, child: const Text('Log out'))
                : ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: _openAuthScreen,
              child: const Text('Log in / Register'),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // --- Notifications - shown to everyone, including guests, since
        // district-news notifications aren't tied to a signed-in account.
        HoverLiftCard(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen())),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.notifications_outlined, color: AppColors.brand),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5)),
                    Text(
                      _unreadNotifications > 0
                          ? '$_unreadNotifications unread'
                          : 'Admin replies, application updates, and district news',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              if (_unreadNotifications > 0)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.bad, borderRadius: BorderRadius.circular(10)),
                  child: Text('$_unreadNotifications', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // --- Admin dashboard entry - only shown to signed-in admins -----
        if (_account?.isAdmin == true) ...[
          HoverLiftCard(
            onTap: _openAdminScreen,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.admin_panel_settings_outlined, color: AppColors.brand),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Admin dashboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5)),
                      Text('View and manage every account on this device',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey.shade400),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // --- My submissions - shown to any signed-in user ----------------
        if (_account != null) ...[
          HoverLiftCard(
            onTap: _openMySubmissions,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.assignment_outlined, color: AppColors.brand),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('My submissions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5)),
                      Text(
                        _pendingSubmissions > 0
                            ? 'Your school & business applications — $_pendingSubmissions pending review'
                            : 'Track your school & business applications',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey.shade400),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // --- Identity card (the main focal point of the page) -----------
        HoverLiftCard(
          onTap: _showIdentityDialog,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(info?.icon ?? Icons.person_outline, color: AppColors.brand),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_identity ?? 'Not set', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(info?.subtitle ?? 'Tap to choose your identity', style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
                      ],
                    ),
                  ),
                  Icon(Icons.edit_outlined, color: Colors.grey.shade400, size: 20),
                ],
              ),
              const SizedBox(height: 12),
              Divider(color: Colors.grey.shade300, height: 1),
              const SizedBox(height: 12),
              Text(
                info?.description ?? 'Choosing an identity personalizes which flows show up first on your home screen.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // --- Quick stats ---------------------------------------------------
        Row(
          children: [
            Expanded(child: _StatTile(icon: Icons.star, label: 'Favorites', value: _loading ? '-' : '$_favoritesCount')),
            const SizedBox(width: 12),
            Expanded(child: _StatTile(icon: Icons.map_outlined, label: 'Districts tracked', value: '$_trackedDistrictCount')),
          ],
        ),
        const SizedBox(height: 24),

        const _SectionLabel('Quick actions'),
        Card(
          child: Column(
            children: [
              ListTile(
                hoverColor: AppColors.brand.withOpacity(0.06),
                leading: const Icon(Icons.star_border),
                title: const Text('View Favorites', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(_favoritesCount == 0 ? 'Nothing saved yet' : '$_favoritesCount saved location${_favoritesCount == 1 ? '' : 's'}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => NavService.currentTab.value = 1,
              ),
              const Divider(height: 1),
              ListTile(
                hoverColor: AppColors.brand.withOpacity(0.06),
                leading: const Icon(Icons.copy_outlined),
                title: const Text('Copy profile summary', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Copy your identity and stats to the clipboard'),
                onTap: _copySummary,
              ),
              if (_account != null) ...[
                const Divider(height: 1),
                ListTile(
                  hoverColor: AppColors.brand.withOpacity(0.06),
                  leading: const Icon(Icons.logout),
                  title: const Text('Log out', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('Signed in as ${_account!.email}'),
                  onTap: _logout,
                ),
              ],
              const Divider(height: 1),
              ListTile(
                hoverColor: AppColors.bad.withOpacity(0.06),
                leading: Icon(Icons.restart_alt, color: AppColors.bad),
                title: Text('Reset profile', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.bad)),
                subtitle: const Text('Clears your identity and all favorites on this device'),
                onTap: _confirmReset,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: Text('UrbanEx v1.0.0', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
        ),
      ],
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  Future<void> _copySummary() async {
    final summary = StringBuffer()
      ..writeln('My UrbanEx profile')
      ..writeln('Identity: ${_identity ?? "Not set"}')
      ..writeln('Favorites saved: $_favoritesCount')
      ..writeln('Using UrbanEx since: ${_firstLaunch != null ? _formatDate(_firstLaunch!) : "-"}');
    await Clipboard.setData(ClipboardData(text: summary.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile summary copied to clipboard')),
    );
  }

  Future<void> _openAuthScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
    );
    // AuthScreen bumps currentUserRevision on success, which triggers
    // _load() via the listener - nothing else needed here.
  }

  Future<void> _openAdminScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AdminScreen()),
    );
  }

  Future<void> _openMySubmissions() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MySubmissionsScreen()),
    );
  }

  Future<void> _logout() async {
    await AuthService.instance.logout();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logged out')),
    );
  }

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset profile?'),
        content: const Text("This clears your saved identity and every favorite on this device. This can't be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Reset', style: TextStyle(color: AppColors.bad, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await LocalStoreService.instance.clearIdentity();
    await LocalStoreService.instance.clearAllFavorites();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile reset')));
  }

  /// Shows the identity picker as a centered dialog (not a bottom sheet),
  /// with a brief description of what each identity does under each
  /// option.
  void _showIdentityDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Choose your identity'),
        contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _identityInfo.entries.map((entry) {
                final selected = _identity == entry.key;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      await LocalStoreService.instance.setIdentity(entry.key);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.brand.withOpacity(0.08) : null,
                        border: Border.all(color: selected ? AppColors.brand : Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(entry.value.icon, color: selected ? AppColors.brand : Colors.black87),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text(entry.value.subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                const SizedBox(height: 6),
                                Text(entry.value.description,
                                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500, height: 1.3)),
                              ],
                            ),
                          ),
                          if (selected) Padding(
                            padding: const EdgeInsets.only(left: 8, top: 2),
                            child: Icon(Icons.check_circle, color: AppColors.brand, size: 20),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.brand, size: 20),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 4),
    child: Text(text, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
  );
}




