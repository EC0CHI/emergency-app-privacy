import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../services/guardians_service.dart';

class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

class GuardiansScreen extends StatefulWidget {
  const GuardiansScreen({super.key});

  @override
  State<GuardiansScreen> createState() => _GuardiansScreenState();
}

class _GuardiansScreenState extends State<GuardiansScreen> {
  static const int _count = 5;

  late List<TextEditingController> _idControllers;
  late List<TextEditingController> _nicknameControllers;

  final List<Timer?> _debounceTimers = List<Timer?>.filled(_count, null);
  final List<int> _generations = List<int>.filled(_count, 0);
  final List<bool> _isSearching = List<bool>.filled(_count, false);
  final List<bool> _searchCompleted = List<bool>.filled(_count, false);
  final List<String?> _foundNames = List<String?>.filled(_count, null);

  @override
  void initState() {
    super.initState();
    _idControllers = List.generate(_count, (_) => TextEditingController());
    _nicknameControllers = List.generate(_count, (_) => TextEditingController());
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    for (int i = 0; i < _count; i++) {
      _idControllers[i].text = prefs.getString('guardian${i + 1}') ?? '';
      _nicknameControllers[i].text =
          prefs.getString('guardian${i + 1}_nickname') ?? '';
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final t in _debounceTimers) t?.cancel();
    for (final c in _idControllers) c.dispose();
    for (final c in _nicknameControllers) c.dispose();
    super.dispose();
  }

  void _onIdChanged(int idx, String value) {
    _debounceTimers[idx]?.cancel();
    if (value.isEmpty) {
      setState(() {
        _isSearching[idx] = false;
        _searchCompleted[idx] = false;
        _foundNames[idx] = null;
      });
      return;
    }
    _debounceTimers[idx] = Timer(
      const Duration(milliseconds: 500),
      () => _performSearch(idx, value),
    );
  }

  Future<void> _performSearch(int idx, String userId) async {
    _generations[idx]++;
    final gen = _generations[idx];

    setState(() {
      _isSearching[idx] = true;
      _searchCompleted[idx] = false;
    });

    String? name;
    try {
      name = await GuardiansService.findUserName(userId);
    } catch (_) {
      name = null;
    }

    if (gen != _generations[idx]) return;

    if (mounted) {
      setState(() {
        _isSearching[idx] = false;
        _searchCompleted[idx] = true;
        _foundNames[idx] = name;
        if (name != null && _nicknameControllers[idx].text.isEmpty) {
          _nicknameControllers[idx].text = name;
        }
      });
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    for (int i = 0; i < _count; i++) {
      await prefs.setString('guardian${i + 1}', _idControllers[i].text);
      await prefs.setString(
          'guardian${i + 1}_nickname', _nicknameControllers[i].text);
    }
    if (mounted) {
      setState(() {});
      Navigator.pop(context);
    }
  }

  /// Status icon for the ID field
  Widget? _suffixIcon(int idx) {
    if (_isSearching[idx]) {
      return const Padding(
        padding: EdgeInsets.all(10),
        child: SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
        ),
      );
    }
    if (_searchCompleted[idx]) {
      final found = _foundNames[idx] != null;
      return Icon(
        found ? Icons.check_circle : Icons.error_outline,
        color: found ? Colors.greenAccent : Colors.redAccent.withOpacity(0.8),
        size: 18,
      );
    }
    return null;
  }

  InputDecoration _fieldDecoration(String hint, {Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      filled: true,
      fillColor: Colors.white.withOpacity(0.08),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.white38, width: 1),
      ),
      suffixIcon: suffix,
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
            colors: [Color(0xFFB71C1C), Color(0xFF7B0000), Color(0xFF3A0000)],
            stops: [0.0, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                // ── Header ──
                const SizedBox(height: 8),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white70, size: 18),
                    ),
                    Expanded(
                      child: Text(
                        loc.guardians,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                  ],
                ),

                // ── Guardian rows ──
                Expanded(
                  child: Column(
                   mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height < 700 ? 40 : 84),
                      for (int i = 0; i < _count; i++) ...[
                        _buildRow(i),
                        if (i < _count - 1) const SizedBox(height: 14),
                      ],
                    ],
                  ),
                ),

                // ── Save button ──
                Padding(
                  padding: const EdgeInsets.only(bottom: 12, top: 8),
                  child: GestureDetector(
                    onTap: _save,
                    child: Container(
                      key: const Key('guardians_save_button'),
                      width: 200,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.25),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          loc.save,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
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
      ),
    );
  }

  Widget _buildRow(int idx) {
    final slot = idx + 1;

    return Row(
      children: [
        // Slot number
        SizedBox(
          width: 24,
          child: Text(
            '$slot',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Colors.white.withOpacity(0.35),
            ),
          ),
        ),

        // ID field
        Expanded(
          flex: 5,
          child: TextField(
            key: Key('guardian_id_field_$slot'),
            controller: _idControllers[idx],
            onChanged: (v) => _onIdChanged(idx, v),
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [_UpperCaseTextFormatter()],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
            decoration: _fieldDecoration('ID', suffix: _suffixIcon(idx)),
          ),
        ),

        const SizedBox(width: 10),

        // Nickname field
        Expanded(
          flex: 5,
          child: TextField(
            key: Key('guardian_nickname_field_$slot'),
            controller: _nicknameControllers[idx],
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            decoration: _fieldDecoration('Nickname'),
          ),
        ),
      ],
    );
  }
}