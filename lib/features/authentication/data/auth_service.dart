import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Allowed organization domain for Nexora access
const String kAllowedDomain = 'bvcgroup.in';

/// Custom authentication exception with user-friendly messages
class NexoraAuthException implements Exception {
  final String message;
  final String? code;

  const NexoraAuthException(this.message, {this.code});

  @override
  String toString() => message;
}

/// Firebase Authentication & Google Sign-In Service
class AuthService {
  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;

  AuthService({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn(scopes: const ['email', 'profile']);

  /// Stream of authentication state changes
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  /// Current authenticated Firebase user
  User? get currentUser => _firebaseAuth.currentUser;

  /// Check if a given email belongs strictly to the allowed domain (@bvcgroup.in)
  static bool isAllowedDomain(String? email) {
    if (email == null) return false;
    final normalized = email.trim().toLowerCase();
    final parts = normalized.split('@');
    if (parts.length != 2) return false;
    if (parts[0].isEmpty || parts[1].isEmpty) return false;
    return parts[1] == kAllowedDomain;
  }

  /// Sign in with Google and validate @bvcgroup.in domain
  /// Returns the authenticated [User] on success.
  /// Returns `null` if the user cancelled the sign-in flow.
  /// Throws [NexoraAuthException] on failure or unauthorized domain.
  Future<User?> signInWithGoogle() async {
    try {
      // 1. Trigger the Google Authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      // User cancelled the sign-in dialog
      if (googleUser == null) {
        debugPrint('[AuthService] Google Sign-In cancelled by user');
        return null;
      }

      // 2. Pre-validate email domain if available from Google account
      if (!isAllowedDomain(googleUser.email)) {
        debugPrint('[AuthService] Rejected non-BVC email: ${googleUser.email}');
        await _googleSignIn.signOut();
        throw const NexoraAuthException(
          'Only BVC Group accounts (@bvcgroup.in) can access Nexora.',
          code: 'unauthorized-domain',
        );
      }

      // 3. Obtain authentication details from request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // 4. Create a new credential for Firebase
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 5. Sign in to Firebase with the Google credential
      final UserCredential userCredential =
          await _firebaseAuth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user == null || user.email == null) {
        await signOut();
        throw const NexoraAuthException(
          'Failed to retrieve user profile from authentication provider.',
          code: 'missing-user-info',
        );
      }

      // 6. Strict validation of authenticated Firebase user email domain
      if (!isAllowedDomain(user.email)) {
        debugPrint('[AuthService] Firebase User domain rejection for: ${user.email}');
        await signOut();
        throw const NexoraAuthException(
          'Only BVC Group accounts (@bvcgroup.in) can access Nexora.',
          code: 'unauthorized-domain',
        );
      }

      debugPrint('[AuthService] Successfully authenticated BVC user: ${user.email} (${user.uid})');
      return user;
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthService] FirebaseAuthException: ${e.code} - ${e.message}');
      switch (e.code) {
        case 'account-exists-with-different-credential':
          throw const NexoraAuthException(
            'An account already exists with a different credential.',
            code: 'account-exists',
          );
        case 'invalid-credential':
          throw const NexoraAuthException(
            'Invalid authentication credentials. Please try again.',
            code: 'invalid-credential',
          );
        case 'user-disabled':
          throw const NexoraAuthException(
            'This user account has been disabled. Please contact college support.',
            code: 'user-disabled',
          );
        case 'network-request-failed':
          throw const NexoraAuthException(
            'Network error. Please check your internet connection and try again.',
            code: 'network-error',
          );
        default:
          throw NexoraAuthException(
            e.message ?? 'Authentication failed. Please try again.',
            code: e.code,
          );
      }
    } on NexoraAuthException {
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('[AuthService] Unexpected error during Google Sign-In: $e\n$stackTrace');
      throw const NexoraAuthException(
        'An unexpected error occurred during sign-in. Please try again.',
        code: 'unknown',
      );
    }
  }

  /// Sign out from both Firebase and Google
  Future<void> signOut() async {
    try {
      await Future.wait([
        _firebaseAuth.signOut(),
        _googleSignIn.signOut(),
      ]);
      debugPrint('[AuthService] Successfully signed out');
    } catch (e) {
      debugPrint('[AuthService] Error during sign out: $e');
      // Ensure at least Firebase signs out
      await _firebaseAuth.signOut();
    }
  }

  /// Check if the currently cached Firebase user is valid and has an authorized domain
  bool get isAuthenticatedAndValid {
    final user = currentUser;
    return user != null && isAllowedDomain(user.email);
  }
}

// ---------------------------------------------------------------------------
// Riverpod Providers
// ---------------------------------------------------------------------------

/// Provider for [AuthService] instance
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// Stream provider for Firebase auth state changes
final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

/// Provider for current Firebase user
final currentUserProvider = Provider<User?>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(authServiceProvider).currentUser;
});
