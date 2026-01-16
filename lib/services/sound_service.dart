import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Service for managing game sound effects
class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  final AudioPlayer _effectsPlayer = AudioPlayer();
  final AudioPlayer _musicPlayer = AudioPlayer();
  
  bool _soundEnabled = true;
  bool _musicEnabled = true;
  double _effectsVolume = 0.7;
  double _musicVolume = 0.3;

  bool get soundEnabled => _soundEnabled;
  bool get musicEnabled => _musicEnabled;

  void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
  }

  void setMusicEnabled(bool enabled) {
    _musicEnabled = enabled;
    if (!enabled) {
      _musicPlayer.stop();
    }
  }

  void setEffectsVolume(double volume) {
    _effectsVolume = volume.clamp(0.0, 1.0);
    _effectsPlayer.setVolume(_effectsVolume);
  }

  void setMusicVolume(double volume) {
    _musicVolume = volume.clamp(0.0, 1.0);
    _musicPlayer.setVolume(_musicVolume);
  }

  // Play UI interaction sounds
  Future<void> playClick() async {
    if (!_soundEnabled) return;
    HapticFeedback.selectionClick();
  }

  Future<void> playSelect() async {
    if (!_soundEnabled) return;
    HapticFeedback.lightImpact();
  }

  Future<void> playError() async {
    if (!_soundEnabled) return;
    HapticFeedback.heavyImpact();
  }

  // Play game event sounds with haptics
  Future<void> playPhaseTransition() async {
    if (!_soundEnabled) return;
    HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 200));
    HapticFeedback.mediumImpact();
  }

  Future<void> playRoleReveal() async {
    if (!_soundEnabled) return;
    HapticFeedback.heavyImpact();
  }

  Future<void> playDeath() async {
    if (!_soundEnabled) return;
    await HapticFeedback.vibrate();
    await Future.delayed(const Duration(milliseconds: 100));
    HapticFeedback.heavyImpact();
  }

  Future<void> playVictory() async {
    if (!_soundEnabled) return;
    for (int i = 0; i < 3; i++) {
      HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 150));
    }
  }

  Future<void> playSwipe() async {
    if (!_soundEnabled) return;
    HapticFeedback.selectionClick();
  }

  Future<void> playExpand() async {
    if (!_soundEnabled) return;
    HapticFeedback.lightImpact();
  }

  Future<void> playCollapse() async {
    if (!_soundEnabled) return;
    HapticFeedback.lightImpact();
  }

  Future<void> playActionComplete() async {
    if (!_soundEnabled) return;
    HapticFeedback.mediumImpact();
  }

  // Cleanup
  void dispose() {
    _effectsPlayer.dispose();
    _musicPlayer.dispose();
  }
}
