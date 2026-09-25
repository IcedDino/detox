import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../l10n_app_strings.dart';
import '../models/link_requests.dart';
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
  StreamSubscription<List<LinkRequest>>? _incomingLinkSub;
  StreamSubscription<List<LinkRequest>>? _outgoingLinkSub;

  final Map<String, String> _seenStates = {};

  /// Pending link requests I sent. When one leaves the stream it was resolved
  /// (accepted or rejected) and the user gets told right away.
  final Set<String> _pendingOutgoingLinkIds = {};

  bool _started = false;
  String? _startedUid;
  bool _hasSponsor = false;
  bool _watchIncoming = false;
  bool _watchOutgoing = false;
  bool _permissionRequested = false;

  String? get _uid => _auth.currentUser?.uid;

  DocumentReference<Map<String, dynamic>>? get _userDoc {
    final uid = _uid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid);
  }

  void start() {
    final uid = _uid;
    if (uid == null) return;
    if (_started && _startedUid == uid) return;
    if (_started) stop();
    _started = true;
    _startedUid = uid;
    _listenToUserProfile();
    _listenToLinkRequests();
    unawaited(_refreshStreams());
  }

  void stop() {
    _started = false;
    _startedUid = null;
    _userDocSub?.cancel();
    _incomingSub?.cancel();
    _outgoingSub?.cancel();
    _incomingLinkSub?.cancel();
    _outgoingLinkSub?.cancel();
    _userDocSub = null;
    _incomingSub = null;
    _outgoingSub = null;
    _incomingLinkSub = null;
    _outgoingLinkSub = null;
    _hasSponsor = false;
    _watchIncoming = false;
    _watchOutgoing = false;
    _permissionRequested = false;
    _seenStates.clear();
    _pendingOutgoingLinkIds.clear();
  }

  /// Link requests can arrive even before there is a sponsor, so these streams
  /// stay active the whole time the user is signed in.
  void _listenToLinkRequests() {
    if (!_started) return;
    _incomingLinkSub ??= SponsorService.instance
        .incomingLinkRequests()
        .listen(_onIncomingLinks, onError: (_) {});
    _outgoingLinkSub ??= SponsorService.instance
        .outgoingLinkRequests()
        .listen(_onOutgoingLinks, onError: (_) {});
  }

  Future<void> _ensureNotificationPermission() async {
    if (_permissionRequested) return;
    _permissionRequested = true;
    await requestNotificationPermission();
  }

  /// Asks for the notification permission when the user opens a screen where
  /// request alerts are expected to appear.
  Future<void> requestNotificationPermission() async {
    try {
      final notifications = FocusNotificationService.instance;
      if (await notifications.hasPermission()) return;
      await notifications.requestPermission();
    } catch (_) {}
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
        unawaited(AppBlockingService.instance.syncSponsorState(_hasSponsor));
        unawaited(_refreshStreams());
        if (hasSponsorNow) {
          unawaited(_ensureNotificationPermission());
        }
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
    final keys =
        _seenStates.keys.where((key) => key.startsWith(prefix)).toList();
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
        final isUnlink = request.requestType == 'unlink_sponsor';
        unawaited(
          FocusNotificationService.instance.showSponsorAlert(
            id: request.id.hashCode & 0x7fffffff,
            title: isUnlink
                ? AppStrings.current.notifyUnlinkRequestTitle
                : AppStrings.current.notifySponsorRequestTitle,
            body: isUnlink
                ? AppStrings.current.notifyUnlinkRequestBody(
                    request.requesterName,
                    request.message,
                  )
                : AppStrings.current.notifySponsorRequestBody(
                    request.requesterName,
                    request.prettyType,
                    request.message,
                  ),
          ),
        );
      }
    }
  }

  /// Appends the sponsor answer to a notification body when there is one.
  String _withReply(String body, String? replyMessage) {
    final reply = replyMessage?.trim() ?? '';
    return reply.isEmpty ? body : '$body\n“$reply”';
  }

  void _onIncomingLinks(List<LinkRequest> requests) {
    for (final request in requests) {
      final key = 'lin_${request.id}';
      if (_seenStates[key] == request.status) continue;
      _seenStates[key] = request.status;

      unawaited(
        FocusNotificationService.instance.showSponsorAlert(
          id: (request.id.hashCode + 300000) & 0x7fffffff,
          title: AppStrings.current.notifyLinkRequestTitle,
          body: AppStrings.current.notifyLinkRequestBody(request.requesterName),
        ),
      );
    }
  }

  void _onOutgoingLinks(List<LinkRequest> requests) {
    final currentIds = requests.map((request) => request.id).toSet();
    final resolvedIds =
        _pendingOutgoingLinkIds.where((id) => !currentIds.contains(id)).toList();

    _pendingOutgoingLinkIds
      ..clear()
      ..addAll(currentIds);

    for (final id in resolvedIds) {
      unawaited(_notifyResolvedLink(id));
    }
  }

  Future<void> _notifyResolvedLink(String requestId) async {
    try {
      final snap = await _firestore
          .collection('meta')
          .doc('sponsor')
          .collection('link_requests')
          .doc(requestId)
          .get();
      final data = snap.data();
      if (data == null) return;

      final status = data['status'] as String? ?? '';
      final name = (data['targetName'] as String?)?.trim().isNotEmpty == true
          ? (data['targetName'] as String).trim()
          : AppStrings.current.defaultUserName;
      final baseId = (requestId.hashCode + 400000) & 0x7fffffff;

      if (status == 'accepted') {
        await FocusNotificationService.instance.showSponsorAlert(
          id: baseId,
          title: AppStrings.current.notifyLinkAcceptedTitle,
          body: AppStrings.current.notifyLinkAcceptedBody(name),
        );
      } else if (status == 'rejected') {
        await FocusNotificationService.instance.showSponsorAlert(
          id: baseId,
          title: AppStrings.current.notifyLinkRejectedTitle,
          body: AppStrings.current.notifyLinkRejectedBody(name),
        );
      }
    } catch (_) {}
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

      if (request.isRejected) {
        final isUnlink = request.requestType == 'unlink_sponsor';
        unawaited(
          FocusNotificationService.instance.showSponsorAlert(
            id: (request.id.hashCode + 500000) & 0x7fffffff,
            title: isUnlink
                ? AppStrings.current.notifyUnlinkDeniedTitle
                : AppStrings.current.notifyRequestDeniedTitle,
            body: _withReply(
              isUnlink
                  ? AppStrings.current.notifyUnlinkDeniedBody
                  : AppStrings.current
                      .notifyRequestDeniedBody(request.prettyType),
              request.replyMessage,
            ),
          ),
        );
      } else if (request.requestType == 'shield_pause' &&
          request.isApproved &&
          !request.isExpired) {
        unawaited(
          AppBlockingService.instance
              .suspendForMinutes(request.durationMinutes),
        );
        unawaited(
          FocusNotificationService.instance.showSponsorAlert(
            id: (request.id.hashCode + 150000) & 0x7fffffff,
            title: AppStrings.current.notifyPauseApprovedTitle,
            body: _withReply(
              AppStrings.current.notifyPauseApprovedBody,
              request.replyMessage,
            ),
          ),
        );
      } else if (request.requestType == 'unlink_sponsor' &&
          request.isApproved &&
          !request.isExpired) {
        unawaited(
          FocusNotificationService.instance.showSponsorAlert(
            id: (request.id.hashCode + 250000) & 0x7fffffff,
            title: AppStrings.current.notifyUnlinkApprovedTitle,
            body: _withReply(
              AppStrings.current.notifyUnlinkApprovedBody,
              request.replyMessage,
            ),
          ),
        );
      } else if (request.isApproved &&
          !request.isExpired &&
          (request.code?.isNotEmpty ?? false)) {
        unawaited(
          FocusNotificationService.instance.showSponsorAlert(
            id: (request.id.hashCode + 100000) & 0x7fffffff,
            title: AppStrings.current.notifyCodeReadyTitle,
            body: _withReply(
              AppStrings.current.notifyCodeReadyBody(request.prettyType),
              request.replyMessage,
            ),
          ),
        );
      }

      if (request.isEmailed) {
        unawaited(
          FocusNotificationService.instance.showSponsorAlert(
            id: (request.id.hashCode + 200000) & 0x7fffffff,
            title: AppStrings.current.notifyUnlinkEmailTitle,
            body: AppStrings.current.notifyUnlinkEmailBody,
          ),
        );
      }
    }

    if (!_hasSponsor && !stillHasPendingOutgoing) {
      unawaited(_refreshStreams());
    }
  }
}
