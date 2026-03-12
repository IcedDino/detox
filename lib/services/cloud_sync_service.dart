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
    final doc = _userDoc;
    if (doc == null) return;
    await doc.set({
      'habits': habits.map((e) => e.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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
    final doc = _userDoc;
    if (doc == null) return;
    await doc.set({
      'appLimits': limits.map((e) => e.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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
    final doc = _userDoc;
    if (doc == null) return;
    await doc.set({
      'concentrationZones': zones.map((e) => e.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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
    final doc = _userDoc;
    if (doc == null) return;
    await doc.set({
      'dailyLimitMinutes': minutes,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<int?> loadDailyLimitMinutes() async {
    final data = await loadSnapshot();
    final value = data?['dailyLimitMinutes'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  Future<void> saveOnboardingDone(bool done) async {
    final doc = _userDoc;
    if (doc == null) return;
    await doc.set({
      'onboardingDone': done,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<bool?> loadOnboardingDone() async {
    final data = await loadSnapshot();
    final value = data?['onboardingDone'];
    return value is bool ? value : null;
  }
}
