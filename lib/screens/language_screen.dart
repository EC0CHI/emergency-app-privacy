import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class LanguageScreen extends StatefulWidget {
  final void Function(String) updateLocale;

  const LanguageScreen({Key? key, required this.updateLocale}) : super(key: key);

  @override
  _LanguageScreenState createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  String _selectedLanguage = 'ru';

  @override
  void initState() {
    super.initState();
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedLanguage = prefs.getString('language') ?? 'ru';
    });
  }

  Future<void> _saveLanguage(String language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', language);
    setState(() => _selectedLanguage = language);
    widget.updateLocale(language);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Language updated'),
        backgroundColor: Colors.white24,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 2),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) Navigator.pop(context);
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
              // AppBar
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
                        loc.language,
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

              // Content
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    const SizedBox(height: 32),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                      ),
                      child: Column(
                        children: [
                          _buildLanguageItem(flag: '🇷🇺', language: loc.russian, code: 'ru', isFirst: true),
                          _buildDivider(),
                          _buildLanguageItem(flag: '🇬🇧', language: loc.english, code: 'en'),
                          _buildDivider(),
                          _buildLanguageItem(flag: '🇨🇳', language: loc.chinese, code: 'zh'),
                          _buildDivider(),
                          _buildLanguageItem(flag: '🇪🇸', language: loc.spanish, code: 'es'),
                          _buildDivider(),
                          _buildLanguageItem(flag: '🇸🇦', language: loc.arabic, code: 'ar'),
                          _buildDivider(),
                          _buildLanguageItem(flag: '🇫🇷', language: loc.french, code: 'fr'),
                          _buildDivider(),
                          _buildLanguageItem(flag: '🇩🇪', language: loc.german, code: 'de', isLast: true),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageItem({
    required String flag,
    required String language,
    required String code,
    bool isFirst = false,
    bool isLast = false,
  }) {
    final isSelected = _selectedLanguage == code;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _saveLanguage(code),
        borderRadius: BorderRadius.vertical(
          top: isFirst ? const Radius.circular(20) : Radius.zero,
          bottom: isLast ? const Radius.circular(20) : Radius.zero,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Text(flag, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  language,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
              if (isSelected)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.check, color: Color(0xFFB71C1C), size: 16),
                )
              else
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                  ),
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
      child: Container(height: 0.5, color: Colors.white.withOpacity(0.15)),
    );
  }
}