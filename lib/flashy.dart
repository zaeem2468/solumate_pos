import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

Path _hexagon(Offset center, double radius) {
  final corners = [
    for (int i = 0; i < 6; i++)
      center + Offset(math.cos(math.pi / 3 * i - math.pi / 2), math.sin(math.pi / 3 * i - math.pi / 2)) * radius,
  ];
  // Rounds each corner so the badge looks like a machined bolt head.
  final path = Path();
  for (int i = 0; i < 6; i++) {
    final previous = corners[(i + 5) % 6];
    final corner = corners[i];
    final next = corners[(i + 1) % 6];
    final entry = Offset.lerp(corner, previous, 0.16)!;
    final exit = Offset.lerp(corner, next, 0.16)!;
    if (i == 0) {
      path.moveTo(entry.dx, entry.dy);
    } else {
      path.lineTo(entry.dx, entry.dy);
    }
    path.quadraticBezierTo(corner.dx, corner.dy, exit.dx, exit.dy);
  }
  return path..close();
}

class _LogoPainter extends CustomPainter {
  final double sweep;

  _LogoPainter(this.sweep);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final center = size.center(Offset.zero);
    final bounds = Offset.zero & size;

    final outer = _hexagon(center, s * 0.46);
    canvas.drawPath(outer, Paint()
      ..color = AppColors.orange.withValues(alpha: 0.55)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.05));
    canvas.drawPath(outer, Paint()..shader = AppGradients.gold.createShader(bounds));

    final face = _hexagon(center, s * 0.39);
    canvas.drawPath(face, Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.3, -0.5),
        radius: 1.0,
        colors: [Color(0xFFFF4B3E), Color(0xFFD81B2C), Color(0xFF6E0B2A)],
      ).createShader(bounds));

    canvas.save();
    canvas.clipPath(face);
    canvas.drawRect(Rect.fromLTWH(0, 0, s, s * 0.46), Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white.withValues(alpha: 0.32), Colors.white.withValues(alpha: 0)],
      ).createShader(Rect.fromLTWH(0, 0, s, s * 0.46)));
    canvas.restore();

    final letter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: 'S',
        style: TextStyle(
          fontFamily: 'RobotoCondensed',
          fontWeight: FontWeight.w700,
          fontSize: s * 0.56,
          height: 1,
          foreground: Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Color(0xFFFFE27A), Color(0xFFFFB000)],
            ).createShader(Rect.fromCenter(center: center, width: s * 0.5, height: s * 0.5)),
          shadows: [Shadow(color: const Color(0xAA3B0014), offset: Offset(0, s * 0.015), blurRadius: s * 0.03)],
        ),
      ),
    )..layout();
    letter.paint(canvas, center - Offset(letter.width / 2, letter.height / 2));

    if (sweep > 0 && sweep < 1) {
      canvas.save();
      canvas.clipPath(outer);
      final x = -s * 0.6 + sweep * s * 2.2;
      canvas.translate(x, 0);
      canvas.skew(-0.45, 0);
      canvas.drawRect(Rect.fromLTWH(0, -s, s * 0.22, s * 3), Paint()
        ..shader = LinearGradient(colors: [Colors.white.withValues(alpha: 0), Colors.white.withValues(alpha: 0.75), Colors.white.withValues(alpha: 0)])
            .createShader(Rect.fromLTWH(0, 0, s * 0.22, s)));
      canvas.restore();
    }

    final twinkle = sweep <= 0 || sweep >= 1 ? 1.0 : 1.0 + math.sin(sweep * math.pi) * 0.7;
    _drawSpark(canvas, center + Offset(s * 0.29, -s * 0.31), s * 0.1 * twinkle);
  }

  void _drawSpark(Canvas canvas, Offset at, double r) {
    final inner = r * 0.16;
    final path = Path();
    for (int i = 0; i < 8; i++) {
      final radius = i.isEven ? r : inner;
      final angle = math.pi / 4 * i - math.pi / 2;
      final point = at + Offset(math.cos(angle), math.sin(angle)) * radius;
      i == 0 ? path.moveTo(point.dx, point.dy) : path.lineTo(point.dx, point.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()
      ..color = AppColors.gold
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.3));
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_LogoPainter oldDelegate) => oldDelegate.sweep != sweep;
}

/// The Solumate bolt-head badge. A band of light crosses it when it appears
/// and again when the pointer moves over it.
class SolumateLogo extends StatefulWidget {
  final double size;
  final bool animate;

