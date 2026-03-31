import 'dart:async';

import '../models/sponsor_request.dart';
import 'app_blocking_service.dart';
import 'focus_notification_service.dart';
import 'sponsor_service.dart';

class SponsorAlertService {
  SponsorAlertService._();
  static final SponsorAlertService instance = SponsorAlertService._();

  StreamSubscription<List<SponsorRequest>>? _incomingSub;
  StreamSubscription<List<SponsorRequest>>? _outgoingSub;
  final Map<String, String> _seenStates = {};
  bool _incomingPrimed = false;
  bool _outgoingPrimed = false;

  void start() {
    stop();
    _incomingSub = SponsorService.instance.incomingRequests().listen(_onIncoming);
    _outgoingSub = SponsorService.instance.outgoingRequests().listen(_onOutgoing);
  }

  void stop() {
    _incomingSub?.cancel();
    _outgoingSub?.cancel();
    _incomingSub = null;
    _outgoingSub = null;
    _seenStates.clear();
    _incomingPrimed = false;
    _outgoingPrimed = false;
  }

  void _onIncoming(List<SponsorRequest> requests) {
    var notify = _incomingPrimed;
    for (final request in requests) {
      final key = 'in_${request.id}';
      final signature = '${request.status}_${request.code ?? ''}';
      final previous = _seenStates[key];
      _seenStates[key] = signature;
      if (!notify || previous == signature) continue;
      if (request.isPending) {
        FocusNotificationService.instance.showSponsorAlert(
          id: request.id.hashCode & 0x7fffffff,
          title: 'Sponsor request',
          body: '${request.requesterName} requested ${request.prettyType.toLowerCase()}.',
        );
      }
    }
    _incomingPrimed = true;
  }

  void _onOutgoing(List<SponsorRequest> requests) {
    var notify = _outgoingPrimed;
    for (final request in requests) {
      final key = 'out_${request.id}';
      final signature = '${request.status}_${request.code ?? ''}';
      final previous = _seenStates[key];
      _seenStates[key] = signature;
      if (!notify || previous == signature) continue;
      if (request.requestType == 'shield_pause' && request.isApproved && !request.isExpired) {
        unawaited(AppBlockingService.instance.suspendForMinutes(request.durationMinutes));
        FocusNotificationService.instance.showSponsorAlert(
          id: (request.id.hashCode + 150000) & 0x7fffffff,
          title: '15-minute pause approved',
          body: 'Your sponsor approved an app shield pause.',
        );
      } else if (request.isApproved && (request.code?.isNotEmpty ?? false) && !request.isExpired) {
        FocusNotificationService.instance.showSponsorAlert(
          id: (request.id.hashCode + 100000) & 0x7fffffff,
          title: 'Your sponsor code is ready',
          body: '${request.prettyType} code received. It expires in 3 minutes.',
        );
      }
      if (request.isEmailed && !request.isExpired) {
        FocusNotificationService.instance.showSponsorAlert(
          id: (request.id.hashCode + 200000) & 0x7fffffff,
          title: 'Unlink code email requested',
          body: 'Check your email for the Detox unlink code.',
        );
      }
    }
    _outgoingPrimed = true;
  }
}
