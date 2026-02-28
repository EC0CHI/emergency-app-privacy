import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../services/user_service.dart';
import 'settings_screen.dart';
import 'package:flutter/services.dart';
import '../services/sos_service.dart';
import 'dart:async';
import 'package:vibration/vibration.dart';

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

  // Inline dialog state (no Navigator push — avoids route observer interference)
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
    setState(() {
      _userId = userId;
      _userName = userName ?? '';
      _isLoading = false;
    });
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
        setState(() {
          _pressProgress = progress;
        });
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${result['error']}'),
              backgroundColor: Colors.red[700],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8EDF2),
      appBar: AppBar(
        title: const Text(
          'Emergency',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.settings_outlined, color: Color(0xFF1A1A1A), size: 20),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsScreen(
                    updateLocale: widget.updateLocale,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // ── Main content ──────────────────────────────────────────────────
          _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF3B30)))
              : Column(
                  children: [
                    // Scrollable top section keeps the card visible even with
                    // long names without causing Column overflow.
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            const SizedBox(height: 24),

                            // ID Card
                            Container(
                              key: const Key('my_id_card'),
                              margin: const EdgeInsets.symmetric(horizontal: 20),
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
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
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFF3B30).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(
                                          Icons.fingerprint,
                                          color: Color(0xFFFF3B30),
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        'Your ID',
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: Color(0xFF8E8E93),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  // FR-17: show user name above ID (only if set)
                                  if (_userName.isNotEmpty)
                                    Text(
                                      _userName,
                                      key: const Key('user_name_display'),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1A1A1A),
                                      ),
                                    ),
                                  Text(
                                    _userId,
                                    key: const Key('user_id_display'),
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 4,
                                      color: Color(0xFF1A1A1A),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  // FR-18: Edit Name button
                                  SizedBox(
                                    width: double.infinity,
                                    child: TextButton(
                                      key: const Key('edit_name_button'),
                                      onPressed: _openEditDialog,
                                      child: const Text('Edit Name'),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildActionButton(
                                          icon: Icons.content_copy,
                                          label: 'Copy',
                                          onTap: _copyToClipboard,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
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
                          ],
                        ),
                      ),
                    ),

                    // SOS Button — pinned to bottom outside the scroll view
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          GestureDetector(
                            onLongPressStart: _onLongPressStart,
                            onLongPressEnd: _onLongPressEnd,
                            child: Container(
                              width: double.infinity,
                              height: 140,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: _isSending
                                      ? [Colors.grey[400]!, Colors.grey[500]!]
                                      : _isLongPressing
                                          ? [const Color(0xFFD32F2F), const Color(0xFFB71C1C)]
                                          : [const Color(0xFFFF3B30), const Color(0xFFFF1744)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(70),
                                boxShadow: [
                                  BoxShadow(
                                    color: _isSending
                                        ? Colors.grey.withOpacity(0.3)
                                        : const Color(0xFFFF3B30).withOpacity(0.4),
                                    blurRadius: 30,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  // Progress overlay
                                  if (_isLongPressing)
                                    Positioned.fill(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(70),
                                        child: LinearProgressIndicator(
                                          value: _pressProgress,
                                          backgroundColor: Colors.transparent,
                                          valueColor: const AlwaysStoppedAnimation<Color>(
                                            Color(0xFFB71C1C),
                                          ),
                                          minHeight: 140,
                                        ),
                                      ),
                                    ),
                                  // Content
                                  Center(
                                    child: _isSending
                                        ? const SizedBox(
                                            width: 40,
                                            height: 40,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 3,
                                            ),
                                          )
                                        : const Text(
                                            'SOS',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 56,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 4,
                                            ),
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _isSending
                                ? 'Sending emergency alert...'
                                : _isLongPressing
                                    ? 'Keep holding...'
                                    : 'Hold for 5 seconds to send SOS',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),

          // ── Inline Edit Name dialog (no Navigator push) ───────────────────
          if (_showEditDialog)
            const ModalBarrier(color: Colors.black54, dismissible: false),
          if (_showEditDialog)
            Center(
              child: StatefulBuilder(
                builder: (ctx, setDialogState) {
                  final canConfirm = _editController.text.trim().isNotEmpty;
                  return AlertDialog(
                    key: const Key('edit_name_dialog'),
                    title: const Text('Edit Name'),
                    content: TextField(
                      key: const Key('edit_name_field'),
                      controller: _editController,
                      maxLength: 50,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Your name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    actions: [
                      TextButton(
                        key: const Key('edit_name_cancel_button'),
                        onPressed: _closeEditDialog,
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        key: const Key('edit_name_confirm_button'),
                        onPressed: canConfirm
                            ? () async {
                                final name = _editController.text.trim();
                                _closeEditDialog();
                                await _saveName(name);
                              }
                            : null,
                        child: const Text('Save'),
                      ),
                    ],
                  );
                },
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
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: const Color(0xFF1A1A1A)),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
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
}
