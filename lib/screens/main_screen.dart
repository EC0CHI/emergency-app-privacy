import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../services/user_service.dart';
import 'settings_screen.dart';
import '../services/sos_service.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:vibration/vibration.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';

class MainScreen extends StatefulWidget {
  final void Function(String) updateLocale;

  const MainScreen({super.key, required this.updateLocale});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  String _userId = '';
  String _userName = '';
  bool _isLoading = true;
  bool _isSending = false;
  bool _isLongPressing = false;
  double _pressProgress = 0.0;
  Timer? _pressTimer;
  List<String> _guardianNames = [];

  bool _showEditDialog = false;
  final _editController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _pressTimer?.cancel();
    _editController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final userId = await UserService.getUserId();
    final userName = await UserService.getUserName();
    final prefs = await SharedPreferences.getInstance();

    final names = <String>[];
    for (int i = 1; i <= 5; i++) {
      final nick = prefs.getString('guardian${i}_nickname') ?? '';
      final id = prefs.getString('guardian$i') ?? '';
      if (id.isNotEmpty) names.add(nick.isNotEmpty ? nick : id);
    }

    if (mounted) {
      setState(() {
        _userId = userId;
        _userName = userName ?? '';
        _guardianNames = names;
        _isLoading = false;
      });
    }
  }

  void _openEditDialog() {
    _editController.text = _userName;
    setState(() => _showEditDialog = true);
  }

  void _closeEditDialog() {
    setState(() => _showEditDialog = false);
  }

  Future<void> _saveName(String name) async {
    try {
      await UserService.saveUserName(name);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved locally. Sync error: $e')),
        );
      }
    }
    if (mounted) {
      setState(() => _userName = name);
    }
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _userId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('ID copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.white24,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _shareId() {
    Share.share(
      'Add me as guardian in Emergency App: $_userId',
      subject: 'My Emergency ID',
    );
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
              content: Text('SOS sent to ${result['recipients']} guardians'),
              backgroundColor: Colors.green[700],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                              const Text(
                                'Guardians',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 22,
                                  letterSpacing: 0.5,
                                ),
                              ),
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
                        // Expanded(
                        //   child: Center(
                        //     child: SizedBox(
                        //       width: 480,
                        //       height: 620,
                        //       child: Stack(
                        //         children: [
                        //           CustomPaint(
                        //             size: const Size(480, 620),
                        //             painter: _ShieldPainter(guardianNames: _guardianNames),
                        //           ),
                        //           // Tap-зона только в центре щита (крест)
                        //           Center(
                        //             child: GestureDetector(
                        //               behavior: HitTestBehavior.opaque,
                        //               onTap: () => Navigator.push(
                        //                 context,
                        //                 MaterialPageRoute(
                        //                   builder: (context) => const GuardiansScreen(),
                        //                 ),
                        //               ).then((_) => _loadUserData()),
                        //               child: const SizedBox(
                        //                 width: 160,  // ширина зоны = armH * 2
                        //                 height: 260, // высота зоны = armV * 2
                        //               ),
                        //             ),
                        //           ),
                        //         ],
                        //       ),
                        //     ),
                        //   ),
                        // ),

                        // ── Shield ─────────────────────────────────────────
                        Expanded(
                          child: Center(
                            child: SizedBox(
                              width: 480,
                              height: 620,
                              child: Stack(
                                children: [
                                  CustomPaint(
                                    size: const Size(480, 620),
                                    painter: _ShieldPainter(guardianNames: _guardianNames),
                                  ),
                                  // ── Скрещенные алебарды вместо креста ──
                                  Positioned.fill(
                                    child: Center(
                                      child: Padding(
                                        padding: EdgeInsets.only(
                                          top: _guardianNames.isEmpty ? 0 : _guardianNames.length * 42.0,
                                        ),
                                        child: SvgPicture.asset(
                                          'assets/images/Vectorizer-io-halberd.svg',
                                          width: _guardianNames.isEmpty ? 180 : 130,
                                          height: _guardianNames.isEmpty ? 180 : 130,
                                          colorFilter: ColorFilter.mode(
                                            Colors.white.withOpacity(0.85),
                                            BlendMode.srcIn,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // ── Tap-зона ──
                                  Center(
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const GuardiansScreen(),
                                        ),
                                      ).then((_) => _loadUserData()),
                                      child: const SizedBox(
                                        width: 180,
                                        height: 280,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
                                  height: 96,
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
                                              minHeight: 96,
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

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shield CustomPainter — концентрические белые линии ────────────────────────

class _ShieldPainter extends CustomPainter {
  final List<String> guardianNames;

  const _ShieldPainter({this.guardianNames = const []});

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


    if (guardianNames.isNotEmpty) {
      const cx = 160.0;
      const lineH = 28.0;

      final namesHeight = guardianNames.length * lineH;

      const shieldTop = 60.0;
      const shieldBottom = 360.0;
      final startY = shieldTop + (shieldBottom - shieldTop - namesHeight) / 2 - 40;

      for (int i = 0; i < guardianNames.length; i++) {
        final tp = TextPainter(
          text: TextSpan(
            text: guardianNames[i],
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 180);
        tp.paint(canvas, Offset(cx - tp.width / 2, startY + i * lineH));
      }
    }

      // // ── Крест ──────────────────────────────────────
      // final crossCy = startY + namesHeight + gapBetween + crossArmV;

      // // _drawCross(canvas, cx, crossCy, crossArmH, crossArmV);

      // // ── Текст на кресте ────────────────────────────
      // const gap = 5.0;
      // final ts = TextStyle(
      //   color: Colors.white.withOpacity(0.65),
      //   fontSize: 10,
      //   fontWeight: FontWeight.w600,
      //   letterSpacing: 0.5,
      // );

      // final sectors = [
      //   ['Tap',  cx - crossArmH / 3.8, crossCy - gap * 1.3],
      //   ['To',   cx + crossArmH / 5.8,   crossCy - gap * 1.3],
      //   ['Add',  cx - crossArmH / 3.8, crossCy + gap * 1.3],
      //   ['Name', cx + crossArmH / 2.7,   crossCy + gap * 1.3],
      // ];

      // for (final s in sectors) {
      //   final tp = TextPainter(
      //     text: TextSpan(text: s[0] as String, style: ts),
      //     textAlign: TextAlign.center,
      //     textDirection: TextDirection.ltr,
      //   )..layout(maxWidth: crossArmH - gap);
      //   tp.paint(canvas, Offset(
      //     (s[1] as double) - tp.width / 2,
      //     (s[2] as double) - tp.height / 2,
      //   ));
      // }
    // }

    canvas.restore();
  }

  // void _drawCross(Canvas canvas, double cx, double cy, double armH, double armV) {
  //   // Glow
  //   final glowPaint = Paint()
  //     ..color = Colors.white.withOpacity(0.15)
  //     ..style = PaintingStyle.stroke
  //     ..strokeWidth = 12
  //     ..strokeCap = StrokeCap.round
  //     ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

  //   canvas.drawLine(Offset(cx - armH, cy), Offset(cx + armH, cy), glowPaint);
  //   canvas.drawLine(Offset(cx, cy - armV), Offset(cx, cy + armV), glowPaint);

  //   // Cross
  //   final crossPaint = Paint()
  //     ..color = Colors.white.withOpacity(0.9)
  //     ..style = PaintingStyle.stroke
  //     ..strokeWidth = 3
  //     ..strokeCap = StrokeCap.round;

  //   canvas.drawLine(Offset(cx - armH, cy), Offset(cx + armH, cy), crossPaint);
  //   canvas.drawLine(Offset(cx, cy - armV), Offset(cx, cy + armV), crossPaint);
  // }

  @override
  bool shouldRepaint(_ShieldPainter old) => old.guardianNames != guardianNames;
}

class _ShieldLine {
  final int offset;
  final double strokeWidth;
  final double opacity;
  const _ShieldLine({required this.offset, required this.strokeWidth, required this.opacity});
}