import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Full-screen logo shown over the game while it loads. It picks up where the
// native launch screen ends (same background colour) and fades out once the
// game is ready and the logo has been visible for a moment.
class SplashOverlay extends StatefulWidget {
  final ValueListenable<bool> ready;
  const SplashOverlay({super.key, required this.ready});

  @override
  State<SplashOverlay> createState() => _SplashOverlayState();
}

class _SplashOverlayState extends State<SplashOverlay> {
  static const _logo = AssetImage("assets/images/logo.png");
  static const _minimumShow = Duration(milliseconds: 700);

  bool _minimumElapsed = false;
  bool _hidden = false;
  bool _gone = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_minimumShow, () {
      _minimumElapsed = true;
      _maybeHide();
    });
    widget.ready.addListener(_maybeHide);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(_logo, context);
  }

  void _maybeHide() {
    if (!mounted || _hidden || !_minimumElapsed || !widget.ready.value) return;
    setState(() => _hidden = true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.ready.removeListener(_maybeHide);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_gone) return const SizedBox.shrink();
    return IgnorePointer(
      ignoring: _hidden,
      child: AnimatedOpacity(
        opacity: _hidden ? 0 : 1,
        duration: const Duration(milliseconds: 450),
        onEnd: () {
          if (_hidden) setState(() => _gone = true);
        },
        child: ColoredBox(
          color: const Color(0xFF06091B),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Blurred, darkened copy fills the screen around the square logo.
              ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: const Image(image: _logo, fit: BoxFit.cover),
              ),
              const ColoredBox(color: Color(0x9906091B)),
              SafeArea(
                child: Column(
                  children: [
                    // Expanded bounds the square logo by the space left, so it
                    // fits a short landscape screen instead of overflowing.
                    const Expanded(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
                        child: Image(image: _logo, fit: BoxFit.contain),
                      ),
                    ),
                    const SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Color(0xFF49E8FF),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
