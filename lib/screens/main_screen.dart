import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _isSending = false;
  bool _isLongPressing = false;
  double _pressProgress = 0.0;
  Timer? _pressTimer;
  bool _hasGuardians = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _loadUserData();
  }

  @override
  void dispose() {
    _pressTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    bool hasAny = false;
    for (int i = 1; i <= 5; i++) {
      if ((prefs.getString('guardian$i') ?? '').isNotEmpty) {
        hasAny = true;
        break;
      }
    }

    if (mounted) {
      setState(() {
        _hasGuardians = hasAny;
        _isLoading = false;
      });
      if (!hasAny) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
      }
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
          _showSnackBar('SOS sent to guardians', isError: false);
        } else {
          _showSnackBar('Error: ${result['error']}', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white.withOpacity(0.9),
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.95),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError
            ? const Color(0xFF2A0000).withOpacity(0.85)
            : const Color(0xFF1B5E20).withOpacity(0.45),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withOpacity(0.15), width: 1),
        ),
        elevation: 0,
        margin: EdgeInsets.only(
          left: 24,
          right: 24,
          bottom: MediaQuery.of(context).size.height * 0.17,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        duration: Duration(seconds: isError ? 4 : 3),
      ),
    );
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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : SafeArea(
                child: Column(
                  children: [
                    // ── AppBar ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const SizedBox(width: 22),
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SettingsScreen(
                                  updateLocale: widget.updateLocale,
                                ),
                              ),
                            ).then((_) => _loadUserData()),
                            child: const Icon(
                              Icons.settings_outlined,
                              color: Colors.white70,
                              size: 22,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const GuardiansScreen(),
                          ),
                        ).then((_) => _loadUserData()),
                        child: Padding(
                          padding: EdgeInsets.only(bottom: MediaQuery.of(context).size.height * 0.09),
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: SizedBox(
                              width: 480,
                              height: 550,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  SvgPicture.asset(
                                    'assets/images/shield.svg',
                                    width: 480,
                                    height: 550,
                                    colorFilter: ColorFilter.mode(
                                      Colors.white.withOpacity(0.85),
                                      BlendMode.srcIn,
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 550 * 0.18,
                                    child: AnimatedBuilder(
                                      animation: _pulseAnimation,
                                      builder: (context, child) {
                                        return Opacity(
                                          opacity: _hasGuardians ? 0.85 : _pulseAnimation.value,
                                          child: child,
                                        );
                                      },
                                      child: SvgPicture.asset(
                                        'assets/images/maltese_cross.svg',
                                        width: 170,
                                        height: 170,
                                        colorFilter: ColorFilter.mode(
                                          Colors.white.withOpacity(0.85),
                                          BlendMode.srcIn,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      ),
                    ),

                    // ── SOS Button ──
                    Column(
                      children: [
                        Text(
                          _isSending
                              ? loc.sendingAlert
                              : _isLongPressing
                                  ? loc.keepHolding
                                  : loc.holdToSend,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.6),
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 18),
                        GestureDetector(
                          onLongPressStart: _onLongPressStart,
                          onLongPressEnd: _onLongPressEnd,
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width,
                            height: MediaQuery.of(context).size.height * 0.12,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                SvgPicture.asset(
                                  'assets/images/scroll_paper.svg',
                                  width: MediaQuery.of(context).size.width,
                                  height: MediaQuery.of(context).size.height * 0.12,
                                  fit: BoxFit.fill,
                                ),
                                _isSending
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
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
      ),
    );
  }
}