  const SolumateLogo({super.key, required this.size, this.animate = true});

  @override
  State<SolumateLogo> createState() => _SolumateLogoState();
}

class _SolumateLogoState extends State<SolumateLogo> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  bool _played = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_played && widget.animate && !MediaQuery.disableAnimationsOf(context)) {
      _played = true;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        if (widget.animate && !_controller.isAnimating && !MediaQuery.disableAnimationsOf(context)) _controller.forward(from: 0);
      },
      child: Semantics(
        label: 'Solumate logo',
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(size: Size.square(widget.size), painter: _LogoPainter(_controller.value)),
        ),
      ),
    );
  }
}

/// Text filled with the gold gradient.
class GoldText extends StatelessWidget {
  final String text;
  final TextStyle style;

  const GoldText(this.text, {super.key, required this.style});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => AppGradients.goldText.createShader(bounds),
      child: Text(text, maxLines: 1, softWrap: false, style: style.copyWith(color: Colors.white)),
    );
  }
}

/// Rays that fan out behind the logo on the splash screen.
class SunburstPainter extends CustomPainter {
  final double progress;

  SunburstPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero).translate(0, -60);
    final radius = size.longestSide;
    canvas.drawRect(Offset.zero & size, Paint()
      ..shader = RadialGradient(
        colors: const [Color(0xFF8C1233), Color(0xFF3A1238), AppColors.navyDeep],
        stops: const [0, 0.45, 1],
        radius: 0.9,
        center: Alignment(0, -60 / (size.height / 2)),
      ).createShader(Offset.zero & size));

    const rays = 16;
    final ray = Paint()
      ..shader = RadialGradient(colors: [AppColors.gold.withValues(alpha: 0.26), AppColors.gold.withValues(alpha: 0)])
          .createShader(Rect.fromCircle(center: center, radius: radius * 0.75));
    final spin = progress * math.pi / 5;
    final reach = radius * Curves.easeOutCubic.transform(progress.clamp(0.0, 1.0));
    for (int i = 0; i < rays; i++) {
      final a = math.pi * 2 / rays * i + spin;
      final b = a + math.pi / rays;
      canvas.drawPath(
        Path()
          ..moveTo(center.dx, center.dy)
          ..lineTo(center.dx + math.cos(a) * reach, center.dy + math.sin(a) * reach)
          ..lineTo(center.dx + math.cos(b) * reach, center.dy + math.sin(b) * reach)
          ..close(),
        ray,
      );
    }
  }

  @override
  bool shouldRepaint(SunburstPainter oldDelegate) => oldDelegate.progress != progress;
}

/// A tappable surface that lifts and glows under the pointer and presses in
/// when tapped.
class GlowTile extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final Color glow;
  final bool selected;

  const GlowTile({super.key, required this.child, required this.onTap, required this.glow, this.selected = false});

  @override
  State<GlowTile> createState() => _GlowTileState();
}

class _GlowTileState extends State<GlowTile> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    final duration = still ? Duration.zero : const Duration(milliseconds: 130);
    final lit = _hover || widget.selected;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedScale(
        duration: duration,
        scale: still ? 1 : (_pressed ? 0.96 : (_hover ? 1.03 : 1)),
        child: AnimatedContainer(
          duration: duration,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(color: lit ? widget.glow.withValues(alpha: 0.55) : const Color(0x1A0A1A30), blurRadius: lit ? 18 : 6, offset: Offset(0, lit ? 6 : 2)),
            ],
          ),
          child: Material(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: widget.selected ? AppColors.yellow : Colors.transparent, width: 2.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onTap,
              onHighlightChanged: (down) => setState(() => _pressed = down),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// The main call-to-action button, filled with the hot gradient.
class FlashButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final double height;

  const FlashButton({super.key, required this.label, required this.onPressed, this.height = 56});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: enabled ? AppGradients.hot : null,
        color: enabled ? null : AppColors.line,
        borderRadius: BorderRadius.circular(10),
        boxShadow: enabled ? [BoxShadow(color: AppColors.orange.withValues(alpha: 0.5), blurRadius: 16, offset: const Offset(0, 6))] : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Center(child: Text(label, style: AppText.display(24, color: enabled ? Colors.white : AppColors.muted))),
        ),
      ),
    );
  }
}
