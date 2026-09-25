import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../l10n_app_strings.dart';
import '../models/link_requests.dart';
import '../models/sponsor_profile.dart';
import '../models/sponsor_request.dart';
import '../services/app_blocking_service.dart';
import '../services/location_zone_service.dart';
import '../services/sponsor_alert_service.dart';
import '../services/sponsor_service.dart';
import '../theme/app_theme.dart';
import '../widgets/message_prompt_dialog.dart';
import '../widgets/ui_kit.dart';

class SponsorScreen extends StatefulWidget {
  const SponsorScreen({super.key});

  @override
  State<SponsorScreen> createState() => _SponsorScreenState();
}

/// Live state of a request, rendered with a [StatusPill].
class _RequestState {
  const _RequestState(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;
}

class _SponsorScreenState extends State<SponsorScreen>
    with WidgetsBindingObserver {
  AppStrings get t => AppStrings.of(context);
  final SponsorService _sponsorService = SponsorService.instance;
  final TextEditingController _codeController = TextEditingController();

  bool _loading = true;
  bool _linkActionBusy = false;
  bool _requestActionBusy = false;

  String _myCode = '';
  SponsorProfile? _sponsor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    // The user came here on purpose, so this is the right moment to ask for the
    // notification permission that makes request alerts appear.
    unawaited(SponsorAlertService.instance.requestNotificationPermission());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _codeController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      await _sponsorService.ensureCurrentUserInitialized();
      final sponsorContext = await _sponsorService.loadCurrentUserContext();
      final sponsor = sponsorContext.sponsorProfile;

      await AppBlockingService.instance.syncSponsorState(sponsor != null);
      await LocationZoneService.instance.refresh();

      if (!mounted) return;

      setState(() {
        _myCode = sponsorContext.sponsorCode;
        _sponsor = sponsor;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack(e.toString());
    }
  }

  Future<void> _request(String type) async {
    if (type == 'zone_override' && !await _ensureLocationForZonePause()) {
      return;
    }
    if (!mounted) return;

    final message = await showMessagePrompt(
      context,
      title: t.requestMessageTitle,
      hint: t.requestMessageHint,
      confirmLabel: t.sendRequestLabel,
    );
    if (message == null) return;

    try {
      await _sponsorService.createUnlockRequest(
        requestType: type,
        durationMinutes: type == 'settings_unlock' ? 10 : 15,
        message: message,
      );
      _snack(
        type == 'settings_unlock'
            ? t.settingsRequestSent
            : t.zonePauseRequestSent,
      );
      await _refresh();
    } catch (e) {
      _snack(e.toString());
    }
  }

  /// Zone pauses only make sense with location permission: the shield must
  /// know when the user is actually inside a concentration zone. Without it,
  /// ask for the permission first; if the user declines, the pause request is
  /// not sent.
  Future<bool> _ensureLocationForZonePause() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      return true;
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.unableToDetermine) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        await LocationZoneService.instance.refresh();
        return true;
      }
    }

    if (!mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          t.isEs
              ? 'Necesitamos el permiso de ubicación para usar pausas por zona. Actívalo para solicitar esta pausa.'
              : 'Location permission is needed for zone pauses. Enable it to request this pause.',
        ),
      ),
    );
    return false;
  }

  /// Sends the unlink request to the sponsor, who answers it with accept or
  /// deny from their own sponsor center.
  Future<void> _requestSponsorUnlink() async {
    final message = await showMessagePrompt(
      context,
      title: t.requestMessageTitle,
      hint: t.requestMessageHint,
      confirmLabel: t.sendRequestLabel,
    );
    if (message == null) return;

    try {
      await _sponsorService.requestUnlinkSponsor(message: message);
      _snack(t.unlinkRequestSentSponsor);
      await _refresh();
    } catch (e) {
      _snack(e.toString());
    }
  }

  /// Leaves the request in Firestore so the Detox team can answer it.
  Future<void> _requestSupportUnlink() async {
    final message = await showMessagePrompt(
      context,
      title: t.requestMessageTitle,
      hint: t.requestMessageHint,
      confirmLabel: t.sendRequestLabel,
    );
    if (message == null) return;

    try {
      await _sponsorService.requestSupportUnlink(message: message);
      _snack(t.unlinkRequestSentSupport);
    } catch (e) {
      _snack(e.toString());
    }
  }

  /// Sponsors accept an unlink request; the link disappears for both users.
  Future<void> _acceptUnlink(SponsorRequest request) async {
    if (_requestActionBusy) return;

    final reply = await showMessagePrompt(
      context,
      title: t.replyMessageTitle,
      hint: t.replyMessageHint,
      confirmLabel: t.approveWithMessage,
    );
    if (reply == null) return;

    setState(() => _requestActionBusy = true);
    try {
      await _sponsorService.approveUnlinkRequest(
        request.id,
        replyMessage: reply,
      );
      await AppBlockingService.instance.syncSponsorState(false);
      await LocationZoneService.instance.refresh();

      if (!mounted) return;
      _snack(t.sponsorLinkRemoved);
      await _refresh();
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) {
        setState(() => _requestActionBusy = false);
      }
    }
  }

  Future<void> _approveDirect(SponsorRequest request) async {
    if (_requestActionBusy) return;

    final reply = await showMessagePrompt(
      context,
      title: t.replyMessageTitle,
      hint: t.replyMessageHint,
      confirmLabel: t.approveWithMessage,
    );
    if (reply == null) return;

    setState(() => _requestActionBusy = true);
    try {
      await _sponsorService.approveDirectRequest(
        request.id,
        replyMessage: reply,
      );
      if (!mounted) return;
      _snack(
        request.requestType == 'settings_unlock'
            ? t.settingsAccessApproved
            : request.requestType == 'shield_pause'
                ? t.shieldPauseApproved
                : t.zonePauseApproved,
      );
      await _refresh();
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) {
        setState(() => _requestActionBusy = false);
      }
    }
  }

  Future<void> _rejectRequest(SponsorRequest request) async {
    if (_requestActionBusy) return;

    final reply = await showMessagePrompt(
      context,
      title: t.replyMessageTitle,
      hint: t.replyMessageHint,
      confirmLabel: t.denyWithMessage,
      isDestructive: true,
    );
    if (reply == null) return;

    setState(() => _requestActionBusy = true);
    try {
      await _sponsorService.rejectRequest(request.id, replyMessage: reply);
      if (!mounted) return;
      _snack(t.requestRejected);
      await _refresh();
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) {
        setState(() => _requestActionBusy = false);
      }
    }
  }

  Future<void> _approveWithCode(SponsorRequest request) async {
    if (_requestActionBusy) return;

    final reply = await showMessagePrompt(
      context,
      title: t.replyMessageTitle,
      hint: t.replyMessageHint,
      confirmLabel: t.approveWithMessage,
    );
    if (reply == null) return;

    setState(() => _requestActionBusy = true);
    try {
      final code = await _sponsorService.approveRequest(
        request.id,
        replyMessage: reply,
      );
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(request.prettyType),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${t.giveCodeTo} ${request.requesterName}.'),
              const SizedBox(height: 12),
              SelectableText(
                code,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: detoxWeightEmphasis,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                t.codeExpiresOnce,
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? DetoxColors.muted
                      : DetoxColors.lightMuted,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppStrings.of(context).done),
            ),
          ],
        ),
      );

      await _refresh();
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) {
        setState(() => _requestActionBusy = false);
      }
    }
  }

  Future<void> _unlink() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.endSponsorLinkTitle,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: detoxWeightEmphasis,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              t.endSponsorLinkBody,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? DetoxColors.muted
                        : DetoxColors.lightMuted,
                  ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, 'requestSponsor'),
              icon: const Icon(Icons.send_outlined),
              label: Text(t.requestSponsorUnlink),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context, 'requestSupport'),
              icon: const Icon(Icons.support_agent_rounded),
              label: Text(t.requestSupportUnlink),
            ),
            const SizedBox(height: 12),
            Text(
              t.requestSupportUnlinkHelp,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: _muted),
            ),
          ],
        ),
      ),
    );

    switch (action) {
      case 'requestSponsor':
        await _requestSponsorUnlink();
        break;
      case 'requestSupport':
        await _requestSupportUnlink();
        break;
    }
  }

  Future<void> _linkSponsor() async {
    final code = _codeController.text.trim();

    if (code.isEmpty) {
      _snack(t.enterSponsorCodeSnack);
      return;
    }

    try {
      await _sponsorService.sendLinkRequestWithCode(code);

      if (!mounted) return;

      _snack(t.requestSentWaiting);
      _codeController.clear();
      await _refresh();
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _acceptLink(LinkRequest request) async {
    if (_linkActionBusy) return;

    setState(() => _linkActionBusy = true);
    try {
      await _sponsorService.acceptLinkRequest(request.id);
      await AppBlockingService.instance.syncSponsorState(true);
      await LocationZoneService.instance.refresh();

      if (!mounted) return;
      _snack(t.sponsorRequestAccepted);
      await _refresh();
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) {
        setState(() => _linkActionBusy = false);
      }
    }
  }

  Future<void> _rejectLink(LinkRequest request) async {
    if (_linkActionBusy) return;

    setState(() => _linkActionBusy = true);
    try {
      await _sponsorService.rejectLinkRequest(request.id);
      if (!mounted) return;
      _snack(t.sponsorRequestRejected);
      await _refresh();
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) {
        setState(() => _linkActionBusy = false);
      }
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    final clean = message.replaceFirst('Exception: ', '');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(clean)),
    );
  }

  Color get _muted => Theme.of(context).brightness == Brightness.dark
      ? DetoxColors.muted
      : DetoxColors.lightMuted;

  /// Severity color for a request state, in the palette of the app.
  Color _stateColor(bool isDark, {required bool warning}) {
    if (!warning) return isDark ? DetoxColors.success : DetoxColors.accentDeep;
    return isDark ? DetoxColors.warning : const Color(0xFF805B19);
  }

  _RequestState _outgoingState(SponsorRequest request, bool isDark) {
    if (request.isConsumed) {
      return _RequestState(
        t.statusCompleted,
        Icons.verified_rounded,
        _stateColor(isDark, warning: false),
      );
    }
    if (request.isApproved && !request.isExpired) {
      return _RequestState(
        t.statusApproved,
        Icons.lock_open_rounded,
        _stateColor(isDark, warning: false),
      );
    }
    if (request.isRejected) {
      return _RequestState(
        t.statusRejected,
        Icons.cancel_outlined,
        DetoxColors.danger,
      );
    }
    if (request.isEmailed) {
      return _RequestState(
        t.statusEmailed,
        Icons.mark_email_read_outlined,
        _stateColor(isDark, warning: true),
      );
    }
    if (request.isExpired) {
      return _RequestState(
        t.expired,
        Icons.timer_off_outlined,
        DetoxColors.danger,
      );
    }
    return _RequestState(
      t.statusPending,
      Icons.schedule_rounded,
      _stateColor(isDark, warning: true),
    );
  }

  String _dateLabel(DateTime? value) {
    if (value == null) return '';
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month $hour:$minute';
  }

  Widget _errorCard(String message) {
    return GlassCard(
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: DetoxColors.danger, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: _muted),
            ),
          ),
        ],
      ),
    );
  }

  /// Incoming link requests and approval requests, which are the only items
  /// that need an answer right now.
  Widget _buildPendingSection() {
    return StreamBuilder<List<LinkRequest>>(
      stream: _sponsorService.incomingLinkRequests(),
      builder: (context, linkSnapshot) {
        return StreamBuilder<List<SponsorRequest>>(
          stream: _sponsorService.incomingRequests(),
          builder: (context, requestSnapshot) {
            final linkRequests = linkSnapshot.data ?? const <LinkRequest>[];
            final requests = (requestSnapshot.data ?? const <SponsorRequest>[])
                .where((request) =>
                    request.isPending ||
                    (request.isApproved && !request.isExpired))
                .toList();

            if (linkSnapshot.hasError || requestSnapshot.hasError) {
              return _errorCard(t.isEs
                  ? 'No pudimos cargar tus solicitudes.'
                  : 'We could not load your requests.');
            }

            if (linkRequests.isEmpty && requests.isEmpty) {
              return GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.incomingRequestsTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t.noPendingRequests,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: _muted),
                    ),
                  ],
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionTitle(
                  title: t.incomingRequestsTitle,
                  subtitle: t.incomingRequestsSubtitle,
                ),
                const SizedBox(height: 12),
                ...linkRequests.map(_buildLinkRequestCard),
                ...requests.map(_buildUnlockRequestCard),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildLinkRequestCard(LinkRequest request) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    t.linkPartnerWantsToLink(request.requesterName),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 8),
                StatusPill(
                  label: t.pendingState,
                  icon: Icons.schedule_rounded,
                  color: _stateColor(isDark, warning: true),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              t.acceptLinkBody,
              style:
                  Theme.of(context).textTheme.bodySmall?.copyWith(color: _muted),
            ),
            if (request.hasMessage) ...[
              const SizedBox(height: 10),
              _noteBox(label: t.requestMessageLabel, text: request.message!),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        _linkActionBusy ? null : () => _rejectLink(request),
                    icon: const Icon(Icons.close_rounded),
                    label: Text(t.reject),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed:
                        _linkActionBusy ? null : () => _acceptLink(request),
                    icon: const Icon(Icons.check_rounded),
                    label: Text(t.accept),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnlockRequestCard(SponsorRequest request) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDirect = request.requestType == 'settings_unlock' ||
        request.requestType == 'zone_override' ||
        request.requestType == 'shield_pause';
    final isUnlink = request.requestType == 'unlink_sponsor';
    final approved = request.isApproved && !request.isExpired;

    final title = request.requestType == 'zone_override'
        ? t.zonePauseApprovalTitle
        : request.requestType == 'settings_unlock'
            ? t.settingsApprovalTitle
            : request.requestType == 'shield_pause'
                ? t.shieldPauseTitle
                : t.unlinkApprovalTitle;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 8),
                StatusPill(
                  label: approved ? t.approvedState : t.pendingState,
                  icon: approved
                      ? Icons.check_circle_outline_rounded
                      : Icons.schedule_rounded,
                  color: _stateColor(isDark, warning: !approved),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${request.requesterName} · ${request.prettyType}',
              style:
                  Theme.of(context).textTheme.bodySmall?.copyWith(color: _muted),
            ),
            const SizedBox(height: 2),
            Text(
              t.durationMinLabel(request.durationMinutes),
              style:
                  Theme.of(context).textTheme.bodySmall?.copyWith(color: _muted),
            ),
            if (request.hasMessage) ...[
              const SizedBox(height: 10),
              _noteBox(label: t.requestMessageLabel, text: request.message!),
            ],
            if (request.hasReply) ...[
              const SizedBox(height: 10),
              _noteBox(label: t.yourReplyLabel, text: request.replyMessage!),
            ],
            if (approved && request.code != null) ...[
              const SizedBox(height: 12),
              SelectableText(
                request.code!,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: detoxWeightEmphasis,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                '${t.expiresSoon} · ${_timeLabel(request.expiresAt)}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: _muted),
              ),
            ],
            if (request.isPending) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _requestActionBusy
                          ? null
                          : () => _rejectRequest(request),
                      icon: const Icon(Icons.close_rounded),
                      label: Text(isUnlink ? t.denyUnlink : t.reject),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: isUnlink
                        ? FilledButton.icon(
                            onPressed: _requestActionBusy
                                ? null
                                : () => _acceptUnlink(request),
                            icon: const Icon(Icons.link_off_rounded),
                            label: Text(t.acceptUnlink),
                          )
                        : isDirect
                            ? FilledButton.icon(
                                onPressed: _requestActionBusy
                                    ? null
                                    : () => _approveDirect(request),
                                icon: const Icon(Icons.check_rounded),
                                label: Text(t.approve),
                              )
                            : FilledButton(
                                onPressed: _requestActionBusy
                                    ? null
                                    : () => _approveWithCode(request),
                                child: Text(t.generateCode),
                              ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _timeLabel(DateTime? value) {
    if (value == null) return '—';
    final diff = value.difference(DateTime.now());
    if (diff.inSeconds <= 0) return t.expired;
    return '${diff.inMinutes} min';
  }

  /// Note bubble used for the requester note and the sponsor answer.
  Widget _noteBox({required String label, required String text}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(detoxRadius),
        color: isDark ? DetoxColors.cardSubtle : DetoxColors.lightCardSubtle,
        border: Border.all(
          color: isDark ? DetoxColors.cardBorder : DetoxColors.lightCardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: _muted),
          ),
          const SizedBox(height: 4),
          Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildCodeCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return HeroInfoCard(
      title: t.yourSponsorCode,
      subtitle: t.sponsorCodeShare,
      badge: StatusPill(
        label: _sponsor == null ? t.noActiveLink : t.linkedState,
        icon: _sponsor == null
            ? Icons.link_off_rounded
            : Icons.check_circle_rounded,
        color: _sponsor == null
            ? _stateColor(isDark, warning: true)
            : _stateColor(isDark, warning: false),
      ),
      child: SelectableText(
        _myCode,
        style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontWeight: detoxWeightEmphasis,
              letterSpacing: 1.0,
            ),
      ),
    );
  }

  Widget _buildLinkCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sponsor = _sponsor;

    if (sponsor == null) {
      return HeroInfoCard(
        title: t.addSponsor,
        subtitle: t.onlyOneSponsor,
        child: Column(
          children: [
            TextField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: t.enterSponsorCodeHint,
                prefixIcon: const Icon(Icons.link_rounded),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _linkSponsor,
              icon: const Icon(Icons.handshake_outlined),
              label: Text(t.linkSponsor),
            ),
          ],
        ),
      );
    }

    return HeroInfoCard(
      title: sponsor.displayName,
      subtitle: sponsor.email,
      badge: StatusPill(
        label: t.protectionActive,
        icon: Icons.verified_user_outlined,
        color: _stateColor(isDark, warning: false),
      ),
      child: Column(
        children: [
          FilledButton.icon(
            onPressed: () => _request('zone_override'),
            icon: const Icon(Icons.pause_circle_outline),
            label: Text(t.requestZonePause),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _request('settings_unlock'),
            icon: const Icon(Icons.lock_open_rounded),
            label: Text(t.requestSettingsApproval),
          ),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: _unlink,
            icon: const Icon(Icons.link_off_rounded),
            label: Text(t.endSponsorLink),
          ),
        ],
      ),
    );
  }

  /// One single list of the requests the user sent, with their live state.
  Widget _buildRequestsList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return StreamBuilder<List<SponsorRequest>>(
      stream: _sponsorService.outgoingHistory(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _errorCard(t.isEs
              ? 'No pudimos cargar tus solicitudes.'
              : 'We could not load your requests.');
        }

        final requests =
            (snapshot.data ?? const <SponsorRequest>[]).take(8).toList();

        if (requests.isEmpty) {
          return GlassCard(
            child: Text(
              t.noOutgoingRequests,
              style:
                  Theme.of(context).textTheme.bodySmall?.copyWith(color: _muted),
            ),
          );
        }

        return Column(
          children: requests.map((request) {
            final state = _outgoingState(request, isDark);
            final date = _dateLabel(request.createdAt);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            request.prettyType,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusPill(
                          label: state.label,
                          icon: state.icon,
                          color: state.color,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      [
                        t.durationMinLabel(request.durationMinutes),
                        if (date.isNotEmpty) date,
                      ].join(' · '),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: _muted),
                    ),
                    if (request.hasMessage) ...[
                      const SizedBox(height: 10),
                      _noteBox(
                        label: t.yourMessageLabel,
                        text: request.message!,
                      ),
                    ],
                    if (request.hasReply) ...[
                      const SizedBox(height: 10),
                      _noteBox(
                        label: t.sponsorReplyLabel,
                        text: request.replyMessage!,
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t.sponsorCenter)),
      body: DetoxBackground(
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    children: [
                      _buildPendingSection(),
                      const SizedBox(height: 16),
                      _buildCodeCard(),
                      const SizedBox(height: 24),
                      SectionTitle(
                        title: t.yourLinkTitle,
                        subtitle: t.yourLinkSubtitle,
                      ),
                      const SizedBox(height: 12),
                      _buildLinkCard(),
                      const SizedBox(height: 24),
                      SectionTitle(
                        title: t.yourOutgoingRequests,
                        subtitle: t.yourRequestsSubtitle,
                      ),
                      const SizedBox(height: 12),
                      _buildRequestsList(),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
