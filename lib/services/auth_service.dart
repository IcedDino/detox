import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/auth_user.dart';
import 'cloud_sync_service.dart';
import 'sponsor_service.dart';
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
        throw AuthException('Account created, but session could not be restored.');
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
      if (user == null) throw AuthException('Could not start your session.');
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
        throw AuthException('Google sign-in was cancelled.');
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) throw AuthException('Google sign-in failed.');
      final mapped = _mapUser(user);
      await CloudSyncService.instance.saveUserProfile(mapped);
      return mapped;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_friendlyAuthMessage(e));
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException(
        'Google sign-in failed on this build. Verify Google is enabled in Firebase and that the Android SHA fingerprints were added.',
      );
    }
  }

  Future<void> startPhoneVerification({
    required String phoneNumber,
    required void Function() onCodeSent,
    required void Function(AuthUser user) onVerified,
  }) async {
    final completer = Completer<void>();
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber.trim(),
        verificationCompleted: (credential) async {
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
          if (!completer.isCompleted) {
            completer.completeError(AuthException(_friendlyAuthMessage(e)));
          }
        },
        codeSent: (verificationId, _) {
          _verificationId = verificationId;
          onCodeSent();
          if (!completer.isCompleted) completer.complete();
        },
        codeAutoRetrievalTimeout: (verificationId) {
          _verificationId = verificationId;
        },
      );
      await completer.future;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_friendlyAuthMessage(e));
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException(
        'Phone sign-in could not be started. Make sure Phone authentication is enabled in Firebase.',
      );
    }
  }

  String? _verificationId;

  Future<AuthUser> verifySmsCode(String code) async {
    final verificationId = _verificationId;
    if (verificationId == null || verificationId.isEmpty) {
      throw AuthException('No SMS verification is active. Request a code first.');
    }
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: code.trim(),
      );
      final result = await _auth.signInWithCredential(credential);
      final user = result.user;
      if (user == null) {
        throw AuthException('The SMS code could not be verified.');
      }
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
      throw AuthException('No active session to delete.');
    }

    try {
      await CloudSyncService.instance.flushPendingWrites();
    } catch (_) {
      // Best effort before removing the remote profile.
    } finally {
      CloudSyncService.instance.cancelPendingWrites();
    }

    try {
      await SponsorService.instance.purgeDeletedAccountReferences(user.uid);
      await CloudSyncService.instance.deleteUserDocument(user.uid);
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
        throw AuthException(
          'Your Detox data was deleted, but Firebase requires a recent sign-in to remove the access account completely. Sign in again and repeat the deletion once more.',
        );
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
          ? 'Detox user'
          : (user.email?.split('@').first ?? 'Detox user')),
      provider: provider,
      phoneNumber: user.phoneNumber,
    );
  }

  String _friendlyAuthMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'That email is already in use.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'user-not-found':
        return 'No account exists with that email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'weak-password':
        return 'Use a stronger password.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled in Firebase yet.';
      case 'invalid-verification-code':
        return 'The SMS code is not valid.';
      case 'session-expired':
        return 'The SMS code expired. Request another one.';
      default:
        return e.message ?? 'Authentication failed.';
    }
  }
}
