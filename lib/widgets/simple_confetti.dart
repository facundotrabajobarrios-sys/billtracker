import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';

class SimpleConfetti extends StatefulWidget {
  final bool trigger;
  final Widget child;

  const SimpleConfetti({super.key, required this.trigger, required this.child});

  @override
  State<SimpleConfetti> createState() => _SimpleConfettiState();
}

class _SimpleConfettiState extends State<SimpleConfetti> {
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
  void didUpdateWidget(SimpleConfetti oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.trigger && !_wasTriggered) {
      _wasTriggered = true;
      _controller.play();
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() => _wasTriggered = false);
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
              numberOfParticles: 80,
              maxBlastForce: 40,
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
