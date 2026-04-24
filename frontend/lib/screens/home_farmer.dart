import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/local_db_service.dart';
import '../services/sync_service.dart';
import '../widgets/app_widgets.dart';
import '../widgets/translated_widget.dart';
import 'login_screen.dart';
import 'animal_form_screen.dart';
import 'audit_log_screen.dart';
import 'dashboard_screen.dart';
import 'notifications_screen.dart';
import 'rfid_scanner_screen.dart';

class HomeFarmer extends StatefulWidget {
  final String farmName;
  const HomeFarmer({super.key, required this.farmName});

  @override
  State<HomeFarmer> createState() => _HomeFarmerState();
}

class _HomeFarmerState extends State<HomeFarmer> with TranslatedWidget {
  Map<String, dynamic>? animal;
  List<dynamic> myAnimals = [];
  bool loading = false;
  bool loadingList = false;
  bool isOnline = true;
  int _tabIndex = 0;
  String username = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  void _init() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => username = prefs.getString('username') ?? '');
    await _loadMyAnimals();
    _checkOnline();
    SyncService.listenConnectivity(() async {
      setState(() => isOnline = true);
      await SyncService.syncPendingActions();
      await _loadMyAnimals();
    });
  }

  void _checkOnline() async {
    final online = await SyncService.isOnline();
    if (mounted) setState(() => isOnline = online);
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

  Future<void> _loadMyAnimals() async {
    setState(() => loadingList = true);
    try {
      final online = await SyncService.isOnline();
      if (online) {
        final data = await ApiService.getMyAnimals();
        await LocalDbService.cacheAnimals(data);
        if (mounted) setState(() => myAnimals = data);
      } else {
        final cached = await LocalDbService.getCachedAnimals();
        if (mounted) setState(() => myAnimals = cached);
      }
    } catch (e) {
      final cached = await LocalDbService.getCachedAnimals();
      if (mounted) setState(() => myAnimals = cached);
    } finally {
      if (mounted) setState(() => loadingList = false);
    }
  }

  void _openCameraScanner() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => RfidScannerScreen(
          title: tr('scan_rfid'),
          subtitle: tr('scan_description'),
          color: const Color(0xFF1B5E20),
        ),
      ),
    );

    if (result != null && result.isNotEmpty) {
      _scanAnimal(result);
    }
  }

  void _scanAnimal(String rfid) async {
    setState(() => loading = true);
    try {
      final online = await SyncService.isOnline();
      Map<String, dynamic>? data;

      if (online) {
        data = await ApiService.scanAnimal(rfid);
      } else {
        final cached = await LocalDbService.getAnimalByRfid(rfid);
        if (cached != null) {
          data = cached;
        } else {
          throw Exception(tr('scan_first'));
        }
      }

      setState(() => animal = data);
      await LocalDbService.addAuditLog('SCAN_RFID', 'Animal $rfid scanné', username);
      _snack('✅ Animal: $rfid', color: Colors.green);
    } catch (e) {
      _snack(e.toString().replaceAll('Exception: ', ''));
      setState(() => animal = null);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool('rememberMe') ?? false;
    if (!remember) await prefs.clear();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E20),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('DZcheptel',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            Text(widget.farmName, style: const TextStyle(color: Colors.white70, fontSize: 12)),
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
                Icon(isOnline ? Icons.wifi : Icons.wifi_off, color: Colors.white, size: 14),
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
              child: Text(
                tr('offline_banner'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          Expanded(
            child: IndexedStack(
              index: _tabIndex,
              children: [
                _buildScanPage(),
                _buildAnimalsPage(),
                _buildDashboardPage(),
                _buildProfilePage(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _tabIndex == 0
          ? FloatingActionButton.extended(
        onPressed: _openCameraScanner,
        backgroundColor: const Color(0xFF1B5E20),
        icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
        label: Text(tr('scan_rfid'), style: const TextStyle(color: Colors.white)),
      )
          : _tabIndex == 1
          ? FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AnimalFormScreen(onSaved: () => _loadMyAnimals()),
            ),
          );
        },
        backgroundColor: const Color(0xFF1B5E20),
        child: const Icon(Icons.add, color: Colors.white),
      )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
        selectedItemColor: const Color(0xFF1B5E20),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.qr_code_scanner), label: tr('scan_btn')),
          BottomNavigationBarItem(icon: const Icon(Icons.list_alt), label: tr('my_animals')),
          BottomNavigationBarItem(icon: const Icon(Icons.dashboard), label: tr('dashboard_tab')),
          BottomNavigationBarItem(icon: const Icon(Icons.person), label: tr('profile_tab')),
        ],
      ),
    );
  }

  Widget _buildScanPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1B5E20), Color(0xFF388E3C)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6)),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.qr_code_scanner, color: Colors.white, size: 28),
                    const SizedBox(width: 10),
                    Text(
                      tr('identification_active'),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(tr('scan_description'), style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _openCameraScanner,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: Colors.white, borderRadius: BorderRadius.circular(14)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.qr_code_scanner,
                            color: Color(0xFF1B5E20), size: 24),
                        const SizedBox(width: 10),
                        Text(
                          tr('scan_camera'),
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: Color(0xFF1B5E20)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          if (loading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: Color(0xFF1B5E20)),
            ),

          if (animal != null) ...[
            _buildAnimalCard(),
            const SizedBox(height: 12),
            _buildAnimalActions(),
          ],

          if (animal == null && !loading)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Column(
                children: [
                  Icon(Icons.pets, size: 100, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(tr('scan_animal'),
                      style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[400],
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAnimalCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Text(
                    'ID TAG #${animal!['rfidTag']}',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                        fontSize: 12),
                  ),
                ),
                const Spacer(),
                StatusBadge(animal!['status'] ?? 'Active'),
              ],
            ),
            const SizedBox(height: 12),
            Text(animal!['breed'] ?? 'Animal',
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _infoBox(tr('species_label'), animal!['species'] ?? '-')),
                const SizedBox(width: 10),
                Expanded(child: _infoBox(tr('gender_label'), animal!['gender'] ?? '-')),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _infoBox(tr('farm_label'), animal!['farmName'] ?? '-')),
                const SizedBox(width: 10),
                Expanded(
                    child: _infoBox(tr('location_label'), animal!['farmLocation'] ?? 'N/A')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimalActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AnimalFormScreen(
                    existingAnimal: animal,
                    onSaved: () => _loadMyAnimals(),
                  ),
                ),
              );
            },
            icon: const Icon(Icons.edit),
            label: Text(tr('edit_btn')),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              foregroundColor: const Color(0xFF1B5E20),
              side: const BorderSide(color: Color(0xFF1B5E20)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.medical_services),
            label: Text(tr('new_care_btn')),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnimalsPage() {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(tr('my_animals'),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: Colors.green[50], borderRadius: BorderRadius.circular(20)),
                child: Text(
                  '${myAnimals.length} ${tr('animals_count')}',
                  style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                onPressed: _loadMyAnimals,
                icon: const Icon(Icons.refresh, color: Color(0xFF1B5E20)),
              ),
            ],
          ),
        ),
        Expanded(
          child: loadingList
              ? const Center(child: CircularProgressIndicator())
              : myAnimals.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.pets, size: 80, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(tr('no_activity')),
              ],
            ),
          )
              : RefreshIndicator(
            onRefresh: _loadMyAnimals,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
              itemCount: myAnimals.length,
              itemBuilder: (_, i) {
                final a = myAnimals[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green[100],
                      child: Icon(
                        a['species'] == 'Ovin' ? Icons.pets : Icons.agriculture,
                        color: const Color(0xFF1B5E20),
                      ),
                    ),
                    title: Text('${a['rfidTag']} - ${a['breed']}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${a['species']} • ${a['gender']}'),
                    trailing: StatusBadge(a['status'] ?? 'Active'),
                    onTap: () {
                      setState(() {
                        animal = {
                          'id': a['id'],
                          'rfidTag': a['rfidTag'],
                          'species': a['species'],
                          'breed': a['breed'],
                          'gender': a['gender'],
                          'status': a['status'],
                          'farmName': a['farm']?['name'] ?? a['farmName'] ?? '',
                          'farmLocation':
                          a['farm']?['location'] ?? a['farmLocation'] ?? '',
                        };
                        _tabIndex = 0;
                      });
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardPage() {
    int total = myAnimals.length;
    int active = myAnimals.where((a) => a['status'] == 'Active').length;
    int ovin = myAnimals.where((a) => a['species'] == 'Ovin').length;
    int bovin = myAnimals.where((a) => a['species'] == 'Bovin').length;
    int sold = myAnimals.where((a) => a['status'] == 'Sold').length;
    int quarantined = myAnimals.where((a) => a['status'] == 'Quarantined').length;
    int lost = myAnimals.where((a) => a['status'] == 'Lost').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('dashboard_tab'),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.3,
            children: [
              InfoCard(
                  label: tr('total_animals'),
                  value: '$total',
                  icon: Icons.pets,
                  color: const Color(0xFF1B5E20)),
              InfoCard(
                  label: tr('active_animals'),
                  value: '$active',
                  icon: Icons.check_circle,
                  color: Colors.green),
              InfoCard(
                  label: tr('ovine_animals'),
                  value: '$ovin',
                  icon: Icons.cruelty_free,
                  color: Colors.blue),
              InfoCard(
                  label: tr('bovine_animals'),
                  value: '$bovin',
                  icon: Icons.agriculture,
                  color: Colors.orange),
            ],
          ),
          const SizedBox(height: 24),
          Text(tr('status_label'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (total > 0) ...[
            _statusBar(tr('active_animals'), active, total, Colors.green),
            const SizedBox(height: 8),
            _statusBar('Vendu', sold, total, Colors.blue),
            const SizedBox(height: 8),
            _statusBar('Quarantaine', quarantined, total, Colors.orange),
            const SizedBox(height: 8),
            _statusBar('Perdu', lost, total, Colors.red),
          ] else
            Text(tr('no_activity'), style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          Text(tr('quick_actions'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: [
              ActionButton(
                icon: Icons.add_circle,
                label: tr('add_btn'),
                color: const Color(0xFF1B5E20),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => AnimalFormScreen(onSaved: () => _loadMyAnimals())),
                ),
              ),
              ActionButton(
                icon: Icons.qr_code_scanner,
                label: tr('scan_btn'),
                color: Colors.blue,
                onTap: _openCameraScanner,
              ),
              ActionButton(
                icon: Icons.sync,
                label: tr('sync_btn'),
                color: Colors.teal,
                onTap: () async {
                  final count = await SyncService.syncPendingActions();
                  await _loadMyAnimals();
                  if (!mounted) return;
                  _snack('✅ $count ${tr('synced_msg')}', color: Colors.green);
                },
              ),
              ActionButton(
                icon: Icons.history,
                label: tr('journal_btn'),
                color: Colors.purple,
                onTap: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const AuditLogScreen())),
              ),
              ActionButton(
                icon: Icons.notifications,
                label: tr('alerts_btn'),
                color: Colors.orange,
                onTap: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
              ),
              ActionButton(
                icon: Icons.bar_chart,
                label: tr('stats_btn'),
                color: Colors.indigo,
                onTap: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const DashboardScreen())),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusBar(String label, int count, int total, Color color) {
    final double pct = total > 0 ? count / total : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            Text('$count',
                style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 18,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildProfilePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 10),
          CircleAvatar(
            radius: 50,
            backgroundColor: const Color(0xFF1B5E20),
            child: Text(
              username.isNotEmpty ? username[0].toUpperCase() : 'F',
              style: const TextStyle(fontSize: 40, color: Colors.white),
            ),
          ),
          const SizedBox(height: 12),
          Text(username,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text(widget.farmName, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
                color: Colors.green[50], borderRadius: BorderRadius.circular(20)),
            child: Text(tr('farmer_role_name'),
                style: const TextStyle(
                    color: Color(0xFF1B5E20), fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 30),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.home, color: Color(0xFF1B5E20)),
                  title: Text(tr('my_farm')),
                  trailing: Text(widget.farmName,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.pets, color: Color(0xFF1B5E20)),
                  title: Text(tr('registered_animals')),
                  trailing: Text('${myAnimals.length}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.history, color: Color(0xFF1B5E20)),
                  title: Text(tr('activity_log')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AuditLogScreen())),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.notifications, color: Color(0xFF1B5E20)),
                  title: Text(tr('notifications_title')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NotificationsScreen())),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: Colors.red),
            label: Text(tr('logout_btn'),
                style: const TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              side: const BorderSide(color: Colors.red),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}