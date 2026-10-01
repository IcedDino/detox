import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/sponsor_request.dart';
import 'app_blocking_service.dart';
import 'focus_notification_service.dart';
import 'sponsor_service.dart';

/// Keeps sponsor side effects in sync. Sponsor notifications are delivered by
/// FCM, so Firestore snapshots must never post another copy of an alert.
class SponsorAlertService {
  SponsorAlertService._();
  static final SponsorAlertService instance = SponsorAlertService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userDocSub;
  StreamSubscription<List<SponsorRequest>>? _outgoingSub;
  final Map<String, String> _seenOutgoingStates = {};

  bool _started = false;
  String? _startedUid;
  bool _hasSponsor = false;
  bool _watchOutgoing = false;
  bool _permissionRequested = false;

  String? get _uid => _auth.currentUser?.uid;

  void start() {
    final uid = _uid;
    if (uid == null) return;
    if (_started && _startedUid == uid) return;
    if (_started) stop();
    _started = true;
    _startedUid = uid;
    _listenToUserProfile();
    unawaited(_refreshStreams());
  }

  void stop() {
    _started = false;
    _startedUid = null;
    _userDocSub?.cancel();
    _outgoingSub?.cancel();
    _userDocSub = null;
    _outgoingSub = null;
    _hasSponsor = false;
    _watchOutgoing = false;
    _permissionRequested = false;
    _seenOutgoingStates.clear();
  }

  Future<void> _ensureNotificationPermission() async {
    if (_permissionRequested) return;
    _permissionRequested = true;
    await requestNotificationPermission();
  }

  Future<void> requestNotificationPermission() async {
    try {
      final notifications = FocusNotificationService.instance;
      if (await notifications.hasPermission()) return;
      await notifications.requestPermission();
    } catch (_) {}
  }

  void _listenToUserProfile() {
    final uid = _uid;
    if (!_started || uid == null) return;
    _userDocSub = _firestore.collection('users').doc(uid).snapshots().listen((
      snap,
    ) {
      final data = snap.data() ?? const <String, dynamic>{};
      final sponsorUid = data['sponsorUid'] as String?;
      final hasSponsorNow = sponsorUid != null && sponsorUid.isNotEmpty;
      if (hasSponsorNow != _hasSponsor) {
        _hasSponsor = hasSponsorNow;
        unawaited(AppBlockingService.instance.syncSponsorState(_hasSponsor));
        unawaited(_refreshStreams());
        if (hasSponsorNow) unawaited(_ensureNotificationPermission());
      }
    });
  }

  Future<void> _refreshStreams() async {
    if (!_started) return;
    final uid = _uid;
    if (uid == null) {
      stop();
      return;
    }

    final hasPendingOutgoing = await _hasPendingOutgoing(uid);
    if (!_started || _uid != uid) return;
    final shouldWatchOutgoing = _hasSponsor || hasPendingOutgoing;
    if (!shouldWatchOutgoing && _watchOutgoing) {
      await _outgoingSub?.cancel();
      _outgoingSub = null;
      _watchOutgoing = false;
      _seenOutgoingStates.clear();
    } else if (shouldWatchOutgoing && !_watchOutgoing) {
      _outgoingSub = SponsorService.instance.outgoingRequests().listen(
        _onOutgoing,
        onError: (_) {},
      );
      _watchOutgoing = true;
    }
  }

  Future<bool> _hasPendingOutgoing(String uid) async {
    try {
      final snap = await _firestore
          .collection('meta')
          .doc('sponsor')
          .collection('unlock_requests')
          .where('requesterUid', isEqualTo: uid)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();
      return snap.docs.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void _onOutgoing(List<SponsorRequest> requests) {
    var stillHasPendingOutgoing = false;
    for (final request in requests) {
      if (request.isPending) stillHasPendingOutgoing = true;

      final signature = '${request.status}_${request.code ?? ''}';
      if (_seenOutgoingStates[request.id] == signature) continue;
      _seenOutgoingStates.remove(request.id);
      _seenOutgoingStates[request.id] = signature;
      while (_seenOutgoingStates.length > 200) {
        _seenOutgoingStates.remove(_seenOutgoingStates.keys.first);
      }

      if (request.requestType == 'shield_pause' &&
          request.isApproved &&
          !request.isExpired) {
        unawaited(
          AppBlockingService.instance.suspendForMinutes(
            request.durationMinutes,
          ),
        );
      }
    }

    if (!_hasSponsor && !stillHasPendingOutgoing) {
      unawaited(_refreshStreams());
    }
  }
}
