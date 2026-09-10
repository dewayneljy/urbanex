import 'package:flutter/material.dart';
import '../services/local_store_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  String? _selected;

  static const _options = [
    (icon: Icons.school_outlined, title: 'Student', subtitle: 'University, college or school'),
    (icon: Icons.work_outline, title: 'Professional', subtitle: 'Employed or working adult'),
    (icon: Icons.apartment_outlined, title: 'Business Owner', subtitle: 'Entrepreneur or self-employed'),
    (icon: Icons.groups_outlined, title: 'Other', subtitle: 'Freelance, retired or exploring'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Text('UrbanEx', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.brand)),
              const SizedBox(height: 20),
              const Text('What best describes you?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                "We'll personalize your UrbanEx experience based on your identity.",
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.separated(
                  itemCount: _options.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final o = _options[i];
                    final selected = _selected == o.title;
                    return HoverLiftCard(
                      selected: selected,
                      onTap: () => setState(() => _selected = o.title),
                      child: Row(
                        children: [
                          Icon(o.icon, color: selected ? Colors.white : Colors.black87),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(o.title,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                      color: selected ? Colors.white : null)),
                              Text(o.subtitle,
                                  style: TextStyle(
                                      color: selected ? Colors.white70 : Colors.grey.shade600, fontSize: 13)),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selected == null
                      ? null
                      : () async {
                          await LocalStoreService.instance.setIdentity(_selected!);
                          widget.onDone();
                        },
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



