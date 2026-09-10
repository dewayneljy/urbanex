import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class _PrivacyPoint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _PrivacyPoint({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.brand, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                const SizedBox(height: 3),
                Text(body, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Purely informational: a plain-language account of what UrbanEx stores
/// and where, since the app deals in real government data and it's worth
/// being explicit that none of it is tied to you personally.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy')),
      bottomNavigationBar: const GlobalBottomNav(),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          _PrivacyPoint(
            icon: Icons.smartphone,
            title: 'Everything stays on this device',
            body: 'Your identity, favorites, dark mode, text size, and home screen preferences are saved locally with '
                'shared_preferences. There is no account, no login, and no server-side profile.',
          ),
          _PrivacyPoint(
            icon: Icons.public,
            title: 'Live data requests are anonymous',
            body: 'When UrbanEx fetches income, population, schools, or crime figures, it queries data.gov.my\'s public '
                'API directly - the same public dataset anyone can query. No personal or device-identifying information '
                'is sent along with those requests.',
          ),
          _PrivacyPoint(
            icon: Icons.visibility_off_outlined,
            title: 'No analytics or tracking',
            body: 'UrbanEx does not collect usage analytics, crash reports, or any third-party tracking.',
          ),
          _PrivacyPoint(
            icon: Icons.delete_outline,
            title: 'You can clear everything, any time',
            body: 'Profile\'s "Reset profile" clears your saved identity and every favorite on this device instantly - '
                'there\'s nothing stored elsewhere to also delete.',
          ),
        ],
      ),
    );
  }
}



