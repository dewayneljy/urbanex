import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'services/local_store_service.dart';
import 'services/supabase_config.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initialize();
  runApp(const UrbanExApp());
}

class UrbanExApp extends StatefulWidget {
  const UrbanExApp({super.key});

  @override
  State<UrbanExApp> createState() => _UrbanExAppState();
}

class _UrbanExAppState extends State<UrbanExApp> {
  ThemeMode _themeMode = ThemeMode.light;
  double _textScale = 1.0;
  bool _loading = true;
  bool _onboarded = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final dark = await LocalStoreService.instance.getDarkMode();
    final onboarded = await LocalStoreService.instance.hasOnboarded();
    final textScale = await LocalStoreService.instance.getTextScale();
    setState(() {
      _themeMode = dark ? ThemeMode.dark : ThemeMode.light;
      _onboarded = onboarded;
      _textScale = textScale;
      _loading = false;
    });
  }

  void setDarkMode(bool value) {
    setState(() => _themeMode = value ? ThemeMode.dark : ThemeMode.light);
    LocalStoreService.instance.setDarkMode(value);
  }

  void setTextScale(double value) {
    setState(() => _textScale = value);
    LocalStoreService.instance.setTextScale(value);
  }

  void completeOnboarding() {
    setState(() => _onboarded = true);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UrbanEx',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeMode,
      // Applies the text-size preference app-wide, above the Navigator, so
      // it takes effect immediately on every screen - including ones
      // already pushed - the same instant it changes in Settings.
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(_textScale)),
          child: child!,
        );
      },
      home: _loading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _onboarded
              ? HomeShell(
                  onDarkModeChanged: setDarkMode,
                  isDarkMode: _themeMode == ThemeMode.dark,
                  onTextScaleChanged: setTextScale,
                  textScale: _textScale,
                )
              : OnboardingScreen(onDone: completeOnboarding),
    );
  }
}



