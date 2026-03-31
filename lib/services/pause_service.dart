import 'package:shared_preferences/shared_preferences.dart';

class PauseService {
  PauseService._();
  static final PauseService instance = PauseService._();

  static const _prefsName = 'detox_native';
  static const _keyFreeUsed = 'pause_free_used';
  static const _keyAdUsed = 'pause_ad_used';
  static const _keyLastReset = 'pause_last_reset';

  Future<bool> canUseFreePause() async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureDailyReset(prefs);
    return !(prefs.getBool(_keyFreeUsed) ?? false);
  }
  Future<bool> useAdPause() async {
    if (!await canUseAdPause()) return false;
    await markAdPauseUsed();
    return true;
  }
  Future<bool> canUseAdPause() async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureDailyReset(prefs);
    return !(prefs.getBool(_keyAdUsed) ?? false);
  }

  Future<void> markFreePauseUsed() async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureDailyReset(prefs);
    await prefs.setBool(_keyFreeUsed, true);
  }

  Future<void> markAdPauseUsed() async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureDailyReset(prefs);
    await prefs.setBool(_keyAdUsed, true);
  }

  Future<void> resetDay() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFreeUsed, false);
    await prefs.setBool(_keyAdUsed, false);
    await prefs.setString(_keyLastReset, _todayString());
  }

  Future<Map<String, bool>> getStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureDailyReset(prefs);
    return {
      'freeUsed': prefs.getBool(_keyFreeUsed) ?? false,
      'adUsed': prefs.getBool(_keyAdUsed) ?? false,
    };
  }

  Future<void> _ensureDailyReset(SharedPreferences prefs) async {
    final lastReset = prefs.getString(_keyLastReset);
    final today = _todayString();
    if (lastReset == today) return;
    await prefs.setBool(_keyFreeUsed, false);
    await prefs.setBool(_keyAdUsed, false);
    await prefs.setString(_keyLastReset, today);
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }
}
