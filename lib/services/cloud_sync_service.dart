import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_limit.dart';
import '../models/auth_user.dart';
import '../models/concentration_zone.dart';
import '../models/habit.dart';

class CloudSyncService {
  CloudSyncService._() {
    _observedAuthUid = _auth.currentUser?.uid;
    _authSubscription = _auth.idTokenChanges().listen(_handleAuthStateChanged);
  }
  static final CloudSyncService instance = CloudSyncService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const Duration _writeDebounce = Duration(seconds: 2);
  static const Duration _snapshotCacheTtl = Duration(seconds: 5);
  static const Duration _retryBackoffMin = Duration(seconds: 2);
  static const Duration _retryBackoffMax = Duration(seconds: 30);

  Timer? _flushTimer;
  Timer? _retryTimer;
  String? _queuedUid;
  final Map<String, dynamic> _pendingPatch = <String, dynamic>{};
  final Map<String, String> _lastQueuedFieldHashes = <String, String>{};
  Future<void> _flushChain = Future<void>.value();
  int _retryCount = 0;

  Future<Map<String, dynamic>?>? _snapshotLoadFuture;
  String? _snapshotUid;
  Map<String, dynamic>? _snapshotCache;
  DateTime? _snapshotCachedAt;
  StreamSubscription<User?>? _authSubscription;
  String? _observedAuthUid;

  String? get _uid => _auth.currentUser?.uid;
  String? get currentUid => _uid;
  bool get isSignedIn => _uid != null;


