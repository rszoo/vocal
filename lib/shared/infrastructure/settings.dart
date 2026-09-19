import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../vocal/domain/models.dart';

class Settings extends ChangeNotifier {
  Settings({SharedPreferencesAsync? prefs})
    : _waveformVisible = false,
      _prMode = PianoRangeMode.real,
      _videoId = '',
      _prefs = prefs ?? SharedPreferencesAsync() {
    // load();
  }

  bool _waveformVisible;
  bool get waveformVisible => _waveformVisible;

  PianoRangeMode _prMode;
  PianoRangeMode get prMode => _prMode;

  String _videoId;
  String get videoId => _videoId;

  final SharedPreferencesAsync _prefs;

  static const String _kWaveformVisible = 'waveform_visible';
  static const String _kPrMode = 'pr_mode';
  static const String _kVideoId = 'video_id';

  Future<void> load() async {
    _waveformVisible = await _prefs.getBool(_kWaveformVisible) ?? false;
    _prMode = switch (await _prefs.getString(_kPrMode)) {
      'real' => PianoRangeMode.real,
      'tone' => PianoRangeMode.tone,
      _ => PianoRangeMode.real,
    };
    _videoId = await _prefs.getString(_kVideoId) ?? '';
  }

  void toggleWaveform() {
    _waveformVisible = !_waveformVisible;
    notifyListeners();
    _prefs.setBool(_kWaveformVisible, _waveformVisible);
  }

  void setPrMode(PianoRangeMode value) {
    if (value == _prMode) return;
    _prMode = value;
    notifyListeners();
    _prefs.setString(_kPrMode, value.name);
  }

  void setVideoId(String value) {
    if (value == _videoId) return;
    _videoId = value;
    notifyListeners();
    _prefs.setString(_kVideoId, value);
  }
}
