import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/data_service.dart';
import '../services/local_store_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'data_sources_screen.dart';
import 'feedback_screen.dart';
import 'privacy_screen.dart';

class SettingsScreen extends StatefulWidget {
  final ValueChanged<bool> onDarkModeChanged;
  final bool isDarkMode;
  final ValueChanged<double> onTextScaleChanged;
  final double textScale;

  const SettingsScreen({
    super.key,
    required this.onDarkModeChanged,
    required this.isDarkMode,
    required this.onTextScaleChanged,
    required this.textScale,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _showTopRated = true;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    LocalStoreService.instance.getShowTopRated().then((v) {
      if (mounted) setState(() => _showTopRated = v);
    });
  }

  Future<void> _refreshData() async {
    setState(() => _refreshing = true);
    try {
      await DataService.instance.getDistricts(forceRefresh: true);
      await DataService.instance.getStates(forceRefresh: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Live data refreshed')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Refresh failed — check your connection')));
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _exportFavorites() async {
    final favorites = await LocalStoreService.instance.getFavorites();
    if (favorites.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No favorites saved yet')));
      return;
    }
    final buffer = StringBuffer()..writeln('My UrbanEx favorites');
    for (final f in favorites) {
      final place = f.type == 'district' ? '${f.title}, ${f.subtitle}' : f.title;
      buffer.writeln('- $place (score ${f.score.round()})');
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Favorites copied to clipboard')));
  }

  String _formatLastRefreshed(DateTime? d) {
    if (d == null) return 'Not yet synced this session';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Settings', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),

        const _SectionLabel('Appearance'),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                hoverColor: AppColors.brand.withOpacity(0.06),
                secondary: const Icon(Icons.dark_mode_outlined),
                title: const Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Preferred app theme'),
                value: widget.isDarkMode,
                onChanged: widget.onDarkModeChanged,
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.text_fields),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Text size', style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text('Applies everywhere in the app, instantly', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                          const SizedBox(height: 10),
                          _TextScaleSelector(value: widget.textScale, onChanged: widget.onTextScaleChanged),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        const _SectionLabel('Home screen'),
        Card(
          child: SwitchListTile(
            hoverColor: AppColors.brand.withOpacity(0.06),
            secondary: const Icon(Icons.leaderboard_outlined),
            title: const Text('Top-rated leaderboard', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Show the top 5 districts on your Home tab'),
            value: _showTopRated,
            onChanged: (v) {
              setState(() => _showTopRated = v);
              LocalStoreService.instance.setShowTopRated(v);
            },
          ),
        ),
        const SizedBox(height: 20),

        const _SectionLabel('Data'),
        Card(
          child: Column(
            children: [
              ListTile(
                hoverColor: AppColors.brand.withOpacity(0.06),
                leading: const Icon(Icons.sync),
                title: const Text('Refresh live data now', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('Last synced: ${_formatLastRefreshed(DataService.instance.lastRefreshed)}'),
                trailing: _refreshing
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.chevron_right),
                onTap: _refreshing ? null : _refreshData,
              ),
              const Divider(height: 1),
              ListTile(
                hoverColor: AppColors.brand.withOpacity(0.06),
                leading: const Icon(Icons.dataset_outlined),
                title: const Text('Data Sources', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Every live government dataset UrbanEx uses'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DataSourcesScreen())),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        const _SectionLabel('Your data'),
        Card(
          child: Column(
            children: [
              ListTile(
                hoverColor: AppColors.brand.withOpacity(0.06),
                leading: const Icon(Icons.copy_outlined),
                title: const Text('Export favorites', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Copy your saved list to the clipboard'),
                onTap: _exportFavorites,
              ),
              const Divider(height: 1),
              ListTile(
                hoverColor: AppColors.brand.withOpacity(0.06),
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Privacy', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('What UrbanEx stores, and where'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrivacyScreen())),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        const _SectionLabel('About'),
        Card(
          child: Column(
            children: [
              ListTile(
                hoverColor: AppColors.brand.withOpacity(0.06),
                leading: const Icon(Icons.info_outline),
                title: const Text('About UrbanEx', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('More information about us'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AboutScreen())),
              ),
              const Divider(height: 1),
              ListTile(
                hoverColor: AppColors.brand.withOpacity(0.06),
                leading: const Icon(Icons.mail_outline),
                title: const Text('Contact & feedback', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Send a bug report or suggestion'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FeedbackScreen())),


    ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TextScaleSelector extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  const _TextScaleSelector({required this.value, required this.onChanged});

  static const _options = [
    (label: 'Small', scale: 0.85),
    (label: 'Normal', scale: 1.0),
    (label: 'Large', scale: 1.15),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _options.map((o) {
        final selected = (value - o.scale).abs() < 0.01;
        return SelectableChip(
          label: o.label,
          selected: selected,
          onTap: () => onChanged(o.scale),
        );
      }).toList(),
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

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About Us')),
      bottomNavigationBar: const GlobalBottomNav(),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('UrbanEx', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.brand)),
          const SizedBox(height: 20),
          const _AboutBlock(
            title: 'Description',
            body:
                'UrbanEx is a location recommendation application designed to help users identify the most suitable districts in Malaysia based on their personal needs and preferences. UrbanEx provides data-driven recommendations, pulled live from official Malaysian open data (data.gov.my), to support better decision-making.',
          ),
          const _AboutBlock(
            title: 'Our Mission',
            body:
                'Our mission is to make location selection easier through reliable data and personalized recommendations. UrbanEx empowers users to make informed decisions by presenting district information in a simple, clear, and accessible way.',
          ),
          const _AboutBlock(
            title: 'Our Vision',
            body:
                'We envision UrbanEx becoming a trusted decision-support platform that helps individuals, students, and entrepreneurs confidently choose locations across Malaysia.',
          ),
        ],
      ),
    );
  }
}

class _AboutBlock extends StatelessWidget {
  final String title;
  final String body;
  const _AboutBlock({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 6),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(body, style: TextStyle(color: Colors.grey.shade700, height: 1.4)),
            ),
          ),
        ],
      ),
    );
  }
}



