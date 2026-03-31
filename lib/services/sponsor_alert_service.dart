import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/sponsor_request.dart';
import 'app_blocking_service.dart';
import 'focus_notification_service.dart';
import 'sponsor_service.dart';

class SponsorAlertService {
  SponsorAlertService._();
  static final SponsorAlertService instance = SponsorAlertService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userDocSub;
  StreamSubscription<List<SponsorRequest>>? _incomingSub;
  StreamSubscription<List<SponsorRequest>>? _outgoingSub;

  final Map<String, String> _seenStates = {};

  bool _started = false;
  bool _hasSponsor = false;
  bool _watchIncoming = false;
  bool _watchOutgoing = false;

  String? get _uid => _auth.currentUser?.uid;

  DocumentReference<Map<String, dynamic>>? get _userDoc {
    final uid = _uid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid);
  }

  void start() {
    stop();
    _started = true;
    _listenToUserProfile();
    unawaited(_refreshStreams());
  }

  void stop() {
    _started = false;
    _userDocSub?.cancel();
    _incomingSub?.cancel();
    _outgoingSub?.cancel();
    _userDocSub = null;
    _incomingSub = null;
    _outgoingSub = null;
    _hasSponsor = false;
    _watchIncoming = false;
    _watchOutgoing = false;
    _seenStates.clear();
  }

  void _listenToUserProfile() {
    final userDoc = _userDoc;
    if (!_started || userDoc == null) return;

    _userDocSub = userDoc.snapshots().listen((snap) {
      final data = snap.data() ?? const <String, dynamic>{};
      final sponsorUid = data['sponsorUid'] as String?;
      final hasSponsorNow = sponsorUid != null && sponsorUid.isNotEmpty;
      if (hasSponsorNow != _hasSponsor) {
        _hasSponsor = hasSponsorNow;
        unawaited(_refreshStreams());
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
    final shouldWatchIncoming = _hasSponsor;
    final shouldWatchOutgoing = _hasSponsor || hasPendingOutgoing;

    if (!shouldWatchIncoming && _watchIncoming) {
      await _incomingSub?.cancel();
      _incomingSub = null;
      _watchIncoming = false;
      _clearSeenByPrefix('in_');
    } else if (shouldWatchIncoming && !_watchIncoming) {
      _incomingSub = SponsorService.instance
          .incomingRequests()
          .listen(_onIncoming, onError: (_) {});
      _watchIncoming = true;
    }

    if (!shouldWatchOutgoing && _watchOutgoing) {
      await _outgoingSub?.cancel();
      _outgoingSub = null;
      _watchOutgoing = false;
      _clearSeenByPrefix('out_');
    } else if (shouldWatchOutgoing && !_watchOutgoing) {
      _outgoingSub = SponsorService.instance
          .outgoingRequests()
          .listen(_onOutgoing, onError: (_) {});
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

  void _clearSeenByPrefix(String prefix) {
    final keys = _seenStates.keys.where((key) => key.startsWith(prefix)).toList();
    for (final key in keys) {
      _seenStates.remove(key);
    }
  }

  void _onIncoming(List<SponsorRequest> requests) {
    for (final request in requests) {
      final key = 'in_${request.id}';
      final signature = '${request.status}_${request.code ?? ''}';
      if (_seenStates[key] == signature) continue;
      _seenStates[key] = signature;

      if (request.isPending) {
        FocusNotificationService.instance.showSponsorAlert(
          id: request.id.hashCode & 0x7fffffff,
          title: 'Sponsor request',
          body:
          '${request.requesterName} requested ${request.prettyType.toLowerCase()}.',
        );
      }
    }
  }

  void _onOutgoing(List<SponsorRequest> requests) {
    var stillHasPendingOutgoing = false;

    for (final request in requests) {
      if (request.isPending) {
        stillHasPendingOutgoing = true;
      }

      final key = 'out_${request.id}';
      final signature = '${request.status}_${request.code ?? ''}';
      if (_seenStates[key] == signature) continue;
      _seenStates[key] = signature;

      if (request.requestType == 'shield_pause' &&
          request.isApproved &&
          !request.isExpired) {
        unawaited(
          AppBlockingService.instance.suspendForMinutes(request.durationMinutes),
        );
        FocusNotificationService.instance.showSponsorAlert(
          id: (request.id.hashCode + 150000) & 0x7fffffff,
          title: '15-minute pause approved',
          body: 'Your sponsor approved an app shield pause.',
        );
      } else if (request.isApproved &&
          !request.isExpired &&
          (request.code?.isNotEmpty ?? false)) {
        FocusNotificationService.instance.showSponsorAlert(
          id: (request.id.hashCode + 100000) & 0x7fffffff,
          title: 'Your sponsor code is ready',
          body: '${request.prettyType} code received. It expires in 3 minutes.',
        );
      }

      if (request.isEmailed) {
        FocusNotificationService.instance.showSponsorAlert(
          id: (request.id.hashCode + 200000) & 0x7fffffff,
          title: 'Unlink code email requested',
          body: 'Check your email for the Detox unlink code.',
        );
      }
    }

    if (!_hasSponsor && !stillHasPendingOutgoing) {
      unawaited(_refreshStreams());
    }
  }
}
