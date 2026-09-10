import 'package:supabase_flutter/supabase_flutter.dart';
import '../models.dart';
import 'supabase_config.dart';

/// Result of a register/login attempt - a small success/error wrapper so
/// screens can show a specific message without throwing exceptions across
/// the UI boundary.
class AuthResult {
  final bool success;
  final String? error;
  const AuthResult._(this.success, this.error);
  const AuthResult.ok() : this._(true, null);
  const AuthResult.fail(String message) : this._(false, message);
}

/// Handles account registration and login via Supabase Auth (email +
/// password). Session state (who's signed in) is owned entirely by
/// supabase.auth from here on - see LocalStoreService.getCurrentUser()
/// for reading it back out as a UserAccount.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  /// Entering this code in the "Admin code" field on the register screen
  /// creates the account as an admin instead of a regular user. This is
  /// a soft, client-side convenience for a class project - anyone who
  /// reads the app's source can find this value. A real product would
  /// grant admin rights from a trusted server context instead.
  static const String adminInviteCode = 'URBANEX-ADMIN-2026';

  String _normalizeEmail(String email) => email.trim().toLowerCase();

  bool _looksLikeEmail(String value) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
  }

  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
    String? adminCode,
  }) async {
    final normalizedEmail = _normalizeEmail(email);
    final normalizedName = name.trim();

    if (normalizedName.isEmpty) {
      return const AuthResult.fail('Please enter your name.');
    }
    if (!_looksLikeEmail(normalizedEmail)) {
      return const AuthResult.fail('Please enter a valid email address.');
    }
    if (password.length < 6) {
      return const AuthResult.fail('Password must be at least 6 characters.');
    }

    final trimmedCode = adminCode?.trim() ?? '';
    if (trimmedCode.isNotEmpty && trimmedCode != adminInviteCode) {
      return const AuthResult.fail('That admin code is not valid.');
    }

    try {
      final response = await supabase.auth.signUp(
        email: normalizedEmail,
        password: password,
      );
      final user = response.user;
      if (user == null) {
        return const AuthResult.fail('Could not create that account. Please try again.');
      }

      await supabase.from('profiles').insert({
        'id': user.id,
        'email': normalizedEmail,
        'name': normalizedName,
        'is_admin': trimmedCode == adminInviteCode,
      });

      // If the Supabase project has "Confirm email" turned on, signUp()
      // won't return a live session yet - the person needs to click the
      // confirmation link before signInWithPassword will work. Turn that
      // setting off (Authentication -> Providers -> Email) for a demo
      // build that should behave like the old instant-login flow.
      if (response.session == null) {
        return const AuthResult.fail('Account created - check your email to confirm it, then log in.');
      }
      return const AuthResult.ok();
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('already registered') ||
          e.message.toLowerCase().contains('already exists')) {
        return const AuthResult.fail('An account with that email already exists.');
      }
      return AuthResult.fail(e.message);
    } catch (_) {
      return const AuthResult.fail('Something went wrong creating that account. Please try again.');
    }
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = _normalizeEmail(email);
    try {
      final response = await supabase.auth.signInWithPassword(
        email: normalizedEmail,
        password: password,
      );
      if (response.user == null) {
        return const AuthResult.fail('Incorrect email or password.');
      }
      return const AuthResult.ok();
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('invalid login credentials')) {
        return const AuthResult.fail('Incorrect email or password.');
      }
      return AuthResult.fail(e.message);
    } catch (_) {
      return const AuthResult.fail('Something went wrong logging in. Please try again.');
    }
  }

  Future<void> logout() => supabase.auth.signOut();

  // --- Admin actions ----------------------------------------------------
  // Only reachable from AdminScreen, which itself only appears in
  // Profile for a signed-in account with isAdmin == true - but every
  // method here re-checks that the caller is currently an admin (via
  // the is_admin() Postgres function, enforced by RLS on the `profiles`
  // table itself), so it stays safe even if something else calls it.

  Future<bool> currentUserIsAdmin() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return false;
    final row = await supabase.from('profiles').select('is_admin').eq('id', uid).maybeSingle();
    return row?['is_admin'] as bool? ?? false;
  }

  /// All registered accounts, newest first.
  Future<List<UserAccount>> getAllUsers() async {
    final rows = await supabase.from('profiles').select().order('created_at', ascending: false);
    return (rows as List)
        .map((r) => UserAccount(
              email: r['email'] as String,
              name: r['name'] as String,
              passwordHash: '',
              salt: '',
              createdAt: DateTime.parse(r['created_at'] as String),
              isAdmin: r['is_admin'] as bool? ?? false,
            ))
        .toList();
  }

  /// Grants or revokes admin rights for [email]. Refuses to remove the
  /// last remaining admin, so the app can never end up with no way to
  /// reach the admin dashboard again.
  Future<AuthResult> setAdminStatus(String email, bool isAdmin) async {
    if (!await currentUserIsAdmin()) {
      return const AuthResult.fail('Only an admin can do that.');
    }
    final users = await getAllUsers();
    final target = users.where((u) => u.email == email).toList();
    if (target.isEmpty) {
      return const AuthResult.fail('That account no longer exists.');
    }

    if (!isAdmin) {
      final otherAdmins = users.where((u) => u.email != email && u.isAdmin).length;
      if (otherAdmins == 0) {
        return const AuthResult.fail("Can't remove the last admin account.");
      }
    }

    await supabase.from('profiles').update({'is_admin': isAdmin}).eq('email', email);
    return const AuthResult.ok();
  }

  /// Removes [email]'s profile row. NOTE: this does not delete the
  /// underlying Supabase Auth account - see the comment on
  /// LocalStoreService.deleteUser() for why (needs a service-role Edge
  /// Function). Refuses to remove the last remaining admin.
  Future<AuthResult> deleteUser(String email) async {
    if (!await currentUserIsAdmin()) {
      return const AuthResult.fail('Only an admin can do that.');
    }
    final users = await getAllUsers();
    final target = users.where((u) => u.email == email).toList();
    if (target.isEmpty) {
      return const AuthResult.fail('That account no longer exists.');
    }
    if (target.first.isAdmin) {
      final otherAdmins = users.where((u) => u.email != email && u.isAdmin).length;
      if (otherAdmins == 0) {
        return const AuthResult.fail("Can't delete the last admin account.");
      }
    }

    await supabase.from('profiles').delete().eq('email', email);
    return const AuthResult.ok();
  }
}
