import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../services/native_notification_service.dart';
import '../../../services/notification_service.dart';

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
  final FirebaseAuth? _injectedAuth;
  final GoogleSignIn? _injectedGoogleSignIn;

  AuthService({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
  })  : _injectedAuth = firebaseAuth,
        _injectedGoogleSignIn = googleSignIn;

  FirebaseAuth get _firebaseAuth => _injectedAuth ?? FirebaseAuth.instance;

  GoogleSignIn get _googleSignIn => _injectedGoogleSignIn ?? GoogleSignIn(
        scopes: const ['email', 'profile'],
        serverClientId: '1056749020398-673a9ldv57g51vrdltv9on8k1ve5tf7l.apps.googleusercontent.com',
      );

  /// Stream of authentication state changes
  Stream<User?> get authStateChanges {
    try {
      return _firebaseAuth.authStateChanges();
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Current authenticated Firebase user
  User? get currentUser {
    try {
      return _firebaseAuth.currentUser;
    } catch (_) {
      return null;
    }
  }

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
    } on PlatformException catch (e) {
      debugPrint('[AuthService] PlatformException: ${e.code} - ${e.message} - ${e.details}');
      if (e.code == 'network_error') {
        throw const NexoraAuthException(
          'Network error. Please check your internet connection and try again.',
          code: 'network-error',
        );
      } else if (e.code == 'sign_in_canceled') {
        return null;
      } else if (e.code == 'sign_in_failed') {
        throw NexoraAuthException(
          'Google Sign-In failed: ${e.message ?? e.code}. Please ensure the app was rebuilt after configuration changes.',
          code: e.code,
        );
      }
      throw NexoraAuthException(
        e.message ?? 'Google Sign-In failed. Please try again.',
        code: e.code,
      );
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

  // ---------------------------------------------------------------------------
  // Email / Password Authentication
  // ---------------------------------------------------------------------------

  /// Sign up with email and password, then send a verification email.
  ///
  /// Returns the newly created [User]. Throws [NexoraAuthException] on failure.
  Future<User> signUpWithEmailPassword(String email, String password) async {
    try {
      final UserCredential credential =
          await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final User? user = credential.user;
      if (user == null) {
        throw const NexoraAuthException(
          'Failed to create account. Please try again.',
          code: 'missing-user-info',
        );
      }

      // Send verification email immediately after account creation
      await user.sendEmailVerification();
      debugPrint('[AuthService] Verification email sent to ${user.email}');
      return user;
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthService] signUp FirebaseAuthException: ${e.code}');
      throw _mapFirebaseSignUpError(e);
    } on NexoraAuthException {
      rethrow;
    } catch (e) {
      debugPrint('[AuthService] Unexpected signUp error: $e');
      throw const NexoraAuthException(
        'An unexpected error occurred during sign-up. Please try again.',
        code: 'unknown',
      );
    }
  }

  /// Sign in with email and password.
  ///
  /// Returns the authenticated [User] — callers MUST check [User.emailVerified]
  /// before granting access to the main app.
  /// Throws [NexoraAuthException] on failure.
  Future<User> signInWithEmailPassword(String email, String password) async {
    try {
      final UserCredential credential =
          await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final User? user = credential.user;
      if (user == null) {
        throw const NexoraAuthException(
          'Sign-in failed. Please try again.',
          code: 'missing-user-info',
        );
      }

      debugPrint('[AuthService] signIn success: ${user.email} (verified=${user.emailVerified})');
      return user;
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthService] signIn FirebaseAuthException: ${e.code}');
      throw _mapFirebaseSignInError(e);
    } on NexoraAuthException {
      rethrow;
    } catch (e) {
      debugPrint('[AuthService] Unexpected signIn error: $e');
      throw const NexoraAuthException(
        'An unexpected error occurred during sign-in. Please try again.',
        code: 'unknown',
      );
    }
  }

  /// Send a password-reset email to [email].
  ///
  /// Throws [NexoraAuthException] on failure.
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
      debugPrint('[AuthService] Password reset email sent to $email');
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthService] sendPasswordReset FirebaseAuthException: ${e.code}');
      switch (e.code) {
        case 'user-not-found':
        case 'invalid-email':
          throw const NexoraAuthException(
            'No account found with that email address.',
            code: 'user-not-found',
          );
        case 'network-request-failed':
          throw const NexoraAuthException(
            'Network error. Please check your internet connection and try again.',
            code: 'network-error',
          );
        default:
          throw NexoraAuthException(
            e.message ?? 'Failed to send reset email. Please try again.',
            code: e.code,
          );
      }
    } catch (e) {
      throw const NexoraAuthException(
        'Failed to send reset email. Please try again.',
        code: 'unknown',
      );
    }
  }

  /// Resend a verification email to the currently signed-in user.
  ///
  /// Throws [NexoraAuthException] if there is no signed-in user or on failure.
  Future<void> resendVerificationEmail() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const NexoraAuthException(
        'No signed-in user found. Please sign in again.',
        code: 'no-user',
      );
    }
    try {
      await user.sendEmailVerification();
      debugPrint('[AuthService] Verification email resent to ${user.email}');
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthService] resendVerification FirebaseAuthException: ${e.code}');
      switch (e.code) {
        case 'too-many-requests':
          throw const NexoraAuthException(
            'Too many requests. Please wait a moment before trying again.',
            code: 'too-many-requests',
          );
        default:
          throw NexoraAuthException(
            e.message ?? 'Failed to resend verification email.',
            code: e.code,
          );
      }
    } catch (e) {
      throw const NexoraAuthException(
        'Failed to resend verification email. Please try again.',
        code: 'unknown',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers — Firebase error mapping
  // ---------------------------------------------------------------------------

  NexoraAuthException _mapFirebaseSignUpError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return const NexoraAuthException(
          'An account with this email already exists. Try signing in instead.',
          code: 'email-already-in-use',
        );
      case 'invalid-email':
        return const NexoraAuthException(
          'The email address is not valid.',
          code: 'invalid-email',
        );
      case 'weak-password':
        return const NexoraAuthException(
          'Password is too weak. Use at least 6 characters.',
          code: 'weak-password',
        );
      case 'network-request-failed':
        return const NexoraAuthException(
          'Network error. Please check your internet connection and try again.',
          code: 'network-error',
        );
      default:
        return NexoraAuthException(
          e.message ?? 'Sign-up failed. Please try again.',
          code: e.code,
        );
    }
  }

  NexoraAuthException _mapFirebaseSignInError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        // Intentionally vague — don't reveal whether the email exists
        return const NexoraAuthException(
          'Incorrect email or password. Please try again.',
          code: 'invalid-credentials',
        );
      case 'invalid-email':
        return const NexoraAuthException(
          'The email address is not valid.',
          code: 'invalid-email',
        );
      case 'user-disabled':
        return const NexoraAuthException(
          'This account has been disabled. Please contact support.',
          code: 'user-disabled',
        );
      case 'too-many-requests':
        return const NexoraAuthException(
          'Too many failed attempts. Please wait a moment and try again.',
          code: 'too-many-requests',
        );
      case 'network-request-failed':
        return const NexoraAuthException(
          'Network error. Please check your internet connection and try again.',
          code: 'network-error',
        );
      default:
        return NexoraAuthException(
          e.message ?? 'Sign-in failed. Please try again.',
          code: e.code,
        );
    }
  }

  /// Sign out from both Firebase and Google with device token deactivation
  Future<void> signOut({NotificationService? notificationService}) async {
    try {
      final notifService = notificationService ?? NotificationService(authService: this);
      await NativeNotificationService.instance.unregisterCurrentDevice(
        notificationService: notifService,
      );
    } catch (e) {
      debugPrint('[AuthService] Error unregistering device on signOut: $e');
    }

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
  /// Get the Firebase ID token for the current user.
  /// Returns null if no user is signed in.
  Future<String?> getIdToken() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return null;
    return await user.getIdToken();
  }

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
