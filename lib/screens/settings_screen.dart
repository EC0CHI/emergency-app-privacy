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
                        const Expanded(
                          child: Text(
                            'Settings',
                            textAlign: TextAlign.center,
                            style: TextStyle(
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
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                                ),
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
                                                'Your name',
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
                                          child: Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: const Icon(Icons.edit_outlined, color: Colors.white, size: 20),
                                          ),
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
                                                'Your ID',
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
                                          child: Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: const Icon(Icons.content_copy, color: Colors.white, size: 20),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        GestureDetector(
                                          onTap: _shareId,
                                          child: Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: const Icon(Icons.ios_share, color: Colors.white, size: 20),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 20),

                              // ── Menu items (donate crypto style) ───
                              _buildMenuCard(
                                icon: Icons.shield_outlined,
                                title: loc.guardians,
                                subtitle: 'Manage your guardians',
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const GuardiansScreen()),
                                ),
                              ),

                              const SizedBox(height: 14),

                              _buildMenuCard(
                                icon: Icons.favorite_outline,
                                title: loc.donate,
                                subtitle: 'Support development',
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const DonateScreen()),
                                ),
                              ),

                              const SizedBox(height: 14),

                              _buildMenuCard(
                                icon: Icons.language_outlined,
                                title: loc.language,
                                subtitle: 'Change app language',
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
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
        ),
      ),
    );
  }
}

// ── EmergencyNumberScreen ─────────────────────────────────────────────────────

class EmergencyNumberScreen extends StatefulWidget {
  const EmergencyNumberScreen({super.key});

  @override
  State<EmergencyNumberScreen> createState() => _EmergencyNumberScreenState();
}

class _EmergencyNumberScreenState extends State<EmergencyNumberScreen> {
  late Map<String, TextEditingController> _controllers;
  final Map<String, bool> _errors = {};

  @override
  void initState() {
    super.initState();
    _controllers = {
      'guardian1': TextEditingController(),
      'guardian2': TextEditingController(),
      'guardian3': TextEditingController(),
      'guardian4': TextEditingController(),
      'guardian5': TextEditingController(),
    };
    _loadGuardianIds();
  }

  Future<void> _loadGuardianIds() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _controllers['guardian1']!.text = prefs.getString('guardian1') ?? '';
      _controllers['guardian2']!.text = prefs.getString('guardian2') ?? '';
      _controllers['guardian3']!.text = prefs.getString('guardian3') ?? '';
      _controllers['guardian4']!.text = prefs.getString('guardian4') ?? '';
      _controllers['guardian5']!.text = prefs.getString('guardian5') ?? '';
    });
  }

  bool _validateId(String id) {
    if (id.isEmpty) return true;
    if (id.length != 8) return false;
    return RegExp(r'^[A-Z0-9]+$').hasMatch(id);
  }

  Future<void> _saveGuardianIds() async {
    bool hasErrors = false;
    setState(() {
      _errors.clear();
      _controllers.forEach((key, controller) {
        final text = controller.text.trim().toUpperCase();
        if (!_validateId(text)) {
          _errors[key] = true;
          hasErrors = true;
        }
      });
    });

    if (hasErrors) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Fix invalid IDs (format: 8 characters A-Z, 0-9)'),
          backgroundColor: Colors.red[900],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('guardian1', _controllers['guardian1']!.text.trim().toUpperCase());
    await prefs.setString('guardian2', _controllers['guardian2']!.text.trim().toUpperCase());
    await prefs.setString('guardian3', _controllers['guardian3']!.text.trim().toUpperCase());
    await prefs.setString('guardian4', _controllers['guardian4']!.text.trim().toUpperCase());
    await prefs.setString('guardian5', _controllers['guardian5']!.text.trim().toUpperCase());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Guardians saved'),
          backgroundColor: Colors.green[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _controllers.forEach((_, controller) => controller.dispose());
    super.dispose();
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
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        loc.guardians,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      loc.guardiansList,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      loc.enterGuardianNumbers,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildIdField('guardian1', loc.guardian1, loc.examplePhone),
                    _buildIdField('guardian2', loc.guardian2, loc.examplePhone),
                    _buildIdField('guardian3', loc.guardian3, loc.examplePhone),
                    _buildIdField('guardian4', loc.guardian4, loc.examplePhone),
                    _buildIdField('guardian5', loc.guardian5, loc.examplePhone),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  height: 72,
                  child: GestureDetector(
                    onTap: _saveGuardianIds,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(36),
                      ),
                      child: Center(
                        child: Text(
                          loc.save,
                          style: const TextStyle(
                            color: Color(0xFFB71C1C),
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
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

  Widget _buildIdField(String key, String label, String hint) {
    final hasError = _errors[key] ?? false;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: _controllers[key],
        textCapitalization: TextCapitalization.characters,
        maxLength: 8,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
          color: Colors.white,
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white.withOpacity(0.12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: hasError ? Colors.redAccent : Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: hasError ? Colors.redAccent : Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.white, width: 2),
          ),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), letterSpacing: 0),
          labelText: label,
          labelStyle: TextStyle(
            color: hasError ? Colors.redAccent : Colors.white.withOpacity(0.6),
            fontWeight: FontWeight.w500,
          ),
          counterText: '',
          errorText: hasError ? 'Invalid ID format' : null,
          errorStyle: const TextStyle(color: Colors.redAccent),
          suffixIcon: _controllers[key]!.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, size: 20, color: Colors.white.withOpacity(0.5)),
                  onPressed: () {
                    setState(() {
                      _controllers[key]!.clear();
                      _errors.remove(key);
                    });
                  },
                )
              : null,
        ),
        onChanged: (value) {
          setState(() => _errors.remove(key));
        },
      ),
    );
  }
}