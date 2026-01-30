import 'package:flutter/material.dart';

class AnimatedGradientButton extends StatefulWidget {
  final VoidCallback onPressed;
  final String text;

  const AnimatedGradientButton({
    required this.onPressed,
    required this.text,
    super.key,
  });

  @override
  State<AnimatedGradientButton> createState() => _AnimatedGradientButtonState();
}

class _AnimatedGradientButtonState extends State<AnimatedGradientButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        height: 56,
        transform: Matrix4.identity()..scale(_isPressed ? 0.96 : 1.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: LinearGradient(
            colors: [
              theme.primaryColor,
              theme.colorScheme.secondary,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: theme.primaryColor.withOpacity(0.3),
              blurRadius: _isPressed ? 10 : 20,
              spreadRadius: _isPressed ? -2 : -5,
              offset: Offset(0, _isPressed ? 5 : 10),
            ),
          ],
        ),
        child: Center(
          child: Text(
            widget.text,
            style: TextStyle(
              color: theme.colorScheme.onPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }
}
