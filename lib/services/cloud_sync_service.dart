import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_limit.dart';
import '../models/auth_user.dart';
import '../models/concentration_zone.dart';
import '../models/habit.dart';

class CloudSyncService {
  CloudSyncService._();
  static final CloudSyncService instance = CloudSyncService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const Duration _writeDebounce = Duration(seconds: 2);

  Timer? _flushTimer;
  String? _queuedUid;
  final Map<String, dynamic> _pendingPatch = <String, dynamic>{};
  final Map<String, String> _lastQueuedFieldHashes = <String, String>{};
  Future<void> _flushChain = Future<void>.value();

  String? get _uid => _auth.currentUser?.uid;
  bool get isSignedIn => _uid != null;

  DocumentReference<Map<String, dynamic>>? get _userDoc {
    final uid = _uid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid);
  }

  Future<void> saveUserProfile(AuthUser user) async {
    final doc = _userDoc;
    if (doc == null) return;
    await doc.set({
      'profile': user.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastSignInAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> loadSnapshot() async {
    final doc = _userDoc;
    if (doc == null) return null;
    final snap = await doc.get();
    return snap.data();
  }

  Future<bool> hasRemoteData() async {
    final data = await loadSnapshot();
    if (data == null) return false;
    return data.containsKey('habits') ||
        data.containsKey('appLimits') ||
        data.containsKey('concentrationZones') ||
        data.containsKey('dailyLimitMinutes') ||
        data.containsKey('onboardingDone');
  }

  Future<void> saveHabits(List<Habit> habits) async {
    _queueFieldWrite('habits', habits.map((e) => e.toMap()).toList());
  }

  Future<List<Habit>?> loadHabits() async {
    final data = await loadSnapshot();
    final raw = data?['habits'];
    if (raw is! List) return null;
    return raw
        .whereType<Map>()
        .map((e) => Habit.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> saveAppLimits(List<AppLimit> limits) async {
    _queueFieldWrite('appLimits', limits.map((e) => e.toMap()).toList());
  }

  Future<List<AppLimit>?> loadAppLimits() async {
    final data = await loadSnapshot();
    final raw = data?['appLimits'];
    if (raw is! List) return null;
    return raw
        .whereType<Map>()
        .map((e) => AppLimit.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> saveConcentrationZones(List<ConcentrationZone> zones) async {
    _queueFieldWrite(
      'concentrationZones',
      zones.map((e) => e.toMap()).toList(),
    );
  }

  Future<List<ConcentrationZone>?> loadConcentrationZones() async {
    final data = await loadSnapshot();
    final raw = data?['concentrationZones'];
    if (raw is! List) return null;
    return raw
        .whereType<Map>()
        .map((e) => ConcentrationZone.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> saveDailyLimitMinutes(int minutes) async {
    _queueFieldWrite('dailyLimitMinutes', minutes);
  }

  Future<int?> loadDailyLimitMinutes() async {
    final data = await loadSnapshot();
    final value = data?['dailyLimitMinutes'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  Future<void> saveOnboardingDone(bool done) async {
    _queueFieldWrite('onboardingDone', done);
  }

  Future<bool?> loadOnboardingDone() async {
    final data = await loadSnapshot();
    final value = data?['onboardingDone'];
    return value is bool ? value : null;
  }

  Future<void> flushPendingWrites() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    await _enqueueFlush();
  }

  void cancelPendingWrites() {
    _flushTimer?.cancel();
    _flushTimer = null;
    _pendingPatch.clear();
    _lastQueuedFieldHashes.clear();
    _queuedUid = null;
  }

  void _queueFieldWrite(String field, dynamic value) {
    final uid = _uid;
    if (uid == null) return;

    if (_queuedUid != null && _queuedUid != uid) {
      cancelPendingWrites();
    }
    _queuedUid = uid;

    final hash = _stableHash(value);
    final pendingHash = _lastQueuedFieldHashes[field];
    if (pendingHash == hash) {
      return;
    }

    _pendingPatch[field] = value;
    _lastQueuedFieldHashes[field] = hash;

    _flushTimer?.cancel();
    _flushTimer = Timer(_writeDebounce, () {
      unawaited(_enqueueFlush());
    });
  }

  Future<void> _enqueueFlush() {
    _flushChain = _flushChain.then((_) => _flushNow());
    return _flushChain;
  }

  Future<void> _flushNow() async {
    if (_pendingPatch.isEmpty) return;

    final currentUid = _uid;
    final queuedUid = _queuedUid;
    if (currentUid == null || queuedUid == null || currentUid != queuedUid) {
      cancelPendingWrites();
      return;
    }

    final doc = _userDoc;
    if (doc == null) return;

    final patch = Map<String, dynamic>.from(_pendingPatch);
    _pendingPatch.clear();

    try {
      await doc.set({
        ...patch,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      for (final entry in patch.entries) {
        _lastQueuedFieldHashes[entry.key] = _stableHash(entry.value);
      }
    } catch (_) {
      _pendingPatch.addAll(patch);
      _flushTimer?.cancel();
      _flushTimer = Timer(_writeDebounce, () {
        unawaited(_enqueueFlush());
      });
      rethrow;
    }
  }

  Future<void> markAccountDeleted(AuthUser user) async {
    final uid = _uid;
    final doc = _userDoc;
    if (uid == null || doc == null) return;

    cancelPendingWrites();

    final userSnapshot = await doc.get();
    final userData = userSnapshot.data() ?? <String, dynamic>{};
    final sponsorUid = (userData['sponsorUid'] as String?)?.trim();

    final batch = _firestore.batch();
    batch.set(
      doc,
      {
        'accountDeleted': true,
        'accountDeletedAt': FieldValue.serverTimestamp(),
        'deletionSource': 'self_service_mobile',
        'profile': {
          'uid': uid,
          'email': '',
          'displayName': user.displayName,
          'provider': 'deleted',
          'phoneNumber': null,
        },
        'habits': FieldValue.delete(),
        'appLimits': FieldValue.delete(),
        'concentrationZones': FieldValue.delete(),
        'dailyLimitMinutes': FieldValue.delete(),
        'onboardingDone': FieldValue.delete(),
        'sponsorUid': FieldValue.delete(),
        'sponsorLinkedAt': FieldValue.delete(),
        'settingsUnlockUntil': FieldValue.delete(),
        'zoneOverrideUntil': FieldValue.delete(),
        'shieldPauseUntil': FieldValue.delete(),
        'unlinkEmailCode': FieldValue.delete(),
        'unlinkEmailCodeExpiresAt': FieldValue.delete(),
        'unlinkEmailRequestId': FieldValue.delete(),
        'fcmToken': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    if (sponsorUid != null && sponsorUid.isNotEmpty) {
      final sponsorRef = _firestore.collection('users').doc(sponsorUid);
      final sponsorSnapshot = await sponsorRef.get();
      final sponsorData = sponsorSnapshot.data() ?? <String, dynamic>{};
      if (sponsorData['sponsorUid'] == uid) {
        batch.set(
          sponsorRef,
          {
            'sponsorUid': FieldValue.delete(),
            'sponsorLinkedAt': FieldValue.delete(),
            'settingsUnlockUntil': FieldValue.delete(),
            'zoneOverrideUntil': FieldValue.delete(),
            'shieldPauseUntil': FieldValue.delete(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
    }

    await batch.commit();
    await _closeSponsorRequestDocs(uid);
  }

  Future<void> _closeSponsorRequestDocs(String uid) async {
    Future<void> closeMatches({
      required CollectionReference<Map<String, dynamic>> collection,
      required String field,
      required String closedStatus,
    }) async {
      final snapshot = await collection.where(field, isEqualTo: uid).get();
      for (final doc in snapshot.docs) {
        await doc.reference.set(
          {
            'status': closedStatus,
            'closedBecause': 'account_deleted',
            'closedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
    }

    final sponsorMeta = _firestore.collection('meta').doc('sponsor');
    final linkRequests = sponsorMeta.collection('link_requests');
    final unlockRequests = sponsorMeta.collection('unlock_requests');

    await closeMatches(
      collection: linkRequests,
      field: 'requesterUid',
      closedStatus: 'cancelled',
    );
    await closeMatches(
      collection: linkRequests,
      field: 'targetUid',
      closedStatus: 'cancelled',
    );
    await closeMatches(
      collection: unlockRequests,
      field: 'requesterUid',
      closedStatus: 'closed',
    );
    await closeMatches(
      collection: unlockRequests,
      field: 'sponsorUid',
      closedStatus: 'closed',
    );
  }

  String _stableHash(dynamic value) {
    return jsonEncode(_canonicalize(value));
  }

  dynamic _canonicalize(dynamic value) {
    if (value is Map) {
      final keys = value.keys.map((e) => e.toString()).toList()..sort();
      return {
        for (final key in keys) key: _canonicalize(value[key]),
      };
    }
    if (value is Iterable) {
      return value.map(_canonicalize).toList();
    }
    return value;
  }
}
