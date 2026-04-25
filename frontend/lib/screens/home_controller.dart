import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/local_db_service.dart';
import '../services/sync_service.dart';
import '../widgets/translated_widget.dart';
import 'login_screen.dart';
import 'uhf_scanner_screen.dart';

class HomeController extends StatefulWidget {
  const HomeController({super.key});

  @override
  State<HomeController> createState() => _HomeControllerState();
}

class _HomeControllerState extends State<HomeController> with TranslatedWidget {
  int _tabIndex = 0;
  int _farmId = 1;
  bool _loading = false;
  bool isOnline = true;
  final List<String> scannedTags = [];
  Map<String, dynamic>? _result;
  final _constatController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkOnline();
    SyncService.listenConnectivity(() async {
      if (mounted) setState(() => isOnline = true);
      await SyncService.syncPendingActions();
    });
  }

  @override
  void dispose() {
    _constatController.dispose();
    super.dispose();
  }

  void _snack(String msg, {Color color = Colors.red}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _checkOnline() async {
    final online = await SyncService.isOnline();
    if (mounted) setState(() => isOnline = online);
  }

  void _openUhfScanner() async {
    final List<String>? result = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(builder: (_) => const UhfScannerScreen()),
    );

    if (result != null && result.isNotEmpty) {
      int added = 0;
      for (final tag in result) {
        if (!scannedTags.contains(tag)) {
          scannedTags.add(tag);
          added++;
        }
      }
      setState(() {});
      if (added > 0) {
        _snack('✅ $added ${tr('synced_msg')}', color: Colors.green);
      }
    }
  }

  void _verifyScan() async {
    if (scannedTags.isEmpty) {
      _snack(tr('no_tags'), color: Colors.orange);
      return;
    }
    setState(() => _loading = true);
    try {
      final result = await ApiService.verifyScan(_farmId, scannedTags);
      setState(() => _result = result);
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _confirmCheck() async {
    if (scannedTags.isEmpty) {
      _snack(tr('no_tags'), color: Colors.orange);
      return;
    }
    try {
      final online = await SyncService.isOnline();
      if (online) {
        await ApiService.confirmCheck(_farmId);
      } else {
        await LocalDbService.savePendingAction(
            'confirm_check', jsonEncode({'farmId': _farmId}));
      }
      _snack(tr('inventory_confirmed'), color: Colors.green);
    } catch (e) {
      _snack(e.toString());
    }
  }

  void _declareConstat() async {
    if (_constatController.text.trim().isEmpty) {
      _snack(tr('field_required'), color: Colors.orange);
      return;
    }
    try {
      final online = await SyncService.isOnline();
      if (online) {
        await ApiService.declareConstat(_farmId, _constatController.text.trim());
        _snack(tr('constat_declared'), color: Colors.green);
      } else {
        await LocalDbService.savePendingAction(
          'declare_constat',
          jsonEncode({
            'farmId': _farmId,
            'description': _constatController.text.trim()
          }),
        );
        _snack(tr('constat_saved_offline'), color: Colors.orange);
      }
      _constatController.clear();
    } catch (e) {
      _snack(e.toString());
    }
  }

  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A237E),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('DZcheptel',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
            Text(tr('audit_session'),
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isOnline ? Colors.green[300] : Colors.orange[300],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(isOnline ? Icons.wifi : Icons.wifi_off,
                    color: Colors.white, size: 14),
                const SizedBox(width: 4),
                Text(
                  isOnline ? tr('online_status') : tr('offline_status'),
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
          ),
        ],
      ),
      body: Column(
        children: [
          if (!isOnline)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              color: Colors.orange[700],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wifi_off, color: Colors.white, size: 14),
                  const SizedBox(width: 6),
                  Text(tr('offline_banner'),
                      style: const TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            ),
          Expanded(
            child: IndexedStack(
              index: _tabIndex,
              children: [
                _buildScanPage(),
                _buildConstatPage(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _tabIndex == 0
          ? FloatingActionButton.extended(
        onPressed: _openUhfScanner,
        backgroundColor: Colors.indigo,
        icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
        label: Text(tr('scan_uhf'),
            style: const TextStyle(color: Colors.white)),
      )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
        selectedItemColor: const Color(0xFF1A237E),
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(
              icon: const Icon(Icons.qr_code_scanner), label: tr('scan_uhf')),
          BottomNavigationBarItem(
              icon: const Icon(Icons.warning_amber), label: tr('constat_title')),
        ],
      ),
    );
  }

  Widget _buildScanPage() {
    final bool hasResult = _result != null;
    final bool isOk = hasResult && _result!['isConsistent'] == true;
    final int scannedCount = _result?['scannedCount'] ?? scannedTags.length;
    final int registeredCount = _result?['registeredCount'] ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black12)],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('verify_effectif'),
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.indigo[50],
                      borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const Icon(Icons.qr_code_scanner, color: Colors.indigo),
                      const SizedBox(width: 8),
                      Text(tr('uhf_range'),
                          style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      const Spacer(),
                      Text(tr('uhf_meters'),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: _farmId,
                  decoration: InputDecoration(
                    labelText: tr('farm_to_control'),
                    prefixIcon: const Icon(Icons.home),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Ferme El Baraka')),
                    DropdownMenuItem(
                        value: 2, child: Text('Ferme Ouled Djellal')),
                  ],
                  onChanged: (v) => setState(() {
                    _farmId = v ?? 1;
                    _result = null;
                  }),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.tag, size: 18, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text('${tr('scanned_tags')} : ${scannedTags.length}',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          const Spacer(),
                          if (scannedTags.isNotEmpty)
                            GestureDetector(
                              onTap: () => setState(() {
                                scannedTags.clear();
                                _result = null;
                              }),
                              child: Text(tr('erase_btn'),
                                  style: const TextStyle(
                                      color: Colors.red, fontSize: 12)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (scannedTags.isEmpty)
                        Text(tr('no_tags'),
                            style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      if (scannedTags.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: scannedTags
                              .map((tag) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(tag,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500)),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () =>
                                      setState(() => scannedTags.remove(tag)),
                                  child: const Icon(Icons.close,
                                      size: 14, color: Colors.red),
                                ),
                              ],
                            ),
                          ))
                              .toList(),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _loading ? null : _verifyScan,
                        icon: _loading
                            ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.search),
                        label: Text(tr('verify_btn')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A237E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _confirmCheck,
                        icon: const Icon(Icons.check_circle),
                        label: Text(tr('check_btn')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1B5E20),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_loading) const CircularProgressIndicator(),

          if (hasResult)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black12)],
              ),
              child: Column(
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '$scannedCount',
                          style: TextStyle(
                              fontSize: 60,
                              fontWeight: FontWeight.bold,
                              color: isOk ? Colors.green : Colors.red),
                        ),
                        TextSpan(
                          text: ' / $registeredCount',
                          style: const TextStyle(
                              fontSize: 30, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Text(tr('animals_detected'),
                      style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isOk ? Colors.green[50] : Colors.red[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: isOk ? Colors.green[200]! : Colors.red[200]!),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(isOk ? Icons.check_circle : Icons.warning,
                            color: isOk ? Colors.green : Colors.red),
                        const SizedBox(width: 8),
                        Text(
                          isOk ? tr('effectif_ok') : tr('gap_detected'),
                          style: TextStyle(
                              color: isOk ? Colors.green[800] : Colors.red[800],
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  if (!isOk &&
                      (_result!['missingTags'] as List?)?.isNotEmpty == true) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr('missing_tags'),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red)),
                          const SizedBox(height: 8),
                          ...(_result!['missingTags'] as List).map(
                                (tag) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  const Icon(Icons.cancel,
                                      color: Colors.red, size: 18),
                                  const SizedBox(width: 8),
                                  Text(tag.toString(),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (!isOk &&
                      (_result!['unknownTags'] as List?)?.isNotEmpty == true) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr('unknown_tags'),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange)),
                          const SizedBox(height: 8),
                          ...(_result!['unknownTags'] as List).map(
                                (tag) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  const Icon(Icons.help,
                                      color: Colors.orange, size: 18),
                                  const SizedBox(width: 8),
                                  Text(tag.toString()),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildConstatPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber, size: 40, color: Colors.orange),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('constat_title'),
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(tr('constat_subtitle'),
                          style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          DropdownButtonFormField<int>(
            initialValue: _farmId,
            decoration: InputDecoration(
              labelText: tr('farm_concerned'),
              prefixIcon: const Icon(Icons.home),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: const [
              DropdownMenuItem(value: 1, child: Text('Ferme El Baraka')),
              DropdownMenuItem(value: 2, child: Text('Ferme Ouled Djellal')),
            ],
            onChanged: (v) => setState(() => _farmId = v ?? 1),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _constatController,
            maxLines: 8,
            decoration: InputDecoration(
              labelText: tr('constat_description'),
              prefixIcon: const Padding(
                padding: EdgeInsets.only(bottom: 120),
                child: Icon(Icons.edit_note),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _declareConstat,
            icon: const Icon(Icons.send),
            label: Text(tr('declare_constat'), style: const TextStyle(fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[700],
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}