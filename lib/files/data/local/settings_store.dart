// lib/data/local/settings_store.dart
//
// Lightweight key-value store backed by SharedPreferences.
// Keeps API keys and user preferences separate from the scan DB.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsStore extends ChangeNotifier {
  static final SettingsStore instance = SettingsStore._();
  SettingsStore._();

  static const _keyVt = 'api_key_virustotal';
  static const _keyGsb = 'api_key_gsb';
  static const _keyAbuse = 'api_key_abuseipdb';
  static const _keyThreatIntel = 'feature_threat_intel';
  static const _keyRedirectTrace = 'feature_redirect_trace';

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // ─── API Keys ─────────────────────────────────────────────────────────────

  String get virusTotalKey => _prefs?.getString(_keyVt) ?? '';
  String get googleSafeBrowsingKey => _prefs?.getString(_keyGsb) ?? '';
  String get abuseIpDbKey => _prefs?.getString(_keyAbuse) ?? '';

  Future<void> setVirusTotalKey(String key) async {
    await _prefs?.setString(_keyVt, key);
    notifyListeners();
  }

  Future<void> setGoogleSafeBrowsingKey(String key) async {
    await _prefs?.setString(_keyGsb, key);
    notifyListeners();
  }

  Future<void> setAbuseIpDbKey(String key) async {
    await _prefs?.setString(_keyAbuse, key);
    notifyListeners();
  }

  // ─── Feature Flags ────────────────────────────────────────────────────────

  bool get threatIntelEnabled => _prefs?.getBool(_keyThreatIntel) ?? false;
  bool get redirectTraceDefault => _prefs?.getBool(_keyRedirectTrace) ?? true;

  Future<void> setThreatIntelEnabled(bool v) async {
    await _prefs?.setBool(_keyThreatIntel, v);
    notifyListeners();
  }

  Future<void> setRedirectTraceDefault(bool v) async {
    await _prefs?.setBool(_keyRedirectTrace, v);
    notifyListeners();
  }

  bool get hasAnyApiKey =>
      virusTotalKey.isNotEmpty ||
      googleSafeBrowsingKey.isNotEmpty ||
      abuseIpDbKey.isNotEmpty;
}
