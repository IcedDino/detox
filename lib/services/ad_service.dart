import 'dart:async';

import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  AdService._();
  static final AdService instance = AdService._();

  static const MethodChannel _channel = MethodChannel('detox/ads');
  static const String _testRewardedAdUnitId =
      'ca-app-pub-3940256099942544/5224354917';

  RewardedAd? _rewardedAd;
  bool _initialized = false;
  bool _loadingAd = false;
  bool _isShowingAd = false;

  Future<void> init() async {
    if (_initialized) return;

    await MobileAds.instance.initialize();
    _channel.setMethodCallHandler(_handleNativeCall);
    _initialized = true;

    await _loadAd();
  }

  Future<void> _loadAd() async {
    if (_loadingAd || _rewardedAd != null) return;
    _loadingAd = true;

    try {
      await RewardedAd.load(
        adUnitId: _testRewardedAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _rewardedAd = ad;
            _loadingAd = false;
          },
          onAdFailedToLoad: (_) {
            _rewardedAd = null;
            _loadingAd = false;
          },
        ),
      );
    } catch (_) {
      _rewardedAd = null;
      _loadingAd = false;
    }
  }

  Future<void> consumePendingRewardedAd() async {
    await init();
    final shouldShow =
        await _channel.invokeMethod<bool>('consumePendingRewardedAd') ?? false;

    if (shouldShow) {
      await showRewardedAd();
    }
  }

  Future<void> showRewardedAd() async {
    await init();

    if (_isShowingAd) {
      return;
    }

    if (_rewardedAd == null) {
      await _loadAd();
    }

    final ad = _rewardedAd;
    if (ad == null) {
      await _channel.invokeMethod('onAdResult', {'success': false});
      return;
    }

    _isShowingAd = true;
    final completer = Completer<bool>();

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) async {
        ad.dispose();
        _rewardedAd = null;
        _isShowingAd = false;
        await _loadAd();
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      },
      onAdFailedToShowFullScreenContent: (ad, _) async {
        ad.dispose();
        _rewardedAd = null;
        _isShowingAd = false;
        await _loadAd();
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      },
    );

    try {
      ad.show(
        onUserEarnedReward: (_, __) {
          if (!completer.isCompleted) {
            completer.complete(true);
          }
        },
      );

      final success = await completer.future;
      _isShowingAd = false;
      await _channel.invokeMethod('onAdResult', {'success': success});
    } catch (_) {
      _rewardedAd = null;
      _isShowingAd = false;
      await _loadAd();
      if (!completer.isCompleted) {
        completer.complete(false);
      }
      await _channel.invokeMethod('onAdResult', {'success': false});
    }
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'showRewardAd':
        await showRewardedAd();
        return null;
      default:
        return null;
    }
  }
}