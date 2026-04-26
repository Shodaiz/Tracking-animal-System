import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/app_localizations.dart';
import 'screens/login_screen.dart';
import 'screens/home_farmer.dart';
import 'screens/home_vet.dart';
import 'screens/home_controller.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  await AppLocalizations.instance.loadSavedLanguage();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppLocalizations.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'DZcheptel',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            primarySwatch: Colors.green,
            useMaterial3: true,
          ),
          home: const AuthWrapper(),
        );
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final prefs = snapshot.data!;
        final token = prefs.getString('token') ?? '';
        final role = prefs.getString('role') ?? '';
        final farmName = prefs.getString('farmName') ?? '';

        if (token.isEmpty) return const LoginScreen();
        if (role == 'Farmer') return HomeFarmer(farmName: farmName);
        if (role == 'Veterinarian') return const HomeVet();
        if (role == 'Inspector') return const HomeController();

        return const LoginScreen();
      },
    );
  }
}