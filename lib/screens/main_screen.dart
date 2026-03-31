import 'package:flutter/material.dart';
import '../services/user_service.dart';
import 'settings_screen.dart';
import '../services/sos_service.dart';
import 'dart:async';
import 'package:vibration/vibration.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';

class MainScreen extends StatefulWidget {
  final void Function(String) updateLocale;

  const MainScreen({super.key, required this.updateLocale});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  bool _isLoading = true;
  bool _isSending = false;
  bool _isLongPressing = false;
  double _pressProgress = 0.0;
  Timer? _pressTimer;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _pressTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUserData() async {

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onLongPressStart(LongPressStartDetails details) {
    if (_isSending) return;
    setState(() {
      _isLongPressing = true;
      _pressProgress = 0.0;
    });

    const totalDuration = Duration(seconds: 5);
    const tickDuration = Duration(milliseconds: 50);
    final totalTicks = totalDuration.inMilliseconds / tickDuration.inMilliseconds;

    int currentTick = 0;
    _pressTimer = Timer.periodic(tickDuration, (timer) {
      currentTick++;
      final progress = currentTick / totalTicks;
      if (progress >= 1.0) {
        timer.cancel();
        _sendSOS();
      } else {
        setState(() => _pressProgress = progress);
      }
    });
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    _pressTimer?.cancel();
    setState(() {
      _isLongPressing = false;
      _pressProgress = 0.0;
    });
  }

  Future<void> _sendSOS() async {
    setState(() {
      _isSending = true;
      _isLongPressing = false;
    });

    try {
      final result = await SosService.sendSOS();
      if (mounted) {
        if (result['success'] == true) {
          Vibration.vibrate(duration: 500);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.white.withOpacity(0.9), size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'SOS sent to guardians',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.95),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF1B5E20).withOpacity(0.45),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.white.withOpacity(0.15), width: 1),
              ),
              elevation: 0,
              margin: EdgeInsets.only(left: 24, right: 24, bottom: MediaQuery.of(context).size.height * 0.17),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${result['error']}'),
              backgroundColor: Colors.red[900],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red[900],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xFF6B0000),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.3),
            radius: 1.2,
            colors: [
              Color(0xFFB71C1C),
              Color(0xFF7B0000),
              Color(0xFF3A0000),
            ],
            stops: [0.0, 0.6, 1.0],
          ),
        ),
        child: Stack(
          children: [
            _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : SafeArea(
                    child: Column(
                      children: [
                        // ── AppBar ─────────────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const SizedBox(width: 22),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => SettingsScreen(
                                        updateLocale: widget.updateLocale,
                                      ),
                                    ),
                                  ).then((_) => _loadUserData());
                                },
                                child: const Icon(
                                  Icons.settings_outlined,
                                  color: Colors.white70,
                                  size: 22,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // ── Shield ─────────────────────────────────────────
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final maxW = constraints.maxWidth * 1.2;
                              final maxH = constraints.maxHeight;
                              final shieldW = (maxH * 480 / 620).clamp(0.0, maxW);
                              final shieldH = (shieldW * 620 / 480).clamp(0.0, maxH);
                              final halberdSize = shieldW * 0.48;

                              return Center(
                                child: SizedBox(
                                  width: shieldW,
                                  height: shieldH,
                                  child: Stack(
                                    children: [
                                      CustomPaint(
                                        size: Size(shieldW, shieldH),
                                        painter: const _ShieldPainter(),
                                      ),
                                      Positioned.fill(
                                        child: Center(
                                          child: Padding(
                                            padding: EdgeInsets.only(bottom: shieldH * 0.05),
                                            child: SvgPicture.asset(
                                              'assets/images/Vectorizer-io-halberd.svg',
                                              width: halberdSize,
                                              height: halberdSize,
                                              colorFilter: ColorFilter.mode(
                                                Colors.white.withOpacity(0.85),
                                                BlendMode.srcIn,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Center(
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => const GuardiansScreen(),
                                            ),
                                          ).then((_) => _loadUserData()),
                                          child: SizedBox(
                                            width: shieldW * 0.4,
                                            height: shieldH * 0.45,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        
                        // ── SOS Button ─────────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            children: [
                              Text(
                                _isSending
                                    ? loc.sendingAlert
                                    : _isLongPressing ? loc.keepHolding
                                    : loc.holdToSend,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.6),
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 16),
                              GestureDetector(
                                onLongPressStart: _onLongPressStart,
                                onLongPressEnd: _onLongPressEnd,
                                child: Container(
                                  width: double.infinity,
                                  height: MediaQuery.of(context).size.height * 0.09,
                                  decoration: BoxDecoration(
                                    color: _isSending
                                        ? Colors.white.withOpacity(0.08)
                                        : Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(48),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Stack(
                                    children: [
                                      if (_isLongPressing)
                                        Positioned.fill(
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(48),
                                            child: LinearProgressIndicator(
                                              value: _pressProgress,
                                              backgroundColor: Colors.transparent,
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                Colors.white.withOpacity(0.2),
                                              ),
                                              minHeight: MediaQuery.of(context).size.height * 0.09,
                                            ),
                                          ),
                                        ),
                                      Center(
                                        child: _isSending
                                            ? const SizedBox(
                                                width: 32,
                                                height: 32,
                                                child: CircularProgressIndicator(
                                                  color: Colors.white,
                                                  strokeWidth: 2.5,
                                                ),
                                              )
                                            : const Text(
                                                'SOS',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 36,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 8,
                                                ),
                                              ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 10),

                      ],
                    ),
                  ),

          ],
        ),
      ),
    );
  }
}

// ── Shield CustomPainter — концентрические белые линии ────────────────────────

class _ShieldPainter extends CustomPainter {

  const _ShieldPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double scaleX = size.width / 320;
    final double scaleY = size.height / 440;

    canvas.save();
    canvas.scale(scaleX, scaleY);

    // ── Заливка (самый внешний контур) ──────────────────────────────────
    final fillPath = Path()
      ..moveTo(160, 20 + 14)
      ..cubicTo(180, 34, 260 - 14 * 0.3, 50 + 14 * 0.5, 256, 79)
      ..lineTo(256, 190)
      ..cubicTo(256, 265 - 14 * 0.3, 230 - 14 * 0.5, 320 - 14 * 0.5, 160, 390 - 14 * 1.2)
      ..cubicTo(90 + 14 * 0.5, 320 - 14 * 0.5, 64, 265 - 14 * 0.3, 64, 190)
      ..lineTo(64, 79)
      ..cubicTo(60 + 14 * 0.8, 57, 143, 34, 160, 34)
      ..close();

    final fillPaint = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // ── Граница заливки (тонкая белая рамка) ────────────────────────────
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawPath(fillPath, borderPaint);

    // ── Концентрические линии внутри ────────────────────────────────────
    final lines = [
      _ShieldLine(offset: 14, strokeWidth: 2.2, opacity: 0.80),
      _ShieldLine(offset: 26, strokeWidth: 1.8, opacity: 0.60),
      // _ShieldLine(offset: 37, strokeWidth: 1.4, opacity: 0.42),
    ];

    for (final line in lines) {
      final o = line.offset.toDouble();
      final paint = Paint()
        ..color = Colors.white.withOpacity(line.opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = line.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final path = Path()
        ..moveTo(160, 20 + o)
        ..cubicTo(180, 20 + o, 260 - o * 0.3, 50 + o * 0.5, 270 - o, 65 + o)
        ..lineTo(270 - o, 190)
        ..cubicTo(270 - o, 265 - o * 0.3, 230 - o * 0.5, 320 - o * 0.5, 160, 390 - o * 1.2)
        ..cubicTo(90 + o * 0.5, 320 - o * 0.5, 50 + o, 265 - o * 0.3, 50 + o, 190)
        ..lineTo(50 + o, 65 + o)
        ..cubicTo(60 + o * 0.8, 50 + o * 0.5, 140 + o * 0.3, 20 + o, 160, 20 + o)
        ..close();

      canvas.drawPath(path, paint);
    }

    // ── Заголовок "Guardians" на щите ──
    final titleStyle = TextStyle(
      color: Colors.white.withOpacity(0.9),
      fontSize: 20,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.5,
    );
    final titlePainter = TextPainter(
      text: TextSpan(text: 'Guardians', style: titleStyle),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 200);
    titlePainter.paint(
      canvas,
      Offset(160 - titlePainter.width / 2, 90),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_ShieldPainter old) => false;
}

class _ShieldLine {
  final int offset;
  final double strokeWidth;
  final double opacity;
  const _ShieldLine({required this.offset, required this.strokeWidth, required this.opacity});
}