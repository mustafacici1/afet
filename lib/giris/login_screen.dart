import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'register_screen.dart';

final supabase = Supabase.instance.client;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isNavigating = false;
  late AnimationController _formAnimationController;

  @override
  void initState() {
    super.initState();
    _formAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _formAnimationController.forward();
  }

  @override
  void dispose() {
    _formAnimationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // HATA ALDIĞIN YER: Parametreleri her ikisi de isimlendirilmiş (named) yaptık.
  Widget _buildAnimatedChild({required Widget child, required double delay}) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _formAnimationController,
        curve: Interval(delay, 1.0, curve: Curves.easeOut),
      ),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _formAnimationController,
            curve: Interval(delay, 1.0, curve: Curves.easeOut),
          ),
        ),
        child: child,
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: Colors.white70),
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.white),
      ),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
    );
  }

  Future<void> _signIn() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToRegister() {
    setState(() => _isNavigating = true);
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const RegisterScreen())).then((_) {
        if (mounted) setState(() => _isNavigating = false);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _isLoading || _isNavigating;
    return Scaffold(
      body: Stack(
        children: [
          Lottie.asset('assets/animation/login.json', fit: BoxFit.cover, width: double.infinity, height: double.infinity),
          Container(color: Colors.black.withOpacity(0.4)),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.all(30.0),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildAnimatedChild(
                          delay: 0.1,
                          child: Text("ZenGuard",
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                        ),
                        const SizedBox(height: 10),
                        _buildAnimatedChild(
                          delay: 0.2,
                          child: Text("Geleceğinizi Güvenle Koruyun",
                              style: TextStyle(color: Colors.white.withOpacity(0.6))),
                        ),
                        const SizedBox(height: 40),
                        _buildAnimatedChild(
                          delay: 0.3,
                          child: TextField(
                            controller: _emailController,
                            enabled: !isBusy,
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration("E-posta Adresi", Icons.email_outlined),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildAnimatedChild(
                          delay: 0.4,
                          child: TextField(
                            controller: _passwordController,
                            obscureText: true,
                            enabled: !isBusy,
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration("Şifre", Icons.lock_outline),
                          ),
                        ),
                        const SizedBox(height: 35),
                        _buildAnimatedChild(
                          delay: 0.5,
                          child: SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              ),
                              onPressed: isBusy ? null : _signIn,
                              child: _isLoading
                                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Text("GİRİŞ YAP"),
                            ),
                          ),
                        ),
                        const SizedBox(height: 25),
                        _buildAnimatedChild(
                          delay: 0.6,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text("Hesabınız yok mu?", style: TextStyle(color: Colors.white.withOpacity(0.6))),
                              TextButton(
                                onPressed: isBusy ? null : _navigateToRegister,
                                child: const Text("Kayıt Ol", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_isNavigating)
            Container(
              color: Colors.black.withOpacity(0.8),
              child: Center(child: Lottie.asset('assets/animation/loading.json', width: 200)),
            ),
        ],
      ),
    );
  }
}