import 'package:flutter/material.dart';

import 'package:kitsune/game/game.dart';
import 'package:kitsune/ui/palette.dart';

class TutorialPanel extends StatelessWidget {
  final KitsuneGame game;
  const TutorialPanel(this.game, {super.key});

  static const List<(String, String, String)> _controls = [
    ("Gerak", "Joystick kiri bawah", "A / D atau ← →"),
    (
      "Lompat",
      "Tombol LOMPAT · tekan lagi di udara untuk lompat ganda",
      "Spasi · tahan saat jatuh untuk meluncur",
    ),
    ("Tembak", "Tombol TEMBAK", "J · tahan untuk tembakan kuat"),
    ("Lesat", "Tombol LESAT", "K · menerobos sebentar dan meninggalkan klon"),
    ("Jimat", "Tombol JIMAT", "L · pasang jimat yang meledak saat didekati"),
    ("Roh", "Tombol ROH (saat penuh)", "I · wujud roh: lebih cepat, cakar dengan TEMBAK"),
    ("Jeda", "Tombol Ⅱ", "Esc"),
  ];

  static const List<(String, String)> _rules = [
    (
      "Ekor = nyawa",
      "Mulai penuh dengan 9. Kena serangan atau jatuh ke jurang −1 ekor. "
          "Ekor terbawa ke distrik berikutnya.",
    ),
    (
      "Pickup ekor",
      "+1 ekor. Ada 2 di tiap distrik, letaknya tinggi: pakai lompat ganda.",
    ),
    (
      "Pecahan roh",
      "Mengisi meter ROH. Saat penuh, tekan ROH untuk berubah wujud.",
    ),
    (
      "Checkpoint",
      "Lentera yang memulihkan ekor jadi minimal 3. Kalau ekor habis, kamu "
          "bangkit di sini dengan 3 ekor.",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: game.tutorialOpen,
      builder: (context, open, _) {
        if (!open) return const SizedBox.shrink();
        return ColoredBox(
          color: const Color(0xD9020512),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Container(
                  width: 440,
                  padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
                  decoration: BoxDecoration(
                    color: const Color(0xF2050A1F),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Neon.border),
                    boxShadow: const [
                      BoxShadow(color: Color(0x5549E8FF), blurRadius: 36),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "CARA MAIN",
                        style: Neon.label.copyWith(
                          color: Neon.cyan,
                          letterSpacing: 2.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Kitsune Neon Exorcist",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 16),
                      for (final (name, touch, keys) in _controls)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 70,
                                child: Text(
                                  name.toUpperCase(),
                                  style: Neon.label.copyWith(color: Neon.cyan),
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      touch,
                                      style: const TextStyle(
                                        color: Color(0xFFE6F4FF),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      keys,
                                      style: const TextStyle(
                                        color: Color(0xFF9FB8D6),
                                        fontSize: 13,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 6),
                      Text(
                        "EKOR & PICKUP",
                        style: Neon.label.copyWith(
                          color: Neon.cyan,
                          letterSpacing: 2.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      for (final (title, body) in _rules)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  color: Color(0xFFE6F4FF),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                body,
                                style: const TextStyle(
                                  color: Color(0xFF9FB8D6),
                                  fontSize: 13,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 6),
                      const Text(
                        "Ikuti pesan di layar saat melewati setiap segel distrik. "
                        "Tombol ? di atas membuka panduan ini lagi.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFC6DDF2),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton(
                          onPressed: game.closeTutorial,
                          style: FilledButton.styleFrom(
                            backgroundColor: Neon.cyan,
                            foregroundColor: const Color(0xFF041024),
                            shape: const StadiumBorder(),
                          ),
                          child: const Text(
                            "MENGERTI",
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
