import 'dart:async';

import 'package:flutter/material.dart';

import '../models/sponsor_profile.dart';
import '../models/sponsor_request.dart';
import '../services/location_zone_service.dart';
import '../services/sponsor_service.dart';
import '../theme/app_theme.dart';

class SponsorScreen extends StatefulWidget {
  const SponsorScreen({super.key});

  @override
  State<SponsorScreen> createState() => _SponsorScreenState();
}

class _SponsorScreenState extends State<SponsorScreen> with WidgetsBindingObserver {
  final SponsorService _sponsorService = SponsorService.instance;
  final TextEditingController _codeController = TextEditingController();

  bool _loading = true;
  String _myCode = '';
  SponsorProfile? _sponsor;
  bool _settingsUnlockActive = false;
  bool _zoneOverrideActive = false;
  DateTime? _settingsUntil;
  DateTime? _zoneUntil;
  ZoneState _zoneState = LocationZoneService.instance.currentState;
  StreamSubscription<ZoneState>? _zoneSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _zoneSubscription = LocationZoneService.instance.states.listen((state) {
      if (!mounted) return;
      setState(() => _zoneState = state);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _zoneSubscription?.cancel();
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
      final results = await Future.wait<dynamic>([
        _sponsorService.getMySponsorCode(),
        _sponsorService.getCurrentSponsorProfile(),
        _sponsorService.hasActiveSettingsUnlock(),
        _sponsorService.hasActiveZoneOverride(),
        _sponsorService.getSettingsUnlockUntil(),
        _sponsorService.getZoneOverrideUntil(),
      ]);
      if (!mounted) return;
      setState(() {
        _myCode = results[0] as String;
        _sponsor = results[1] as SponsorProfile?;
        _settingsUnlockActive = results[2] as bool;
        _zoneOverrideActive = results[3] as bool;
        _settingsUntil = results[4] as DateTime?;
        _zoneUntil = results[5] as DateTime?;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack(e.toString());
    }
  }

  Future<void> _linkSponsor() async {
    try {
      await _sponsorService.linkWithCode(_codeController.text);
      _codeController.clear();
      _snack('Sponsor linked successfully.');
      await _refresh();
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _request(String type) async {
    try {
      await _sponsorService.createUnlockRequest(
        requestType: type,
        durationMinutes: type == 'settings_unlock' ? 10 : 15,
      );
      _snack(type == 'settings_unlock'
          ? 'Settings-unlock request sent to your sponsor.'
          : 'Zone-pause request sent to your sponsor.');
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _enterCode(String type) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(type == 'settings_unlock' ? 'Enter settings code' : 'Enter zone-pause code'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(labelText: '6-digit code'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Use code')),
        ],
      ),
    );
    if (value == null || value.trim().isEmpty) return;
    try {
      final minutes = await _sponsorService.consumeCode(code: value, requestType: type);
      if (type == 'zone_override') {
        await LocationZoneService.instance.refresh();
      }
      await _refresh();
      _snack(type == 'settings_unlock'
          ? 'Settings unlocked for $minutes minutes.'
          : 'Zone paused for $minutes minutes.');
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _requestEmailUnlinkCode() async {
    try {
      await _sponsorService.requestEmailUnlinkCode();
      _snack('We sent an unlink code request to your email.');
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _requestSponsorUnlinkCode() async {
    try {
      await _sponsorService.requestUnlinkSponsorCode();
      _snack('Unlink request sent to your sponsor.');
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _enterUnlinkCode({required bool emailCode}) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(emailCode ? 'Enter email unlink code' : 'Enter sponsor unlink code'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(labelText: '6-digit code'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Use code')),
        ],
      ),
    );
    if (value == null || value.trim().isEmpty) return;
    try {
      if (emailCode) {
        await _sponsorService.consumeEmailUnlinkCode(value);
      } else {
        await _sponsorService.consumeCode(code: value, requestType: 'unlink_sponsor');
      }
      _snack('Sponsor link removed.');
      await _refresh();
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _approve(SponsorRequest request) async {
    try {
      final code = await _sponsorService.approveRequest(request.id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(request.prettyType),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Give this code to ${request.requesterName}.'),
              const SizedBox(height: 12),
              SelectableText(
                code,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('It expires in 3 minutes and only works once.', style: TextStyle(color: DetoxColors.muted)),
            ],
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))],
        ),
      );
    } catch (e) {
      _snack(e.toString());
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
            Text('End sponsor link', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text('You can unlink with a sponsor-generated code or request a code by email.', style: TextStyle(color: DetoxColors.muted)),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, 'requestSponsor'),
              icon: const Icon(Icons.send_outlined),
              label: const Text('Request sponsor unlink code'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context, 'enterSponsor'),
              icon: const Icon(Icons.password_rounded),
              label: const Text('Enter sponsor unlink code'),
            ),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              onPressed: () => Navigator.pop(context, 'requestEmail'),
              icon: const Icon(Icons.email_outlined),
              label: const Text('Email me an unlink code'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context, 'enterEmail'),
              icon: const Icon(Icons.mark_email_read_outlined),
              label: const Text('Enter email unlink code'),
            ),
          ],
        ),
      ),
    );

    switch (action) {
      case 'requestSponsor':
        await _requestSponsorUnlinkCode();
        break;
      case 'enterSponsor':
        await _enterUnlinkCode(emailCode: false);
        break;
      case 'requestEmail':
        await _requestEmailUnlinkCode();
        break;
      case 'enterEmail':
        await _enterUnlinkCode(emailCode: true);
        break;
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    final clean = message.replaceFirst('Exception: ', '');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(clean)));
  }

