import 'package:flutter/material.dart';
import '../services/user_service.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _controller = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onContinue() async {
    final name = _controller.text.trim();
    setState(() => _isSaving = true);
    try {
      await UserService.saveUserName(name);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved locally. Sync error: $e'),
            backgroundColor: Colors.white24,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      }
    }
    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.pushReplacementNamed(context, '/main');
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = !_isSaving && _controller.text.trim().isNotEmpty;
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
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),

                // ── Title ──────────────────────────────────────────────────
                Text(
                  loc.welcome,
                  style: TextStyle(
                    fontSize: MediaQuery.of(context).size.height < 700 ? 32 : 40,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12),
                Text(
                  loc.welcomeDescription,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.6),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),

                const Spacer(),

                // ── Input ──────────────────────────────────────────────────
                TextField(
                  key: const Key('welcome_name_field'),
                  controller: _controller,
                  maxLength: 50,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.12),
                    labelText: 'Your name',
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                    counterStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.2), width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Colors.white, width: 2),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Button ─────────────────────────────────────────────────
                GestureDetector(
                  onTap: canSubmit ? _onContinue : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: MediaQuery.of(context).size.height * 0.08,
                    decoration: BoxDecoration(
                      color: canSubmit ? Colors.white : Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(36),
                    ),
                    child: Center(
                      child: _isSaving
                          ? SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                color: const Color(0xFFB71C1C),
                                strokeWidth: 2.5,
                              ),
                            )
                          : Text(
                              loc.continueButton,
                              key: const Key('welcome_continue_button'),
                              style: TextStyle(
                                color: canSubmit
                                    ? const Color(0xFFB71C1C)
                                    : Colors.white.withOpacity(0.4),
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
