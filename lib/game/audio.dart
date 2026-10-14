import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

// Plays the sound effects and background music bundled under assets/audio/.
// Files are placeholders until the real mp3s are swapped in; empty or missing
// files fail silently so the game keeps running without sound.
class AudioManager {
  // Player-chosen loudness steps: full, medium, muted.
  static const List<double> levelMultipliers = [1.0, 0.5, 0.0];

  // Upper bound on effects playing at once, so rapid fire cannot pile up
  // hundreds of native players.
  static const int _maxActiveSfx = 12;

  double volume;
  int stage = 0;
  bool unlocked = false;
  int level = 0;

  final AudioPlayer _bgm = AudioPlayer();
  final Set<AudioPlayer> _activeSfx = {};
  bool _bgmWanted = false;

  AudioManager([this.volume = 0.16]);

  double get _multiplier => levelMultipliers[level];
  double get _bgmVolume => (volume * 2.2 * _multiplier).clamp(0.0, 1.0);

  // Without this every player asks Android for audio focus, and each sound
  // effect would pause the background music. Mixing lets them all play at once.
  AudioContext _mixingContext() => AudioContext(
    android: const AudioContextAndroid(
      isSpeakerphoneOn: false,
      stayAwake: false,
      contentType: AndroidContentType.music,
      usageType: AndroidUsageType.game,
      audioFocus: AndroidAudioFocus.none,
    ),
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.playback,
      options: const {AVAudioSessionOptions.mixWithOthers},
    ),
  );

  static const int bgmTrackCount = 3;
  int _track = 1;
  int? _playingTrack;

  Future<void> unlock() async {
    _bgmWanted = true;
    if (unlocked) return;
    unlocked = true;
    await _ignoreErrors(() async {
      await _bgm.setAudioContext(_mixingContext());
      await _bgm.setReleaseMode(ReleaseMode.loop);
      await _bgm.setVolume(_bgmVolume);
    });
    await _playTrack(_track);
  }

  // The three tracks rotate through the districts: 1, 4, 7 and 10 play
  // bgm1.mp3, 2, 5 and 8 play bgm2.mp3, 3, 6 and 9 play bgm3.mp3.
  void setStage(int index) {
    stage = index.abs() % 3;
    _track = index.abs() % bgmTrackCount + 1;
    if (unlocked && _playingTrack != _effective(_track)) {
      unawaited(_playTrack(_track));
    }
  }

  // Tracks whose file could not be played (still an empty placeholder).
  final Set<int> _unplayable = {};
  int _effective(int track) => _unplayable.contains(track) ? 1 : track;

  Future<void> _playTrack(int track) async {
    final wanted = _effective(track);
    _playingTrack = wanted;
    try {
      await _bgm.stop();
      await _bgm.play(AssetSource('audio/bgm$wanted.mp3'), volume: _bgmVolume);
    } catch (_) {
      if (wanted == 1) return;
      // Fall back to the first track rather than leaving the district silent.
      _unplayable.add(wanted);
      _playingTrack = 1;
      await _ignoreErrors(
        () => _bgm.play(AssetSource('audio/bgm1.mp3'), volume: _bgmVolume),
      );
    }
    if (!_bgmWanted) await _ignoreErrors(() => _bgm.pause());
  }

  void setVolume(double value) {
    volume = value;
    _ignoreErrors(() => _bgm.setVolume(_bgmVolume));
  }

  // Index into levelMultipliers; out-of-range values are clamped.
  void setLevel(int value) {
    level = value.clamp(0, levelMultipliers.length - 1);
    _ignoreErrors(() => _bgm.setVolume(_bgmVolume));
  }

  void pauseBgm() {
    _bgmWanted = false;
    _ignoreErrors(() => _bgm.pause());
  }

  void resumeBgm() {
    _bgmWanted = true;
    if (!unlocked) return;
    _ignoreErrors(() => _bgm.resume());
  }

  // Each effect gets its own short-lived player, so effects overlap each other
  // and the music instead of cutting one another off.
  void sfx(String name, [double amount = 1]) {
    if (_multiplier == 0 || _activeSfx.length >= _maxActiveSfx) return;
    unawaited(_playSfx(name, amount));
  }

  Future<void> _playSfx(String name, double amount) async {
    final player = AudioPlayer();
    _activeSfx.add(player);
    void release() {
      if (_activeSfx.remove(player)) unawaited(_ignoreErrors(player.dispose));
    }

    try {
      await player.setAudioContext(_mixingContext());
      await player.setReleaseMode(ReleaseMode.release);
      player.onPlayerComplete.listen((_) => release());
      final sfxVolume = (volume * 3 * amount * _multiplier).clamp(0.0, 1.0);
      await player.play(AssetSource('audio/sfx/$name.mp3'), volume: sfxVolume);
      // Safety net in case a completion event never arrives.
      Timer(const Duration(seconds: 8), release);
    } catch (_) {
      // Placeholder files are empty, so playback failures are expected.
      release();
    }
    // A failed effect must never leave the music stopped.
    if (_bgmWanted && unlocked && _bgm.state != PlayerState.playing) {
      unawaited(_ignoreErrors(() => _bgm.resume()));
    }
  }

  void destroy() {
    _bgmWanted = false;
    _ignoreErrors(() => _bgm.dispose());
    for (final player in _activeSfx) {
      _ignoreErrors(() => player.dispose());
    }
    _activeSfx.clear();
  }

  Future<void> _ignoreErrors(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // Audio is optional and must never interrupt gameplay.
    }
  }
}
