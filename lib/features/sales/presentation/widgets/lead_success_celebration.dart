import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:audioplayers/audioplayers.dart';

class LeadSuccessCelebration {
  static void show(BuildContext context) {
    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;
    
    entry = OverlayEntry(
      builder: (context) => _CelebrationOverlay(
        onComplete: () => entry.remove(),
      ),
    );
    
    overlay.insert(entry);
  }
}

class _CelebrationOverlay extends StatefulWidget {
  final VoidCallback onComplete;
  const _CelebrationOverlay({required this.onComplete});

  @override
  State<_CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<_CelebrationOverlay> with SingleTickerProviderStateMixin {
  final List<String> messages = [
    '🎉 Lead Added Successfully!\nGreat job! Every lead is a new opportunity.',
    '🚀 Another Opportunity Added!\nKeep building your pipeline.',
    '💼 Lead Saved!\nYour future customer is waiting.',
  ];
  late String selectedMessage;
  final AudioPlayer _audioPlayer = AudioPlayer();
  late AnimationController _confettiController;

  @override
  void initState() {
    super.initState();
    selectedMessage = messages[Random().nextInt(messages.length)];
    _triggerFeedback();
    
    _confettiController = AnimationController(
      vsync: this, 
      duration: const Duration(seconds: 2),
    )..forward();

    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        widget.onComplete();
      }
    });
  }
  
  void _triggerFeedback() async {
    HapticFeedback.lightImpact();
    try {
      await _audioPlayer.play(AssetSource('sounds/reminder.wav'), volume: 0.1);
    } catch (_) {}
  }
  
  @override
  void dispose() {
    _confettiController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parts = selectedMessage.split('\n');
    final title = parts[0];
    final subtitle = parts[1];
    
    return IgnorePointer(
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // Confetti layer
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _confettiController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _ConfettiPainter(progress: _confettiController.value),
                  );
                },
              ).animate().fadeIn(duration: 200.ms).fadeOut(delay: 2000.ms, duration: 500.ms),
            ),
            
            // Card layer
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2F33) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 30,
                      spreadRadius: 5,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle, color: Colors.green, size: 56)
                        .animate()
                        .scale(delay: 100.ms, duration: 500.ms, curve: Curves.easeOutBack),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      title,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 15, color: Theme.of(context).textTheme.bodySmall?.color),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ).animate()
               .fadeIn(duration: 300.ms)
               .scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack, duration: 500.ms)
               .slideY(begin: 0.1, end: 0, duration: 400.ms, curve: Curves.easeOutCubic)
               .fadeOut(delay: 2200.ms, duration: 300.ms),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  _ConfettiPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(42); // Fixed seed for stable particle positions
    final paint = Paint()..style = PaintingStyle.fill;
    final colors = [
      Colors.red, Colors.blue, Colors.green, 
      Colors.yellow, Colors.purple, Colors.orange,
      Colors.pink, Colors.teal
    ];
    
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    for (int i = 0; i < 60; i++) {
      paint.color = colors[random.nextInt(colors.length)].withValues(alpha: 1.0 - (progress * 0.5));
      
      // Starting positions slightly around the center
      final angle = random.nextDouble() * 2 * pi;
      final distance = random.nextDouble() * 50;
      final startX = centerX + cos(angle) * distance;
      final startY = centerY + sin(angle) * distance;
      
      // Explosion velocities
      final vx = (random.nextDouble() - 0.5) * 600;
      final vy = (random.nextDouble() - 0.5) * 600 - 200; // slight upward bias
      
      // Gravity and current position
      final t = progress * 2; // Time factor
      final currentX = startX + vx * t;
      final currentY = startY + vy * t + (400 * t * t); // Add gravity
      
      // Shape
      final sizeRandom = random.nextDouble() * 6 + 4;
      final isCircle = random.nextBool();
      
      if (isCircle) {
        canvas.drawCircle(Offset(currentX, currentY), sizeRandom / 2, paint);
      } else {
        // Draw a rotating rectangle
        canvas.save();
        canvas.translate(currentX, currentY);
        canvas.rotate(progress * pi * 4 * (random.nextBool() ? 1 : -1)); // Rotate based on progress
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: sizeRandom, height: sizeRandom * 1.5), paint);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
