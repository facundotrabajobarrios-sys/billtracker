import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';

// 🎉 Widget de celebración con confeti
class Celebration extends StatefulWidget {
  final Widget child;
  final bool trigger;
  final VoidCallback? onComplete;

  const Celebration({
    super.key,
    required this.child,
    required this.trigger,
    this.onComplete,
  });

  @override
  State<Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends State<Celebration>
    with SingleTickerProviderStateMixin {
  late final ConfettiController _controller;
  bool _wasTriggered = false;

  @override
  void initState() {
    super.initState();
    _controller = ConfettiController(duration: const Duration(seconds: 3));
    _controller.addListener(_handleControllerStateChanged);
  }

  void _handleControllerStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(Celebration oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger && !_wasTriggered) {
      _wasTriggered = true;
      _controller.play();
      Future.delayed(const Duration(seconds: 3), () {
        if (widget.onComplete != null) {
          widget.onComplete!();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerStateChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: ConfettiWidget(
              confettiController: _controller,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                Colors.red,
                Colors.green,
                Colors.blue,
                Colors.yellow,
                Colors.purple,
                Colors.orange,
                Colors.pink,
              ],
              numberOfParticles: 100,
              maxBlastForce: 50,
              minBlastForce: 20,
              emissionFrequency: 0.05,
              gravity: 0.1,
              particleDrag: 0.05,
            ),
          ),
        ),
      ],
    );
  }
}
