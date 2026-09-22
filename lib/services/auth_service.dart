import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../l10n_app_strings.dart';
import '../models/auth_user.dart';
import 'cloud_sync_service.dart';
import 'storage_service.dart';

class AuthException implements Exception {
  AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  /// Error messages follow the language selected in the app.
  AppStrings get _t => AppStrings.current;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _google = GoogleSignIn();

  Future<AuthUser?> getCurrentUser() async {
    final user = _auth.currentUser;
    return user == null ? null : _mapUser(user);
  }

  Stream<AuthUser?> authChanges() =>
      _auth.authStateChanges().map((u) => u == null ? null : _mapUser(u));

  Future<AuthUser> signUpWithEmail({
    required String displayName,
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (displayName.trim().isNotEmpty) {
        await cred.user?.updateDisplayName(displayName.trim());
        await cred.user?.reload();
      }
      final current = _auth.currentUser;
      if (current == null) {
        throw AuthException(_t.authSessionNotRestored);
      }
      final mapped = _mapUser(current);
      await CloudSyncService.instance.saveUserProfile(mapped);
      return mapped;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_friendlyAuthMessage(e));
    }
  }

  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = cred.user;
      if (user == null) throw AuthException(_t.authSessionNotStarted);
      final mapped = _mapUser(user);
      await CloudSyncService.instance.saveUserProfile(mapped);
      return mapped;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_friendlyAuthMessage(e));
    }
  }

  Future<AuthUser> signInWithGoogle() async {
    try {
      // ignore: body_might_complete_normally_catch_error
      await _google.signOut().catchError((_) {});
      final googleUser = await _google.signIn();
      if (googleUser == null) {
        throw AuthException(_t.authGoogleCancelled);
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) throw AuthException(_t.authGoogleFailed);
      final mapped = _mapUser(user);
      await CloudSyncService.instance.saveUserProfile(mapped);
      return mapped;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_friendlyAuthMessage(e));
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException(_t.authGoogleBuildSetup);
    }
  }

  Future<void> startPhoneVerification({
    required String phoneNumber,
    required void Function() onCodeSent,
    required void Function(AuthUser user) onVerified,
  }) async {
    final completer = Completer<void>();
    final requestNonce = ++_activeVerificationNonce;
    _verificationId = null;
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber.trim(),
        verificationCompleted: (credential) async {
          if (requestNonce != _activeVerificationNonce) {
            if (!completer.isCompleted) completer.complete();
            return;
          }
          try {
            final result = await _auth.signInWithCredential(credential);
            final user = result.user;
            if (user != null) {
              final mapped = _mapUser(user);
              await CloudSyncService.instance.saveUserProfile(mapped);
              onVerified(mapped);
            }
          } finally {
            if (!completer.isCompleted) completer.complete();
          }
        },
        verificationFailed: (e) {
          if (requestNonce == _activeVerificationNonce) {
            _verificationId = null;
          }
          if (!completer.isCompleted) {
            completer.completeError(AuthException(_friendlyAuthMessage(e)));
          }
        },
        codeSent: (verificationId, _) {
          if (requestNonce != _activeVerificationNonce) return;
          _verificationId = verificationId;
          onCodeSent();
          if (!completer.isCompleted) completer.complete();
        },
        codeAutoRetrievalTimeout: (verificationId) {
          if (requestNonce != _activeVerificationNonce) return;
          _verificationId = verificationId;
        },
      );
      await completer.future;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_friendlyAuthMessage(e));
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException(_t.authPhoneStartFailed);
    }
  }

  String? _verificationId;
  int _activeVerificationNonce = 0;

  Future<AuthUser> verifySmsCode(String code) async {
    final verificationId = _verificationId;
    if (verificationId == null || verificationId.isEmpty) {
      throw AuthException(_t.authNoSmsVerification);
    }
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: code.trim(),
      );
      final result = await _auth.signInWithCredential(credential);
      final user = result.user;
      if (user == null) {
        throw AuthException(_t.authSmsVerifyFailed);
      }
      _verificationId = null;
      final mapped = _mapUser(user);
      await CloudSyncService.instance.saveUserProfile(mapped);
      return mapped;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_friendlyAuthMessage(e));
    }
  }


  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw AuthException(_t.authNoActiveSession);
    }

    try {
      await CloudSyncService.instance.flushPendingWrites();
    } catch (_) {
      // Best effort before removing the remote profile.
    } finally {
      CloudSyncService.instance.cancelPendingWrites();
    }

    try {
      final mappedUser = _mapUser(user);
      await CloudSyncService.instance.markAccountDeleted(mappedUser);
      await user.delete();
      await StorageService.instance.clearLocalUserData();
      // ignore: body_might_complete_normally_catch_error
      await _google.signOut().catchError((_) {});
      // ignore: body_might_complete_normally_catch_error
      await _auth.signOut().catchError((_) {});
    } on FirebaseAuthException catch (e) {
      // The Firestore profile may already be gone at this point.
      // Force the session back to login so the user can retry if needed.
      // ignore: body_might_complete_normally_catch_error
      await _google.signOut().catchError((_) {});
      // ignore: body_might_complete_normally_catch_error
      await _auth.signOut().catchError((_) {});

      if (e.code == 'requires-recent-login') {
        throw AuthException(_t.authDeleteRequiresRecentLogin);
      }
      throw AuthException(_friendlyAuthMessage(e));
    }
  }

  Future<void> signOut() async {
    try {
      await CloudSyncService.instance.flushPendingWrites();
    } catch (_) {
      // Best effort: local data is already saved, so do not block sign out.
    } finally {
      CloudSyncService.instance.cancelPendingWrites();
    }

    await Future.wait([
      _auth.signOut(),
      // ignore: body_might_complete_normally_catch_error
      _google.signOut().catchError((_) {}),
    ]);
  }

  AuthUser _mapUser(User user) {
    final provider = user.providerData.isNotEmpty
        ? user.providerData.first.providerId
        : 'firebase';
    return AuthUser(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : (user.phoneNumber?.trim().isNotEmpty == true
              ? user.phoneNumber!.trim()
              : (user.email?.split('@').first ?? 'Detox user')),
      provider: provider,
      phoneNumber: user.phoneNumber,
    );
  }

  String _friendlyAuthMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return _t.authEmailInUse;
      case 'invalid-email':
        return _t.authInvalidEmail;
      case 'user-not-found':
        return _t.authUserNotFound;
      case 'wrong-password':
      case 'invalid-credential':
        return _t.authWrongCredentials;
      case 'weak-password':
        return _t.authWeakPassword;
      case 'network-request-failed':
        return _t.authNetworkError;
      case 'too-many-requests':
        return _t.authTooManyRequests;
      case 'operation-not-allowed':
        return _t.authMethodNotAllowed;
      case 'invalid-verification-code':
        return _t.authInvalidSmsCode;
      case 'session-expired':
        return _t.authSmsExpired;
      default:
        return e.message ?? _t.authFailed;
    }
  }
}
