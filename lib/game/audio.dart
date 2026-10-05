// Audio manager mirroring game js/game/audio.js. The original used the Web Audio
// API to synthesize taiko/synth tones. On Flutter we keep the same interface and
// event surface; wire real synthesis (e.g. via the `audioplayers` package) here
// when audio assets are available. It is intentionally a no-op so the game runs
// on every platform without audio files.
class AudioManager {
  double volume;
  int stage = 0;
  bool unlocked = false;

  AudioManager([this.volume = 0.16]);

  Future<void> unlock() async {
    unlocked = true;
  }

  void setStage(int index) {
    stage = index.abs() % 3;
  }

  void setVolume(double value) {
    volume = value;
  }

  void sfx(String name, [double amount = 1]) {
    // Hook for sound effects: shot, charge, dash, ofuda, hit, damage,
    // transform, pickup, jump, boss.
  }

  void destroy() {}
}