  void _handleAuthStateChanged(User? user) {
    final nextUid = user?.uid;
    final previousUid = _observedAuthUid;
    final switchedUser = previousUid != nextUid;

    if (switchedUser) {
      cancelPendingWrites();
      _snapshotUid = nextUid;
    }

    _observedAuthUid = nextUid;
    _invalidateSnapshotCache(uid: nextUid);

    if (nextUid == null) {
      _snapshotUid = null;
    }
  }

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
    _mergeIntoSnapshotCache(<String, dynamic>{
      'profile': user.toMap(),
      'lastSignInAt': FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, dynamic>?> loadSnapshot({bool force = false}) async {
    final uid = _uid;
    if (uid == null) return null;

    final cachedAt = _snapshotCachedAt;
    final cachedData = _snapshotCache;
    if (!force &&
        _snapshotUid == uid &&
        cachedAt != null &&
        cachedData != null &&
        DateTime.now().difference(cachedAt) <= _snapshotCacheTtl) {
      return Map<String, dynamic>.from(cachedData);
    }

    final inFlight = _snapshotLoadFuture;
    if (!force && _snapshotUid == uid && inFlight != null) {
      final data = await inFlight;
      return data == null ? null : Map<String, dynamic>.from(data);
    }

    final loadFuture = _loadSnapshotFromNetwork(uid);
    _snapshotUid = uid;
    _snapshotLoadFuture = loadFuture;

    try {
      final data = await loadFuture;
      return data == null ? null : Map<String, dynamic>.from(data);
    } finally {
      if (identical(_snapshotLoadFuture, loadFuture)) {
        _snapshotLoadFuture = null;
      }
    }
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

  List<Habit>? habitsFromSnapshot(Map<String, dynamic>? data) {
    final raw = data?['habits'];
    if (raw is! List) return null;
    return raw
        .whereType<Map>()
        .map((e) => Habit.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  List<AppLimit>? appLimitsFromSnapshot(Map<String, dynamic>? data) {
    final raw = data?['appLimits'];
    if (raw is! List) return null;
    return raw
        .whereType<Map>()
        .map((e) => AppLimit.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  List<ConcentrationZone>? concentrationZonesFromSnapshot(
    Map<String, dynamic>? data,
  ) {
    final raw = data?['concentrationZones'];
    if (raw is! List) return null;
    return raw
        .whereType<Map>()
        .map((e) => ConcentrationZone.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  int? dailyLimitMinutesFromSnapshot(Map<String, dynamic>? data) {
    final value = data?['dailyLimitMinutes'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  bool? onboardingDoneFromSnapshot(Map<String, dynamic>? data) {
    final value = data?['onboardingDone'];
    return value is bool ? value : null;
  }

  Future<void> saveHabits(List<Habit> habits) async {
    _queueFieldWrite('habits', habits.map((e) => e.toMap()).toList());
  }

  Future<List<Habit>?> loadHabits() async {
    final data = await loadSnapshot();
    return habitsFromSnapshot(data);
  }

  Future<void> saveAppLimits(List<AppLimit> limits) async {
    _queueFieldWrite('appLimits', limits.map((e) => e.toMap()).toList());
  }

  Future<List<AppLimit>?> loadAppLimits() async {
    final data = await loadSnapshot();
    return appLimitsFromSnapshot(data);
  }

  Future<void> saveConcentrationZones(List<ConcentrationZone> zones) async {
    _queueFieldWrite(
      'concentrationZones',
      zones.map((e) => e.toMap()).toList(),
    );
  }

  Future<List<ConcentrationZone>?> loadConcentrationZones() async {
    final data = await loadSnapshot();
    return concentrationZonesFromSnapshot(data);
  }

  Future<void> saveDailyLimitMinutes(int minutes) async {
    _queueFieldWrite('dailyLimitMinutes', minutes);
  }

  Future<int?> loadDailyLimitMinutes() async {
    final data = await loadSnapshot();
    return dailyLimitMinutesFromSnapshot(data);
  }

  Future<void> saveOnboardingDone(bool done) async {
    _queueFieldWrite('onboardingDone', done);
  }

  Future<bool?> loadOnboardingDone() async {
    final data = await loadSnapshot();
    return onboardingDoneFromSnapshot(data);
  }

  Future<void> flushPendingWrites() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    await _enqueueFlush();
  }

  void cancelPendingWrites() {
    _flushTimer?.cancel();
    _flushTimer = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    _retryCount = 0;
    _pendingPatch.clear();
    _lastQueuedFieldHashes.clear();
    _queuedUid = null;
  }


  Future<void> deleteUserDocument(String uid) async {
    cancelPendingWrites();
    await _firestore.collection('users').doc(uid).delete();
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
    _retryTimer?.cancel();
    _retryTimer = null;

    _flushTimer?.cancel();
    _flushTimer = Timer(_writeDebounce, () {
      unawaited(_enqueueFlush());
    });
  }

  Future<void> _enqueueFlush() {
    _retryTimer?.cancel();
    _retryTimer = null;
    final operation = _flushChain
        .catchError((_) {})
        .then((_) => _flushNow());
    _flushChain = operation.catchError((_) {});
    return operation;
  }

  Future<void> _flushNow() async {
    if (_pendingPatch.isEmpty) return;

    final targetUid = _queuedUid;
    if (targetUid == null) {
      cancelPendingWrites();
      return;
    }

    final doc = _firestore.collection('users').doc(targetUid);
    final patch = Map<String, dynamic>.from(_pendingPatch);
    _pendingPatch.clear();

    try {
      await doc.set({
        ...patch,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _retryCount = 0;
      _mergeIntoSnapshotCache(patch, uid: targetUid);
      for (final entry in patch.entries) {
        _lastQueuedFieldHashes[entry.key] = _stableHash(entry.value);
      }
    } catch (_) {
      if (_queuedUid == targetUid) {
        _pendingPatch.addAll(patch);
        _scheduleRetry();
      }
      rethrow;
    }
  }

  Future<void> markAccountDeleted(AuthUser user) async {
    final uid = _uid;
    final doc = _userDoc;
    if (uid == null || doc == null) return;

    cancelPendingWrites();
    _invalidateSnapshotCache(uid: uid);

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
        'pushToken': FieldValue.delete(),
        'pushTokenUpdatedAt': FieldValue.delete(),
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
    final sponsorMeta = _firestore.collection('meta').doc('sponsor');
    final linkRequests = sponsorMeta.collection('link_requests');
    final unlockRequests = sponsorMeta.collection('unlock_requests');

    await _closeMatchedDocsInBatches(
      collection: linkRequests,
      field: 'requesterUid',
      matchValue: uid,
      closedStatus: 'cancelled',
    );
    await _closeMatchedDocsInBatches(
      collection: linkRequests,
      field: 'targetUid',
      matchValue: uid,
      closedStatus: 'cancelled',
    );
    await _closeMatchedDocsInBatches(
      collection: unlockRequests,
      field: 'requesterUid',
      matchValue: uid,
      closedStatus: 'closed',
    );
    await _closeMatchedDocsInBatches(
      collection: unlockRequests,
      field: 'sponsorUid',
      matchValue: uid,
      closedStatus: 'closed',
    );
  }

  Future<void> _closeMatchedDocsInBatches({
    required CollectionReference<Map<String, dynamic>> collection,
    required String field,
    required String matchValue,
    required String closedStatus,
  }) async {
    const pageSize = 400;
    QueryDocumentSnapshot<Map<String, dynamic>>? lastDoc;

    while (true) {
      Query<Map<String, dynamic>> query = collection
          .where(field, isEqualTo: matchValue)
          .limit(pageSize);
      if (lastDoc != null) {
        query = query.startAfterDocument(lastDoc);
      }

      final snapshot = await query.get();
      if (snapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.set(
          doc.reference,
          {
            'status': closedStatus,
            'closedBecause': 'account_deleted',
            'closedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
      await batch.commit();

      if (snapshot.docs.length < pageSize) return;
      lastDoc = snapshot.docs.last;
    }
  }

  Future<Map<String, dynamic>?> _loadSnapshotFromNetwork(String uid) async {
    final snap = await _firestore.collection('users').doc(uid).get();
    final data = snap.data();
    _snapshotUid = uid;
    _snapshotCachedAt = DateTime.now();
    _snapshotCache = data == null ? null : Map<String, dynamic>.from(data);
    return data == null ? null : Map<String, dynamic>.from(data);
  }

  void _scheduleRetry() {
    _flushTimer?.cancel();
    _flushTimer = null;
    _retryTimer?.cancel();

    final nextRetry = (_retryCount + 1).clamp(1, 6);
    _retryCount = nextRetry;
    final delaySeconds = _retryBackoffMin.inSeconds * (1 << (nextRetry - 1));
    final boundedSeconds = delaySeconds > _retryBackoffMax.inSeconds
        ? _retryBackoffMax.inSeconds
        : delaySeconds;
    _retryTimer = Timer(Duration(seconds: boundedSeconds), () {
      unawaited(_enqueueFlush());
    });
  }

  void _invalidateSnapshotCache({String? uid}) {
    if (uid != null && _snapshotUid != null && _snapshotUid != uid) {
      return;
    }
    _snapshotLoadFuture = null;
    _snapshotCachedAt = null;
    _snapshotCache = null;
    if (uid != null) {
      _snapshotUid = uid;
    }
  }

  void _mergeIntoSnapshotCache(Map<String, dynamic> patch, {String? uid}) {
    final effectiveUid = uid ?? _uid;
    if (effectiveUid == null) return;
    if (_snapshotUid != effectiveUid) {
      _snapshotUid = effectiveUid;
      _snapshotCache = <String, dynamic>{};
    }
    final cache = Map<String, dynamic>.from(_snapshotCache ?? const <String, dynamic>{});
    for (final entry in patch.entries) {
      cache[entry.key] = entry.value;
    }
    _snapshotCache = cache;
    _snapshotCachedAt = DateTime.now();
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
