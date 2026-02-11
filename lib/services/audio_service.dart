import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _musicPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();

  bool _isMusicEnabled = true;
  bool _isSfxEnabled = true;
  double _volume = 0.5;
  final double _sfxVolume = 1.0; // SFX at max volume
  bool _isInitialized = false;

  // Song rotation
  final List<String> _songs = [
    'Medieval Tavern - Full.wav',
    'Greensleeves.wav',
  ];
  int _currentSongIndex = 0;
  final Random _random = Random();

  bool get isMusicEnabled => _isMusicEnabled;
  bool get isSfxEnabled => _isSfxEnabled;
  double get volume => _volume;

  /// Check if running on Windows desktop
  bool get _isWindows => !kIsWeb && Platform.isWindows;

  Future<void> init() async {
    if (_isInitialized) return;

    final prefs = await SharedPreferences.getInstance();
    _isMusicEnabled = prefs.getBool('musicEnabled') ?? true;
    _isSfxEnabled = prefs.getBool('sfxEnabled') ?? true;
    _volume = prefs.getDouble('musicVolume') ?? 0.5;

    // Configure audio context to allow multiple audio streams to play simultaneously
    // This prevents SFX from interrupting background music on mobile devices
    // Skip on Windows to avoid threading issues
    if (!_isWindows) {
      final audioContext = AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: {AVAudioSessionOptions.mixWithOthers},
        ),
        android: AudioContextAndroid(
          isSpeakerphoneOn: false,
          audioMode: AndroidAudioMode.normal,
          stayAwake: false,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.game,
          audioFocus: AndroidAudioFocus
              .none, // Don't request audio focus to avoid interrupting other audio
        ),
      );

      AudioPlayer.global.setAudioContext(audioContext);
    }

    await _musicPlayer.setReleaseMode(ReleaseMode.loop);
    await _musicPlayer.setVolume(_volume);
    await _sfxPlayer.setVolume(_sfxVolume); // SFX always at max

    _isInitialized = true;

    // Delay music start slightly on Windows to avoid threading issues
    if (_isMusicEnabled) {
      if (_isWindows) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
      await playMusic();
    }
  }

  Future<void> playMusic() async {
    if (!_isMusicEnabled) return;

    try {
      // Pick a random song to start
      _currentSongIndex = _random.nextInt(_songs.length);

      // Set to stop when complete so we can play the next song
      await _musicPlayer.setReleaseMode(ReleaseMode.stop);

      // Listen for song completion to play next song
      _musicPlayer.onPlayerComplete.listen((_) {
        _playNextSong();
      });

      await _musicPlayer.play(AssetSource(_songs[_currentSongIndex]));
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _playNextSong() async {
    if (!_isMusicEnabled) return;

    try {
      // Move to next song (or random)
      _currentSongIndex = (_currentSongIndex + 1) % _songs.length;
      await _musicPlayer.play(AssetSource(_songs[_currentSongIndex]));
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> stopMusic() async {
    await _musicPlayer.stop();
  }

  /// Play the piece placement/movement sound effect
  Future<void> playPieceSound() async {
    if (!_isSfxEnabled) return;

    try {
      await _sfxPlayer.stop();
      await _sfxPlayer.play(AssetSource('Game Chess Piece Placement 36.wav'));
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> setMusicEnabled(bool enabled) async {
    _isMusicEnabled = enabled;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('musicEnabled', enabled);

    if (enabled) {
      await playMusic();
    } else {
      await stopMusic();
    }
  }

  Future<void> setSfxEnabled(bool enabled) async {
    _isSfxEnabled = enabled;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sfxEnabled', enabled);
  }

  Future<void> setVolume(double volume) async {
    _volume = volume;
    await _musicPlayer.setVolume(volume);
    // SFX volume stays at max, independent of music volume

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('musicVolume', volume);
  }

  void dispose() {
    _musicPlayer.dispose();
    _sfxPlayer.dispose();
  }
}
