import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/home_models.dart';

/// Auto-scrolling hero banner with image backgrounds and dot indicators.
class HeroSlider extends StatefulWidget {
  const HeroSlider({
    super.key,
    required this.slides,
    this.height = 210,
    this.autoPlayInterval = const Duration(seconds: 4),
    this.onActionTap,
  });

  final List<HeroSlide> slides;
  final double height;
  final Duration autoPlayInterval;
  final void Function(String route)? onActionTap;

  @override
  State<HeroSlider> createState() => _HeroSliderState();
}

class _HeroSliderState extends State<HeroSlider> {
  late final PageController _controller;
  late Timer _timer;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _startAutoPlay();
  }

  void _startAutoPlay() {
    _timer = Timer.periodic(widget.autoPlayInterval, (_) {
      if (!mounted) return;
      final next = (_current + 1) % widget.slides.length;
      _controller.animateToPage(next,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.slides.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (_, i) => _SlideCard(
                slide: widget.slides[i], onActionTap: widget.onActionTap),
          ),
        ),
        const SizedBox(height: 12),
        _DotIndicators(count: widget.slides.length, current: _current),
      ],
    );
  }
}

// ── Single slide card with image background ────────────────────────────────────
class _SlideCard extends StatelessWidget {
  const _SlideCard({required this.slide, this.onActionTap});

  final HeroSlide slide;
  final void Function(String)? onActionTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Background image ────────────────────────────────────────────
            if (slide.imagePath != null)
              Image.asset(
                slide.imagePath!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _GradientBackground(slide: slide),
              )
            else
              _GradientBackground(slide: slide),

            // ── Dark scrim for readability ─────────────────────────────────
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.62),
                    Colors.black.withValues(alpha: 0.20),
                    Colors.black.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),

            // ── Content ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          slide.title,
                          style: GoogleFonts.playfairDisplay(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 6,
                              )
                            ],
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          slide.subtitle,
                          style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.88),
                            fontSize: 12.5,
                            height: 1.45,
                          ),
                        ),
                        if (slide.actionLabel != null) ...[
                          const SizedBox(height: 14),
                          _CTAButton(
                            label: slide.actionLabel!,
                            gradient: slide.gradient,
                            onTap: slide.actionRoute != null
                                ? () => onActionTap?.call(slide.actionRoute!)
                                : null,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Frosted icon badge
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 60,
                      height: 60,
                      color: Colors.white.withValues(alpha: 0.18),
                      child: Icon(slide.icon, color: Colors.white, size: 30),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fallback gradient background when no image is provided.
class _GradientBackground extends StatelessWidget {
  const _GradientBackground({required this.slide});

  final HeroSlide slide;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: slide.gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }
}

class _CTAButton extends StatelessWidget {
  const _CTAButton({required this.label, required this.gradient, this.onTap});

  final String label;
  final List<Color> gradient;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: gradient.isNotEmpty ? gradient.first : const Color(0xFFD4611A),
          ),
        ),
      ),
    );
  }
}

// ── Dot indicators ─────────────────────────────────────────────────────────────
class _DotIndicators extends StatelessWidget {
  const _DotIndicators({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 22 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: active ? color : color.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
