import 'package:flutter/material.dart';

class MarqueeWidget extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final double speed;
  final bool autoPlay;

  const MarqueeWidget({super.key, required this.text, this.style, this.speed = 50, this.autoPlay = true});

  @override
  State<MarqueeWidget> createState() => _MarqueeWidgetState();
}

class _MarqueeWidgetState extends State<MarqueeWidget> with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _animController;
  double _scrollWidth = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _animController = AnimationController(vsync: this, duration: Duration.zero);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startMarquee();
    });
  }

  void _startMarquee() {
    if (!widget.autoPlay || !_scrollController.hasClients) return;

    _scrollWidth = _scrollController.position.maxScrollExtent;

    if (_scrollWidth <= 0) return;

    final duration = Duration(milliseconds: (_scrollWidth / widget.speed * 1000).round());
    _animController.duration = duration;

    _animController.forward().then((_) {
      _scrollController.jumpTo(0);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _startMarquee();
      });
    });

    _animController.addListener(() {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_animController.value * _scrollWidth);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Row(
          children: [
            Text(widget.text, style: widget.style),
            const SizedBox(width: 50),
            Text(widget.text, style: widget.style),
          ],
        ),
      ),
    );
  }
}
