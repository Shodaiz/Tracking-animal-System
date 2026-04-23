import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/app_localizations.dart';
import 'home_farmer.dart';
import 'home_vet.dart';
import 'home_controller.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _acceptConditions = false;
  bool _rememberMe = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _animController.forward();
    _loadSavedCredentials();
  }

  void _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('rememberMe') ?? false) {
      setState(() {
        _rememberMe = true;
        _usernameController.text = prefs.getString('savedUsername') ?? '';
      });
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Raccourci pour les traductions
  String tr(String key) => AppLocalizations.t(key);

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

  void _login() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptConditions) {
      _snack(tr('accept_conditions_error'), color: Colors.orange);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final data = await ApiService.login(
        _usernameController.text.trim(),
        _passwordController.text.trim(),
      );

      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setBool('rememberMe', true);
        await prefs.setString('savedUsername', _usernameController.text.trim());
      } else {
        await prefs.setBool('rememberMe', false);
        await prefs.remove('savedUsername');
      }

      if (!mounted) return;
      final role = data['role'];
      if (role == 'ROLE_FARMER') {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => HomeFarmer(farmName: data['farmName'] ?? '')));
      } else if (role == 'ROLE_VET') {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const HomeVet()));
      } else if (role == 'ROLE_CONTROLLER') {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const HomeController()));
      }
    } catch (e) {
      _snack(tr('login_error'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showForgotPasswordDialog() {
    final identifierCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    int step = 1;
    bool loading = false;
    String foundUsername = '';
    String foundEmail = '';
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            const Icon(Icons.lock_reset, color: Color(0xFF1B5E20)),
            const SizedBox(width: 8),
            Text(step == 1
                ? tr('forgot_title')
                : step == 2
                ? tr('account_found')
                : tr('success_title')),
          ]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (step == 1) ...[
                  Text(tr('forgot_subtitle'),
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  TextField(
                    controller: identifierCtrl,
                    decoration: InputDecoration(
                      labelText: tr('identifier_label'),
                      hintText: tr('identifier_hint'),
                      prefixIcon: const Icon(Icons.person_search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.blue[50], borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      const Icon(Icons.info_outline, color: Colors.blue, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(tr('identifier_info'),
                          style: const TextStyle(fontSize: 12))),
                    ]),
                  ),
                ],
                if (step == 2) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green[200]!)),
                    child: Column(children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 40),
                      const SizedBox(height: 8),
                      Text(tr('account_found'),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                      const SizedBox(height: 4),
                      Text(foundUsername, style: const TextStyle(fontSize: 13)),
                      if (foundEmail.isNotEmpty)
                        Text(foundEmail, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: newPassCtrl,
                    obscureText: obscureNew,
                    decoration: InputDecoration(
                      labelText: tr('new_password'),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmPassCtrl,
                    obscureText: obscureConfirm,
                    decoration: InputDecoration(
                      labelText: tr('confirm_password'),
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
                if (step == 3) ...[
                  const Icon(Icons.check_circle, color: Colors.green, size: 60),
                  const SizedBox(height: 12),
                  Text(tr('password_reset_ok'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(tr('password_reset_msg'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey)),
                ],
              ],
            ),
          ),
          actions: [
            if (step != 3)
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(tr('cancel_btn')),
              ),
            if (step == 3)
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B5E20)),
                child: Text(tr('sign_in'), style: const TextStyle(color: Colors.white)),
              ),
            if (step == 1)
              ElevatedButton(
                onPressed: loading ? null : () async {
                  if (identifierCtrl.text.trim().isEmpty) {
                    _snack(tr('field_required'), color: Colors.orange);
                    return;
                  }
                  setDialogState(() => loading = true);
                  try {
                    final result = await ApiService.forgotPassword(identifierCtrl.text.trim());
                    foundUsername = result['username'] ?? '';
                    foundEmail = result['email'] ?? '';
                    setDialogState(() { step = 2; loading = false; });
                  } catch (e) {
                    setDialogState(() => loading = false);
                    _snack(e.toString().replaceAll('Exception: ', ''));
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B5E20)),
                child: loading
                    ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(tr('search_btn'), style: const TextStyle(color: Colors.white)),
              ),
            if (step == 2)
              ElevatedButton(
                onPressed: loading ? null : () async {
                  if (newPassCtrl.text.length < 6) {
                    _snack('Minimum 6 caractères', color: Colors.orange);
                    return;
                  }
                  if (newPassCtrl.text != confirmPassCtrl.text) {
                    _snack('Les mots de passe ne correspondent pas', color: Colors.orange);
                    return;
                  }
                  setDialogState(() => loading = true);
                  try {
                    await ApiService.resetPassword(identifierCtrl.text.trim(), newPassCtrl.text.trim());
                    setDialogState(() { step = 3; loading = false; });
                  } catch (e) {
                    setDialogState(() => loading = false);
                    _snack(e.toString().replaceAll('Exception: ', ''));
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B5E20)),
                child: loading
                    ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(tr('reset_btn'), style: const TextStyle(color: Colors.white)),
              ),
          ],
        ),
      ),
    );
  }

  void _showConditions() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.description, color: Color(0xFF1B5E20)),
          const SizedBox(width: 8),
          Text(tr('conditions_title')),
        ]),
        content: SingleChildScrollView(child: Text(tr('conditions_text'))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('close_btn'))),
          ElevatedButton(
            onPressed: () {
              setState(() => _acceptConditions = true);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B5E20)),
            child: Text(tr('accept_btn'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppLocalizations.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F0),
          body: FadeTransition(
            opacity: _fadeAnim,
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // ─── SÉLECTEUR LANGUE ───
                        Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.language, size: 18, color: Color(0xFF1B5E20)),
                                const SizedBox(width: 6),
                                DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: AppLocalizations.instance.currentLang,
                                    isDense: true,
                                    icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'fr',
                                        child: Row(children: [
                                          Text('🇫🇷', style: TextStyle(fontSize: 16)),
                                          SizedBox(width: 6),
                                          Text('Français'),
                                        ]),
                                      ),
                                      DropdownMenuItem(
                                        value: 'en',
                                        child: Row(children: [
                                          Text('en', style: TextStyle(fontSize: 16)),
                                          SizedBox(width: 6),
                                          Text('English'),
                                        ]),
                                      ),
                                      DropdownMenuItem(
                                        value: 'ar',
                                        child: Row(children: [
                                          Text('🇩🇿', style: TextStyle(fontSize: 16)),
                                          SizedBox(width: 6),
                                          Text('العربية'),
                                        ]),
                                      ),
                                    ],
                                    onChanged: (val) async {
                                      await AppLocalizations.instance.setLanguage(val!);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ─── LOGO ───
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B5E20),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(color: Colors.green.withOpacity(0.3),
                                  blurRadius: 20, offset: const Offset(0, 8)),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.asset('assets/icon/icon.png', width: 80, height: 80,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                const Icon(Icons.agriculture, size: 80, color: Colors.white)),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ─── TITRE (traduit automatiquement) ───
                        Text(tr('app_name'),
                            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold,
                                color: Color(0xFF1B5E20), letterSpacing: 1.5)),
                        const SizedBox(height: 6),
                        Text(tr('login'),
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Text(tr('login_subtitle'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey, fontSize: 14)),
                        const SizedBox(height: 40),

                        // ─── Identifiant ───
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(tr('username_label'),
                              style: const TextStyle(fontWeight: FontWeight.bold,
                                  fontSize: 11, letterSpacing: 1)),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _usernameController,
                          validator: (v) => v == null || v.isEmpty ? tr('field_required') : null,
                          decoration: InputDecoration(
                            hintText: tr('username_hint'),
                            prefixIcon: const Icon(Icons.person_outline),
                            filled: true, fillColor: Colors.white,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFF1B5E20), width: 2)),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ─── Mot de passe ───
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(tr('password_label'),
                              style: const TextStyle(fontWeight: FontWeight.bold,
                                  fontSize: 11, letterSpacing: 1)),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          validator: (v) => v == null || v.isEmpty ? tr('field_required') : null,
                          decoration: InputDecoration(
                            hintText: tr('password_hint'),
                            prefixIcon: const Icon(Icons.lock_outline),
                            filled: true, fillColor: Colors.white,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFF1B5E20), width: 2)),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ─── Rester connecté + Mot de passe oublié ───
                        Row(children: [
                          Checkbox(
                            value: _rememberMe,
                            activeColor: const Color(0xFF1B5E20),
                            onChanged: (v) => setState(() => _rememberMe = v ?? false),
                          ),
                          Text(tr('remember_me')),
                          const Spacer(),
                          TextButton(
                            onPressed: _showForgotPasswordDialog,
                            child: Text(tr('forgot_password'),
                                style: const TextStyle(color: Color(0xFF1B5E20))),
                          ),
                        ]),

                        // ─── Conditions ───
                        Row(children: [
                          Checkbox(
                            value: _acceptConditions,
                            activeColor: const Color(0xFF1B5E20),
                            onChanged: (v) => setState(() => _acceptConditions = v ?? false),
                          ),
                          Text(tr('accept_conditions')),
                          GestureDetector(
                            onTap: _showConditions,
                            child: Text(tr('conditions_link'),
                                style: const TextStyle(color: Color(0xFF1B5E20),
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline)),
                          ),
                        ]),
                        const SizedBox(height: 24),

                        // ─── Bouton Connexion ───
                        SizedBox(
                          width: double.infinity, height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1B5E20),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 4,
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Text(tr('connect_button'),
                                  style: const TextStyle(fontSize: 17, color: Colors.white)),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward, color: Colors.white),
                            ]),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ─── Créer un compte ───
                        SizedBox(
                          width: double.infinity, height: 56,
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => const RegisterScreen())),
                            icon: const Icon(Icons.person_add, color: Color(0xFF1B5E20)),
                            label: Text(tr('create_account'),
                                style: const TextStyle(fontSize: 16, color: Color(0xFF1B5E20))),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF1B5E20), width: 2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),

                        // ─── Copyright ───
                        Text(tr('copyright'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey, fontSize: 10)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}