import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/guardians_service.dart';

class _GuardianEntry {
  final int slot;
  final String id;
  final String nickname;
  final String? name;
  final bool hasError;
  final bool isLoading;

  const _GuardianEntry({
    required this.slot,
    required this.id,
    required this.nickname,
    this.name,
    this.hasError = false,
    this.isLoading = false,
  });
}

/// Displays the list of saved guardians with names fetched from Supabase.
/// FR-14: parallel loading via Future.wait (NFR-07).
/// FR-15: display logic (name+nick / name / nick / id).
/// FR-16: on error → only User ID (EC-04 / C-04).
class GuardianListWidget extends StatefulWidget {
  const GuardianListWidget({super.key});

  @override
  State<GuardianListWidget> createState() => _GuardianListWidgetState();
}

class _GuardianListWidgetState extends State<GuardianListWidget> {
  List<_GuardianEntry> _items = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    final loadingItems = <_GuardianEntry>[];
    for (int slot = 1; slot <= 5; slot++) {
      final id = prefs.getString('guardian$slot') ?? '';
      if (id.isEmpty) continue;
      final nick = prefs.getString('guardian${slot}_nickname') ?? '';
      loadingItems.add(_GuardianEntry(
        slot: slot,
        id: id,
        nickname: nick,
        isLoading: true,
      ));
    }

    if (!mounted) return;
    setState(() => _items = loadingItems);

    // NFR-07: all futures start before any completes (Future.wait = parallel)
    // EC-07: Future.wait preserves original order regardless of completion order
    final futures = loadingItems.map((item) async {
      try {
        final name = await GuardiansService.findUserName(item.id);
        return _GuardianEntry(
          slot: item.slot,
          id: item.id,
          nickname: item.nickname,
          name: name,
        );
      } catch (_) {
        // FR-16: exception → hasError = true → display only User ID
        return _GuardianEntry(
          slot: item.slot,
          id: item.id,
          nickname: item.nickname,
          hasError: true,
        );
      }
    }).toList(); // toList() starts all futures before Future.wait begins

    final results = await Future.wait(futures);
    if (!mounted) return;
    setState(() => _items = results);
  }

  /// FR-15 display logic (used only when hasError = false).
  String _primaryText(_GuardianEntry entry) {
    final nick = entry.nickname.isEmpty ? null : entry.nickname;
    final name = entry.name;
    if (name != null && nick != null) return '$name ($nick)';
    if (name != null) return name;
    if (nick != null) return nick;
    return entry.id;
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();
    return Column(
      children: _items.map(_buildItem).toList(),
    );
  }

  Widget _buildItem(_GuardianEntry entry) {
    final slot = entry.slot;

    if (entry.isLoading) {
      return Padding(
        key: Key('guardian_list_item_$slot'),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: SizedBox(
          height: 16,
          width: 16,
          child: CircularProgressIndicator(
            key: Key('guardian_list_loading_$slot'),
            strokeWidth: 2,
          ),
        ),
      );
    }

    // FR-16: error → only User ID, no nickname
    if (entry.hasError) {
      return Padding(
        key: Key('guardian_list_item_$slot'),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Text(entry.id, key: Key('guardian_list_primary_$slot')),
      );
    }

    final primary = _primaryText(entry);
    final showSecondary = primary != entry.id;

    return Padding(
      key: Key('guardian_list_item_$slot'),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(primary, key: Key('guardian_list_primary_$slot')),
          if (showSecondary)
            Text(
              entry.id,
              key: Key('guardian_list_secondary_$slot'),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
        ],
      ),
    );
  }
}
