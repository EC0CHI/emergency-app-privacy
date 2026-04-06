export 'guardians_screen.dart';

import 'package:flutter/material.dart';
import 'guardians_screen.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../services/user_service.dart';
import 'language_screen.dart';
import 'donate_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SettingsScreen extends StatefulWidget {
  final void Function(String) updateLocale;

  const SettingsScreen({
    super.key,
    required this.updateLocale,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _userName = '';
  String _userId = '';
  bool _isLoading = true;
  bool _showEditDialog = false;
  final _editController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  Future<void> _loadUserId() async {
    final userId = await UserService.getUserId();
    final userName = await UserService.getUserName();
    setState(() {
      _userName = userName ?? '';
      _userId = userId;
      _isLoading = false;
    });
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
    if (mounted) setState(() => _userName = name);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Stack(
      children: [
        Scaffold(
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
              child: Column(
                children: [
                  // ── AppBar ───────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 18),
                        ),
                        Expanded(
                          child: Text(
                            loc.settings,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 22,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 18),
                      ],
                    ),
                  ),

                  // ── Content ──────────────────────────────────────────
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator(color: Colors.white))
                        : ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            children: [
                              const SizedBox(height: 8),

                              // ── Profile card ─────────────────────────
                              SizedBox(
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    SvgPicture.asset(
                                      'assets/images/scroll_paper.svg',
                                      width: MediaQuery.of(context).size.width - 40,
                                      height: 220,
                                      fit: BoxFit.fill,
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 24),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Name row
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      _userName.isNotEmpty ? _userName : '—',
                                                      style: const TextStyle(
                                                        fontSize: 22,
                                                        fontWeight: FontWeight.w800,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      loc.yourName,
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: Colors.white.withOpacity(0.5),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              GestureDetector(
                                                onTap: _openEditDialog,
                                                child: const Icon(Icons.edit_outlined, color: Colors.white, size: 20),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 20),
                                          // ID row
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      _userId,
                                                      style: TextStyle(
                                                        fontSize: 22,
                                                        fontWeight: FontWeight.w800,
                                                        letterSpacing: 2.5,
                                                        color: Colors.white.withOpacity(0.85),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      loc.yourId,
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: Colors.white.withOpacity(0.5),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              GestureDetector(
                                                onTap: _copyToClipboard,
                                                child: const Icon(Icons.content_copy, color: Colors.white, size: 20),
                                              ),
                                              const SizedBox(width: 16),
                                              GestureDetector(
                                                onTap: _shareId,
                                                child: const Icon(Icons.ios_share, color: Colors.white, size: 20),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 20),

                              // ── Menu items ───────────────────────────
                              _buildMenuCard(
                                icon: Icons.shield_outlined,
                                title: loc.guardians,
                                subtitle: loc.manageGuardians,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const GuardiansScreen()),
                                ),
                              ),

                              const SizedBox(height: 14),

                              _buildMenuCard(
                                icon: Icons.favorite_outline,
                                title: loc.donate,
                                subtitle: loc.supportDev,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const DonateScreen()),
                                ),
                              ),

                              const SizedBox(height: 14),

                              _buildMenuCard(
                                icon: Icons.language_outlined,
                                title: loc.language,
                                subtitle: loc.changeLanguage,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => LanguageScreen(updateLocale: widget.updateLocale),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 32),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Edit Name dialog ──────────────────────────────────────────
        if (_showEditDialog)
          const ModalBarrier(color: Colors.black54, dismissible: false),
        if (_showEditDialog)
          Center(
            child: StatefulBuilder(
              builder: (ctx, setDialogState) {
                final canConfirm = _editController.text.trim().isNotEmpty;
                return AlertDialog(
                  backgroundColor: const Color(0xFF6B0000),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  title: const Text(
                    'Edit Name',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  content: TextField(
                    controller: _editController,
                    maxLength: 50,
                    style: const TextStyle(color: Colors.white),
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Your name',
                      labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white),
                      ),
                      counterStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: _closeEditDialog,
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: Colors.white.withOpacity(0.6)),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFFB71C1C),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: canConfirm
                          ? () async {
                              final name = _editController.text.trim();
                              _closeEditDialog();
                              await _saveName(name);
                            }
                          : null,
                      child: const Text(
                        'Save',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: 110,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SvgPicture.asset(
              'assets/images/scroll_paper.svg',
              width: MediaQuery.of(context).size.width - 40,
              height: 110,
              fit: BoxFit.fill,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Icon(icon, color: Colors.white, size: 28),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white.withOpacity(0.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}