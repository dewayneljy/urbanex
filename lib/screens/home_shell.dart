import 'package:flutter/material.dart';
import '../services/nav_service.dart';
import '../widgets/common_widgets.dart';
import 'home_screen.dart';
import 'favorites_screen.dart';
import 'settings_about_profile_screens.dart';
import 'profile_screen.dart';

/// Top-level shell with the persistent bottom navigation bar seen on
/// Home / Favorites / Settings / Profile in the Figma. The active tab now
/// lives in [NavService.currentTab] so pushed screens elsewhere in the
/// app can show the same bar and jump straight to a different tab.
class HomeShell extends StatefulWidget {
  final ValueChanged<bool> onDarkModeChanged;
  final bool isDarkMode;
  final ValueChanged<double> onTextScaleChanged;
  final double textScale;

  const HomeShell({
    super.key,
    required this.onDarkModeChanged,
    required this.isDarkMode,
    required this.onTextScaleChanged,
    required this.textScale,
  });

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  @override
  void initState() {
    super.initState();
    NavService.currentTab.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    NavService.currentTab.removeListener(_onTabChanged);
    super.dispose();
  }

  void _onTabChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final index = NavService.currentTab.value;
    final pages = [
      const HomeScreen(),
      const FavoritesScreen(),
      SettingsScreen(
        onDarkModeChanged: widget.onDarkModeChanged,
        isDarkMode: widget.isDarkMode,
        onTextScaleChanged: widget.onTextScaleChanged,
        textScale: widget.textScale,
      ),
      const ProfileScreen(),
    ];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: index, children: pages)),
      bottomNavigationBar: AppBottomNav(
        currentIndex: index,
        onTap: (i) => NavService.currentTab.value = i,
      ),
    );
  }
}



