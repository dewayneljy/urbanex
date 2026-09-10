import 'package:supabase_flutter/supabase_flutter.dart';

/// Central place for the Supabase project's connection details and the
/// initialized client. Called once from `main()` before `runApp`.
///
/// Fill these in from your Supabase project dashboard:
/// Project Settings -> API -> "Project URL" and "anon public" key.
/// The anon key is safe to ship in the app - it's the public key meant
/// for client apps, and every table it can touch is protected by the
/// Row Level Security policies in supabase/schema.sql.
class SupabaseConfig {
  static const String url = 'https://nfodkmvhpmssvtwvxqjw.supabase.co';
  static const String anonKey = '';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
  }
}

/// Shorthand used throughout the services - `supabase.from('table')...`.
SupabaseClient get supabase => Supabase.instance.client;

