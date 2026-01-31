import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'giris/login_screen.dart';
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
      // Başlangıç ekranı animasyonlu açılış ekranımız
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _gridController;
  late AnimationController _logoController;

  @override
  void initState() {
    super.initState();

    // Arka plan ızgara animasyonu
    _gridController = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 4)
    )..repeat();

    // Logo ve yazı animasyonu
    _logoController = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 2)
    );

    // Animasyonu başlat ve bitince yönlendir
    _startAppFlow();
  }

  Future<void> _startAppFlow() async {
    // 1. Logo animasyonunu başlat
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    await _logoController.forward();

    // 2. Kısa bir süre logoyu göster (bekleme)
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;

    // 3. Oturum kontrolü ve Yönlendirme
    final session = supabase.auth.currentSession;

    Widget nextScreen;
    if (session != null) {
      nextScreen = const HomeScreen(); // Ana ekran (Screens/main_screen.dart)
    } else {
      nextScreen = const LoginScreen(); // Giriş ekranı (giris/login_screen.dart)
    }

    // Yumuşak geçiş ile yönlendir
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 800),
        pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _gridController.dispose();
    _logoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      body: Stack(
        children: [
          // Hareketli Arka Plan Izgarası
          CustomPaint(
            painter: GridPainter(_gridController),
            child: Container(),
          ),
          // Merkezdeki Logo ve Başlık
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FadeTransition(
                  opacity: _logoController,
                  child: ScaleTransition(
                    scale: _logoController.drive(CurveTween(curve: Curves.elasticOut)),
                    child: CustomPaint(
                      painter: LogoPainter(_logoController),
                      child: const SizedBox(
                        width: 150,
                        height: 150,
                        child: Icon(Icons.shield_outlined, size: 70, color: Color(0xFF135BEC)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                _buildTypingText('ZenGuard', 0),
                const SizedBox(height: 10),
                _buildTypingText('Afet Yönetim Sistemi', 1000),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingText(String text, int delayMs) {
    return TypingText(
      text,
      controller: _logoController,
      begin: Duration(milliseconds: delayMs),
      style: text.contains('ZenGuard')
          ? const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)
          : const TextStyle(fontSize: 16, color: Colors.white54),
    );
  }
}

// --- Tasarımcı Sınıfları (Custom Painters) ---

class GridPainter extends CustomPainter {
  final Animation<double> animation;
  GridPainter(this.animation) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF135BEC).withOpacity(0.05)
      ..strokeWidth = 0.5;

    for (double i = 0; i < size.width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 40) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }

    final scanlinePos = (animation.value * size.height * 1.5) - (size.height * 0.5);
    final scanlinePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, const Color(0xFF135BEC).withOpacity(0.3), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, scanlinePos, size.width, 100));

    canvas.drawRect(Rect.fromLTWH(0, scanlinePos, size.width, 100), scanlinePaint);
  }

  @override
  bool shouldRepaint(GridPainter oldDelegate) => true;
}

class LogoPainter extends CustomPainter {
  final Animation<double> animation;
  LogoPainter(this.animation) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.stroke;

    for (int i = 0; i < 2; i++) {
      final wave = (animation.value + (i * 0.5)) % 1.0;
      paint.color = const Color(0xFF135BEC).withOpacity(1 - wave);
      paint.strokeWidth = 2;
      canvas.drawCircle(center, (size.width / 2) * wave, paint);
    }
  }

  @override
  bool shouldRepaint(LogoPainter oldDelegate) => true;
}

class TypingText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final AnimationController controller;
  final Duration begin;

  const TypingText(this.text, {super.key, required this.style, required this.controller, required this.begin});

  @override
  State<TypingText> createState() => _TypingTextState();
}

class _TypingTextState extends State<TypingText> {
  String _displayedText = '';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.begin, () {
      if (mounted) _startTyping();
    });
  }

  void _startTyping() {
    int index = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 60), (timer) {
      if (index < widget.text.length) {
        if (mounted) {
          setState(() {
            _displayedText += widget.text[index];
            index++;
          });
        }
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
  Widget build(BuildContext context) => Text(_displayedText, style: widget.style);
}