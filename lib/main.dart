import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'giris/login_screen.dart'; // We'll still use some components from here
import 'Screens/main_screen.dart';
import 'theme/theme.dart';

// Global Supabase client
final supabase = Supabase.instance.client;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://liakumkphqymxfxdwrsc.supabase.co',
    anonKey: 'sb_publishable_5m4IgOFoyU4Bwd5gv9Oriw_09TOevQW',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZenGuard',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.seismoDarkTheme,
      home: const AnimatedAuthScreen(), // Our new animated screen
    );
  }
}

class AnimatedAuthScreen extends StatefulWidget {
  const AnimatedAuthScreen({super.key});

  @override
  State<AnimatedAuthScreen> createState() => _AnimatedAuthScreenState();
}

class _AnimatedAuthScreenState extends State<AnimatedAuthScreen> with TickerProviderStateMixin {
  late AnimationController _gridController;
  late AnimationController _logoController;
  late AnimationController _transitionController;
  late StreamSubscription<AuthState> _authSubscription;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _showLoginForm = false;

  @override
  void initState() {
    super.initState();

    _gridController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _logoController = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _transitionController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));

    // Start the logo animation after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if(mounted) _logoController.forward();
    });

    _authSubscription = supabase.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null) {
        // If user is logged in, navigate to home immediately
        if (mounted) {
           Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          );
        }
      }
    });

    // After the main animation, decide whether to show login or navigate away
    _logoController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Check if user is already logged in
        final user = supabase.auth.currentUser;
        if (user == null) {
          // If not logged in, trigger the transition to the login form
          setState(() {
            _showLoginForm = true;
          });
          _transitionController.forward();
        }
      }
    });
  }

  @override
  void dispose() {
    _gridController.dispose();
    _logoController.dispose();
    _transitionController.dispose();
    _authSubscription.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      // The stream listener will handle navigation
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.message, style: const TextStyle(color: Colors.white)),
          backgroundColor: Colors.redAccent,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      body: Stack(
        children: [
          // Animated Background
          CustomPaint(
            painter: GridPainter(_gridController),
            child: Container(),
          ),
          // Logo and Title Animation
          _buildLogoAndTitle(),
          // Login Form Animation
          if (_showLoginForm) _buildLoginForm(),
        ],
      ),
    );
  }

  Widget _buildLogoAndTitle() {
    return AnimatedBuilder(
      animation: _transitionController,
      builder: (context, child) {
        // Defines the vertical position of the logo during the transition
        final yOffset = _transitionController.value * - (MediaQuery.of(context).size.height / 4);
        return Transform.translate(
          offset: Offset(0, yOffset),
          child: child,
        );
      },
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pulsating Logo
            FadeTransition(
              opacity: _logoController,
              child: ScaleTransition(
                scale: _logoController.drive(CurveTween(curve: Curves.elasticOut)),
                child: CustomPaint(
                  painter: LogoPainter(_logoController),
                  child: Container(
                    width: 150,
                    height: 150,
                    alignment: Alignment.center,
                    child: const Icon(Icons.shield_outlined, size: 70, color: Color(0xFF135BEC)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
            // Typing Text Effect
            TypingText(
              'ZenGuard',
              controller: _logoController,
              style: Theme.of(context).textTheme.displaySmall!.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 10),
            TypingText(
              'Afet Yönetim Sistemi',
              controller: _logoController,
              begin: const Duration(milliseconds: 1000),
              style: Theme.of(context).textTheme.titleMedium!.copyWith(color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return FadeTransition(
      opacity: _transitionController,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
            .animate(_transitionController),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                 SizedBox(height: MediaQuery.of(context).size.height / 2.5),
                _buildFormFields(),
                const SizedBox(height: 20),
                _buildButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

    Widget _buildFormFields() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              TextField(
                controller: _emailController,
                enabled: !_isLoading,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration("E-posta", Icons.alternate_email),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _passwordController,
                enabled: !_isLoading,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration("Şifre", Icons.lock_outline),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.4)),
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
      floatingLabelStyle: const TextStyle(color: Color(0xFF135BEC)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFF135BEC)),
      ),
    );
  }

  Widget _buildButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF135BEC),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              elevation: 8,
              shadowColor: const Color(0xFF135BEC).withOpacity(0.5)
            ),
            onPressed: _isLoading ? null : _signIn,
            child: _isLoading
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white,))
                : const Text("GİRİŞ YAP", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: _isLoading ? null : () {
            // Navigate to register screen - you'd create a similar animated experience for it
          },
          child: Text("Hesabın yok mu? Kayıt Ol", style: TextStyle(color: Colors.white.withOpacity(0.7))),
        )
      ],
    );
  }
}

// --- Custom Painters and Widgets for Animation ---

class GridPainter extends CustomPainter {
  final Animation<double> animation;
  GridPainter(this.animation) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF135BEC).withOpacity(0.1)
      ..strokeWidth = 0.5;
    
    // Draw grid
    for (int i = 0; i < size.width / 40; i++) {
      canvas.drawLine(Offset(i * 40, 0), Offset(i * 40, size.height), paint);
    }
    for (int i = 0; i < size.height / 40; i++) {
      canvas.drawLine(Offset(0, i * 40), Offset(size.width, i * 40), paint);
    }

    // Draw scanline
    final scanlinePos = (animation.value * size.height * 1.5) - (size.height * 0.5);
    final gradient = LinearGradient(
      colors: [Colors.transparent, const Color(0xFF135BEC).withOpacity(0.5), Colors.transparent],
      stops: const [0.0, 0.5, 1.0],
    );
    final scanlinePaint = Paint()..shader = gradient.createShader(Rect.fromLTWH(0, scanlinePos - 20, size.width, 40));
    canvas.drawRect(Rect.fromLTWH(0, scanlinePos - 20, size.width, 40), scanlinePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}


class LogoPainter extends CustomPainter {
  final Animation<double> animation;
  LogoPainter(this.animation) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = const Color(0xFF135BEC)
      ..style = PaintingStyle.stroke;
    
    final radius = (size.width / 2) * 0.9;
    
    // Draw pulsating rings
    for (int i = 1; i <= 3; i++) {
      final wave = (animation.value + (i * 0.3)) % 1.0;
      final easedWave = Curves.easeInOut.transform(wave);
      paint.strokeWidth = 2.0 * (1 - easedWave);
      paint.color = const Color(0xFF135BEC).withOpacity(1 - easedWave);
      canvas.drawCircle(center, radius * easedWave, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}


class TypingText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final AnimationController controller;
  final Duration begin;

  const TypingText(this.text, {super.key, required this.style, required this.controller, this.begin = Duration.zero});

  @override
  State<TypingText> createState() => _TypingTextState();
}

class _TypingTextState extends State<TypingText> {
  String _displayedText = '';
  Timer? _timer;
  int _charIndex = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addStatusListener((status) {
      if (status == AnimationStatus.forward || status == AnimationStatus.completed) {
        Future.delayed(widget.begin, _startTyping);
      }
    });
  }

  void _startTyping() {
    if(!mounted) return;
    const typingSpeed = Duration(milliseconds: 50);
    _timer?.cancel();
    _timer = Timer.periodic(typingSpeed, (timer) {
      if (_charIndex < widget.text.length) {
        setState(() {
          _charIndex++;
          _displayedText = widget.text.substring(0, _charIndex);
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(_displayedText, style: widget.style, textAlign: TextAlign.center,);
  }
}