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
  String _userId = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    final userId = await UserService.getUserId();
    setState(() {
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFFE8EDF2),
      appBar: AppBar(
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1A1A1A), size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          loc.settings,
          style: const TextStyle(
            color: Color(0xFF1A1A1A),
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF3B30)))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // ID Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF3B30).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.fingerprint,
                              color: Color(0xFFFF3B30),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Your ID',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF8E8E93),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _userId,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 3,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionButton(
                              icon: Icons.content_copy,
                              label: 'Copy',
                              onTap: _copyToClipboard,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildActionButton(
                              icon: Icons.ios_share,
                              label: 'Share',
                              onTap: _shareId,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Settings Section
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildSettingsItem(
                        icon: Icons.shield_outlined,
                        title: loc.guardians,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const GuardiansScreen(),
                          ),
                        ),
                        isFirst: true,
                      ),
                      _buildDivider(),
                      _buildSettingsItem(
                        icon: Icons.favorite_outline,
                        title: loc.donate,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const DonateScreen(),
                          ),
                        ),
                      ),
                      _buildDivider(),
                      _buildSettingsItem(
                        icon: Icons.language_outlined,
                        title: loc.language,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LanguageScreen(updateLocale: widget.updateLocale),
                          ),
                        ),
                        isLast: true,
                      ),
                    ],
                  ),
                ),
              ],
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
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: const Color(0xFF1A1A1A)),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.vertical(
          top: isFirst ? const Radius.circular(16) : Radius.zero,
          bottom: isLast ? const Radius.circular(16) : Radius.zero,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B30).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFFFF3B30),
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Color(0xFF8E8E93),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.only(left: 64),
      child: Container(
        height: 0.5,
        color: Colors.grey[300],
      ),
    );
  }
}

// EmergencyNumberScreen остается без изменений
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
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      backgroundColor: const Color(0xFFE8EDF2),
      appBar: AppBar(
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1A1A1A), size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          loc.guardians,
          style: const TextStyle(
            color: Color(0xFF1A1A1A),
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                loc.guardiansList,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[900],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                loc.enterGuardianNumbers,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[600],
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
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _saveGuardianIds,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF3B30),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    loc.save,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdField(String key, String label, String hint) {
    final hasError = _errors[key] ?? false;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: _controllers[key],
        textCapitalization: TextCapitalization.characters,
        maxLength: 8,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 2,
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: hasError ? Colors.red : Colors.grey[300]!,
              width: 1.5,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: hasError ? Colors.red : Colors.grey[300]!,
              width: 1.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: hasError ? Colors.red : const Color(0xFFFF3B30),
              width: 2,
            ),
          ),
          hintText: hint,
          labelText: label,
          labelStyle: TextStyle(
            color: hasError ? Colors.red : Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
          counterText: '',
          errorText: hasError ? 'Invalid ID format' : null,
          suffixIcon: _controllers[key]!.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 20),
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
          setState(() {
            _errors.remove(key);
          });
        },
      ),
    );
  }
}