import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../l10n_app_strings.dart';
import '../models/auth_user.dart';
import 'cloud_sync_service.dart';
import 'storage_service.dart';
import 'username_policy.dart';

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
  bool get hasGoogleProvider =>
      _auth.currentUser?.providerData.any(
        (provider) => provider.providerId == 'google.com',
      ) ??
      false;
  final GoogleSignIn _google = GoogleSignIn.instance;
  late final Future<void> _googleReady = _google.initialize();

  Future<void> _signOutGoogle() async {
    try {
      await _googleReady;
      await _google.signOut();
    } catch (_) {
      // Signing out of Firebase is still possible if Google is unavailable.
    }
  }

  Future<AuthUser?> getCurrentUser() async {
    final user = _auth.currentUser;
    return user == null ? null : _mapUser(user);
  }

  Completer<void>? _pendingAuth;

  Stream<AuthUser?> authChanges() => _auth.userChanges().asyncMap((_) async {
    // Publish only the final alias/profile, not the intermediate provider name.
    await _pendingAuth?.future;
    return getCurrentUser();
  });

  Future<AuthUser> continueAnonymously(String username) async {
    final error = UsernamePolicy.validate(username, isEs: _t.isEs);
    if (error != null) throw AuthException(error);
    _pendingAuth = Completer<void>();
    try {
      final user = _auth.currentUser ?? (await _auth.signInAnonymously()).user!;
      await user.updateDisplayName(username.trim());
      final mapped = _mapUser(_auth.currentUser!);
      await CloudSyncService.instance.saveUserProfile(mapped);
      return mapped;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_friendlyAuthMessage(e));
    } finally {
      _pendingAuth?.complete();
      _pendingAuth = null;
    }
  }

  Future<void> updateUsername(String username) async {
    final value = username.trim();
    final error = UsernamePolicy.validate(value, isEs: _t.isEs);
    if (error != null) throw AuthException(error);
    await _auth.currentUser!.updateDisplayName(value);
    await CloudSyncService.instance.saveUserProfile(
      _mapUser(_auth.currentUser!),
    );
  }

  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(_friendlyAuthMessage(e));
    }
  }

  Future<void> resendEmailVerification() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw AuthException(_friendlyAuthMessage(e));
    }
  }

  Future<AuthUser> signUpWithEmail({
    required String displayName,
    required String email,
    required String password,
  }) async {
    final error = UsernamePolicy.validate(displayName, isEs: _t.isEs);
    if (error != null) throw AuthException(error);
    _pendingAuth = Completer<void>();
    try {
      final existing = _auth.currentUser;
      final cred = existing != null
          ? await existing.linkWithCredential(
              EmailAuthProvider.credential(
                email: email.trim(),
                password: password,
              ),
            )
          : await _auth.createUserWithEmailAndPassword(
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
      if (!current.emailVerified) await current.sendEmailVerification();
      return mapped;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_friendlyAuthMessage(e));
    } finally {
      _pendingAuth?.complete();
      _pendingAuth = null;
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

  Future<AuthUser> signInWithGoogle({bool linkToCurrentUser = false}) async {
    final existing = _auth.currentUser;
    final existingAlias = existing?.displayName;
    if (linkToCurrentUser && existing == null)
      throw AuthException(_t.authNoActiveSession);
    _pendingAuth = Completer<void>();
    try {
      await _googleReady;
      await _signOutGoogle();
      final googleUser = await _google.authenticate();
      final googleAuth = googleUser.authentication;
      if (googleAuth.idToken == null) throw AuthException(_t.authGoogleFailed);
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
      if (linkToCurrentUser && _auth.currentUser?.uid != existing!.uid) {
        throw AuthException(_t.authSessionNotRestored);
      }
      final userCredential = linkToCurrentUser
          ? await existing!.linkWithCredential(credential)
          : await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) throw AuthException(_t.authGoogleFailed);
      final snapshot = await CloudSyncService.instance.loadSnapshot(
        force: true,
      );
      final alias = linkToCurrentUser
          ? existingAlias
          : snapshot?['profile']?['displayName'] as String?;
      await user.updateDisplayName(alias ?? 'Detox user');
      await user.updatePhotoURL(null);
      final mapped = _mapUser(_auth.currentUser!);
      await CloudSyncService.instance.saveUserProfile(mapped);
      return mapped;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_friendlyAuthMessage(e));
    } on GoogleSignInException catch (e) {
      throw AuthException(
        e.code == GoogleSignInExceptionCode.canceled
            ? _t.authGoogleCancelled
            : _t.authGoogleBuildSetup,
      );
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException(_t.authGoogleBuildSetup);
    } finally {
      _pendingAuth?.complete();
      _pendingAuth = null;
    }
  }

  Future<void> startPhoneVerification({
    required String phoneNumber,
    required void Function() onCodeSent,
    required void Function(AuthUser user) onVerified,
  }) async {
    final completer = Completer<void>();
    final requestNonce = ++_activeVerificationNonce;
    _phoneLinkUser = _auth.currentUser;
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
            final result = await _completePhoneCredential(credential);
            final user = result.user;
            if (user != null) {
              final mapped = _mapUser(user);
              await CloudSyncService.instance.saveUserProfile(mapped);
              onVerified(mapped);
            }
          } on FirebaseAuthException catch (e) {
            if (!completer.isCompleted)
              completer.completeError(AuthException(_friendlyAuthMessage(e)));
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
  User? _phoneLinkUser;

  Future<UserCredential> _completePhoneCredential(
    PhoneAuthCredential credential,
  ) {
    final user = _phoneLinkUser;
    if (user != null) {
      if (_auth.currentUser?.uid != user.uid)
        throw AuthException(_t.authSessionNotRestored);
      return user.linkWithCredential(credential);
    }
    return _auth.signInWithCredential(credential);
  }

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
      final result = await _completePhoneCredential(credential);
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
      await _signOutGoogle();
      // ignore: body_might_complete_normally_catch_error
      await _auth.signOut().catchError((_) {});
    } on FirebaseAuthException catch (e) {
      // The Firestore profile may already be gone at this point.
      // Force the session back to login so the user can retry if needed.
      await _signOutGoogle();
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

    await Future.wait([_auth.signOut(), _signOutGoogle()]);
  }

  AuthUser _mapUser(User user) {
    final provider = user.providerData.isNotEmpty
        ? user.providerData.first.providerId
        : (user.isAnonymous ? 'Anónimo' : 'firebase');
    return AuthUser(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : 'Detox user',
      provider: provider,
      phoneNumber: user.phoneNumber,
      isAnonymous: user.isAnonymous,
      emailVerified: user.emailVerified,
    );
  }

  String _friendlyAuthMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'credential-already-in-use':
      case 'account-exists-with-different-credential':
        return _t.isEs
            ? 'Ese acceso pertenece a otro perfil. Tu perfil actual se conserva; inicia sesión en el otro perfil para recuperarlo.'
            : 'That credential belongs to another profile. Your current profile is unchanged; sign in to the other profile to recover it.';
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