  String _timeLabel(DateTime? value) {
    if (value == null) return '—';
    final diff = value.difference(DateTime.now());
    if (diff.inSeconds <= 0) return 'Expired';
    return '${diff.inMinutes} min left';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sponsor center')),
      body: DetoxBackground(
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Your sponsor code', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            SelectableText(_myCode, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            const Text('Share this code with the one person you trust to approve Detox overrides.', style: TextStyle(color: DetoxColors.muted)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (_sponsor == null)
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Add a sponsor', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _codeController,
                                textCapitalization: TextCapitalization.characters,
                                decoration: const InputDecoration(
                                  labelText: 'Enter sponsor code',
                                  prefixIcon: Icon(Icons.link_rounded),
                                ),
                              ),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: _linkSponsor,
                                icon: const Icon(Icons.handshake_outlined),
                                label: const Text('Link sponsor'),
                              ),
                              const SizedBox(height: 8),
                              const Text('You can only have one sponsor at a time.', style: TextStyle(color: DetoxColors.muted)),
                            ],
                          ),
                        )
                      else ...[
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const CircleAvatar(child: Icon(Icons.person_outline_rounded)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(_sponsor!.displayName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                                        Text(_sponsor!.email, style: const TextStyle(color: DetoxColors.muted)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: FilledButton.icon(
                                      onPressed: () => _request('zone_override'),
                                      icon: const Icon(Icons.pause_circle_outline),
                                      label: const Text('Request zone pause'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _request('settings_unlock'),
                                      icon: const Icon(Icons.lock_open_rounded),
                                      label: const Text('Request settings code'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => _enterCode('zone_override'),
                                      child: const Text('Enter zone code'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => _enterCode('settings_unlock'),
                                      child: const Text('Enter settings code'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              TextButton.icon(
                                onPressed: _unlink,
                                icon: const Icon(Icons.link_off_rounded),
                                label: const Text('End sponsor link'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Current safeguards', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(_zoneOverrideActive ? Icons.verified_rounded : Icons.block_rounded, color: _zoneOverrideActive ? Colors.greenAccent : DetoxColors.accentSoft),
                                title: const Text('Zone pause'),
                                subtitle: Text(_zoneOverrideActive ? 'Active · ${_timeLabel(_zoneUntil)}' : _zoneState.insideZone ? 'Inside ${_zoneState.zoneName ?? 'a focus zone'}' : 'Inactive', style: const TextStyle(color: DetoxColors.muted)),
                              ),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(_settingsUnlockActive ? Icons.verified_rounded : Icons.lock_outline_rounded, color: _settingsUnlockActive ? Colors.greenAccent : DetoxColors.accentSoft),
                                title: const Text('Protected settings'),
                                subtitle: Text(_settingsUnlockActive ? 'Unlocked · ${_timeLabel(_settingsUntil)}' : 'Removing apps or zones needs a sponsor code.', style: const TextStyle(color: DetoxColors.muted)),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Text('Requests from your sponsor partner', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      StreamBuilder<List<SponsorRequest>>(
                        stream: _sponsorService.incomingRequests(),
                        builder: (context, snapshot) {
                          final requests = (snapshot.data ?? const [])
                              .where((request) => request.isPending || (request.isApproved && !request.isExpired))
                              .toList();
                          if (requests.isEmpty) {
                            return const GlassCard(child: Text('No incoming requests right now.', style: TextStyle(color: DetoxColors.muted)));
                          }
                          return Column(
                            children: requests.map((request) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: GlassCard(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(request.requesterName, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 6),
                                      Text('${request.prettyType} · ${request.durationMinutes} min', style: const TextStyle(color: DetoxColors.muted)),
                                      if (request.isApproved && request.code != null) ...[
                                        const SizedBox(height: 12),
                                        SelectableText(request.code!, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 6),
                                        Text('Expires soon · ${_timeLabel(request.expiresAt)}', style: const TextStyle(color: DetoxColors.muted)),
                                      ],
                                      if (request.isPending) ...[
                                        const SizedBox(height: 12),
                                        FilledButton(onPressed: () => _approve(request), child: const Text('Generate code')),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      Text('Your outgoing requests', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      StreamBuilder<List<SponsorRequest>>(
                        stream: _sponsorService.outgoingRequests(),
                        builder: (context, snapshot) {
                          final requests = (snapshot.data ?? const []).take(6).toList();
                          if (requests.isEmpty) {
                            return const GlassCard(child: Text('You have not requested any sponsor actions yet.', style: TextStyle(color: DetoxColors.muted)));
                          }
                          return Column(
                            children: requests.map((request) {
                              final status = request.isConsumed
                                  ? 'Used'
                                  : request.isApproved
                                      ? 'Approved'
                                      : 'Pending';
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: GlassCard(
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(
                                      request.isConsumed
                                          ? Icons.verified_rounded
                                          : request.isApproved
                                              ? Icons.lock_open_rounded
                                              : Icons.schedule_rounded,
                                      color: request.isConsumed
                                          ? Colors.greenAccent
                                          : request.isApproved
                                              ? DetoxColors.accentSoft
                                              : Colors.orangeAccent,
                                    ),
                                    title: Text(request.prettyType),
                                    subtitle: Text('$status · ${request.durationMinutes} min', style: const TextStyle(color: DetoxColors.muted)),
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      Text('History', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      StreamBuilder<List<SponsorRequest>>(
                        stream: _sponsorService.outgoingHistory(),
                        builder: (context, snapshot) {
                          final requests = (snapshot.data ?? const []).take(12).toList();
                          if (requests.isEmpty) {
                            return const GlassCard(child: Text('No sponsor history yet.', style: TextStyle(color: DetoxColors.muted)));
                          }
                          return Column(
                            children: requests.map((request) {
                              final status = request.isConsumed
                                  ? 'Completed'
                                  : request.isApproved
                                      ? 'Approved'
                                      : request.isEmailed
                                          ? 'Emailed'
                                          : request.isExpired
                                              ? 'Expired'
                                              : 'Pending';
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: GlassCard(
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(
                                      request.requestType == 'unlink_sponsor' || request.requestType == 'unlink_email'
                                          ? Icons.link_off_rounded
                                          : request.isConsumed
                                              ? Icons.history_toggle_off_rounded
                                              : Icons.receipt_long_outlined,
                                    ),
                                    title: Text(request.prettyType),
                                    subtitle: Text('$status${request.createdAt != null ? ' · ' + request.createdAt!.toLocal().toString().substring(0,16) : ''}', style: const TextStyle(color: DetoxColors.muted)),
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
