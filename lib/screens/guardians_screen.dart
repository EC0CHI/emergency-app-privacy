import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/guardians_service.dart';
import '../widgets/guardian_list_widget.dart';

class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

/// GuardiansScreen — улучшенный экран редактирования хранителей.
/// FR-09..FR-13: debounce 500ms, поиск по ID, никнейм, сохранение.
class GuardiansScreen extends StatefulWidget {
  const GuardiansScreen({super.key});

  @override
  State<GuardiansScreen> createState() => _GuardiansScreenState();
}

class _GuardiansScreenState extends State<GuardiansScreen> {
  static const int _count = 5;

  late List<TextEditingController> _idControllers;
  late List<TextEditingController> _nicknameControllers;

  // Per-slot mutable state (fixed-length lists, elements are mutable)
  final List<Timer?> _debounceTimers = List<Timer?>.filled(_count, null);
  final List<int> _generations = List<int>.filled(_count, 0);
  final List<bool> _isSearching = List<bool>.filled(_count, false);
  final List<bool> _searchCompleted = List<bool>.filled(_count, false);
  final List<String?> _foundNames = List<String?>.filled(_count, null);
  int _listRefreshKey = 0;

  @override
  void initState() {
    super.initState();
    _idControllers =
        List.generate(_count, (_) => TextEditingController());
    _nicknameControllers =
        List.generate(_count, (_) => TextEditingController());
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    for (int i = 0; i < _count; i++) {
      _idControllers[i].text =
          prefs.getString('guardian${i + 1}') ?? '';
      _nicknameControllers[i].text =
          prefs.getString('guardian${i + 1}_nickname') ?? '';
    }
    if (mounted) setState(() {});

    // Auto-fill nickname from Supabase for slots with ID but no nickname
    for (int i = 0; i < _count; i++) {
      final id = _idControllers[i].text;
      if (id.isNotEmpty && _nicknameControllers[i].text.isEmpty) {
        try {
          final name = await GuardiansService.findUserName(id);
          if (name != null && mounted && _nicknameControllers[i].text.isEmpty) {
            setState(() => _nicknameControllers[i].text = name);
          }
        } catch (_) {}
      }
    }
  }

  @override
  void dispose() {
    for (final t in _debounceTimers) {
      t?.cancel();
    }
    for (final c in _idControllers) {
      c.dispose();
    }
    for (final c in _nicknameControllers) {
      c.dispose();
    }
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

    // EC-04: discard stale response
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
      await prefs.setString(
          'guardian${i + 1}', _idControllers[i].text);
      await prefs.setString(
          'guardian${i + 1}_nickname', _nicknameControllers[i].text);
    }
    if (mounted) {
      setState(() => _listRefreshKey++);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Guardians saved')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Guardians'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              // SingleChildScrollView + Column (not ListView) ensures all 5 slots
              // are always in the widget tree, regardless of viewport height.
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GuardianListWidget(key: ValueKey(_listRefreshKey)),
                    const Divider(height: 32),
                    for (int i = 0; i < _count; i++) _buildSlot(i),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                key: const Key('guardians_save_button'),
                onPressed: _save,
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlot(int idx) {
    final slot = idx + 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: Key('guardian_id_field_$slot'),
          controller: _idControllers[idx],
          onChanged: (v) => _onIdChanged(idx, v),
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [_UpperCaseTextFormatter()],
          decoration: const InputDecoration(labelText: 'Guardian ID'),
        ),
        if (_isSearching[idx])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(
                key: Key('guardian_search_loading_$slot'),
                strokeWidth: 2,
              ),
            ),
          ),
        if (!_isSearching[idx] && _searchCompleted[idx])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              _foundNames[idx] != null
                  ? '✓ Found: ${_foundNames[idx]}'
                  : '⚠️ User not found',
              key: Key('guardian_search_status_$slot'),
            ),
          ),
        TextField(
          key: Key('guardian_nickname_field_$slot'),
          controller: _nicknameControllers[idx],
          decoration: const InputDecoration(labelText: 'Nickname'),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
