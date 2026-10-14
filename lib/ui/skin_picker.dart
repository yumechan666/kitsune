import 'package:flutter/material.dart';

import 'package:kitsune/game/game.dart';
import 'package:kitsune/game/levels.dart';
import 'package:kitsune/ui/palette.dart';

String _previewAsset(int skin) {
  if (skin == 0) return "assets/images/akari_base_a-transparent.webp";
  final id = (skin + 1).toString().padLeft(2, "0");
  return skin <= 3
      ? "assets/images/skin_${id}_base_a-transparent.webp"
      : "assets/images/skin_${id}_master-transparent.webp";
}

Future<void> showSkinPicker(BuildContext context, KitsuneGame game) async {
  final resume = game.playing && game.overlay.value == null;
  game.playing = false;
  final picked = await showGeneralDialog<int>(
    context: context,
    barrierDismissible: true,
    barrierLabel: "Tutup",
    barrierColor: const Color(0xB3020512),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (ctx, _, _) => _SkinPicker(current: game.currentSkinIndex),
    transitionBuilder: (ctx, anim, _, child) => FadeTransition(
      opacity: anim,
      child: ScaleTransition(
        scale: Tween(begin: 0.96, end: 1.0).animate(anim),
        child: child,
      ),
    ),
  );
  if (picked != null) await game.setSkin(picked);
  game.input.resetEdges();
  if (resume && game.overlay.value == null) game.playing = true;
}

class _SkinPicker extends StatelessWidget {
  final int current;
  const _SkinPicker({required this.current});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(16),
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 560),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xF20A1438), Color(0xF2050A1F)],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Neon.border),
            boxShadow: const [
              BoxShadow(color: Color(0x6649E8FF), blurRadius: 30),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("LEMARI KITSUNE", style: Neon.label),
                          SizedBox(height: 2),
                          Text(
                            "Pilih Skin",
                            style: TextStyle(
                              color: Neon.text,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: "Tutup",
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, color: Neon.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final cols = c.maxWidth > 620
                            ? 5
                            : c.maxWidth > 420
                            ? 4
                            : 3;
                        return GridView.builder(
                          padding: const EdgeInsets.only(right: 8),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: cols,
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                                childAspectRatio: 0.74,
                              ),
                          itemCount: SKIN_NAMES.length,
                          itemBuilder: (context, i) => _SkinCard(
                            index: i,
                            selected: i == current,
                            onTap: () => Navigator.pop(context, i),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SkinCard extends StatelessWidget {
  final int index;
  final bool selected;
  final VoidCallback onTap;
  const _SkinCard({
    required this.index,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final parts = SKIN_NAMES[index].split("·");
    final name = parts.first.trim();
    final title = parts.length > 1 ? parts[1].trim() : "";
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.2),
              radius: 0.9,
              colors: selected
                  ? const [Color(0x6649E8FF), Color(0xCC0A1538)]
                  : const [Color(0x332F5BA8), Color(0xB3071029)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? Neon.borderBright : Neon.border,
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? const [BoxShadow(color: Color(0x8049E8FF), blurRadius: 14)]
                : null,
          ),
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                      child: ClipRect(
                        child: FittedBox(
                          child: Align(
                            alignment: Alignment.topLeft,
                            widthFactor: 0.2,
                            heightFactor: 0.25,
                            child: Image.asset(
                              _previewAsset(index),
                              cacheWidth: 640,
                              filterQuality: FilterQuality.medium,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 2, 6, 10),
                    child: Column(
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: Neon.text,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Neon.muted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (selected)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Neon.cyan,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      "DIPAKAI",
                      style: TextStyle(
                        color: Color(0xFF041024),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
