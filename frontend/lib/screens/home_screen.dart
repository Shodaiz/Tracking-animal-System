import 'package:flutter/material.dart';
import 'farmer_screen.dart';
import 'vet_screen.dart';
import 'controller_screen.dart';
import 'constat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const FarmerScreen(),     // SCAN
    const VetScreen(),        // FICHE
    const ControllerScreen(), // SANTÉ / Contrôle
    const ConstatScreen(),    // CONSTAT
  ];

  final List<String> _titles = [
    "Scan RFID",
    "Fiche Animal",
    "Contrôle UHF",
    "Déclaration Constat"
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        backgroundColor: const Color(0xFF1B5E20),
        elevation: 0,
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF1B5E20),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner),
            label: 'SCAN',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.description),
            label: 'FICHE',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.health_and_safety),
            label: 'SANTÉ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.warning_amber),
            label: 'CONSTAT',
          ),
        ],
      ),
    );
  }
}