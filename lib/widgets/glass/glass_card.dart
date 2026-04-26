import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';

enum GlassWeight { thin, mid, thick }

class GlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final GlassWeight weight;
  final Color? tint;
  final Color? rimColor;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = 28,
    this.weight = GlassWeight.mid,
    this.tint,
    this.rimColor,
    this.padding,
    this.width,
    this.height,
    this.onTap,
    this.onLongPress,
  });

  double get _opacity => switch (weight) {
    GlassWeight.thin  => 0.06,
    GlassWeight.mid   => 0.08,
    GlassWeight.thick => 0.11,
  };

  double get _blur => switch (weight) {
    GlassWeight.thin  => 20,
    GlassWeight.mid   => 36,
    GlassWeight.thick => 56,
  };

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: _blur,
            sigmaY: _blur,
          ),
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: radius,
              color: Colors.white.withOpacity(_opacity),
              border: Border.all(
                color: AppColors.glassBorder,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.45),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Tint overlay
                if (tint != null)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: radius,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [tint!, Colors.transparent],
                        ),
                      ),
                    ),
                  ),

                // Top specular sheen
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: Container(
                    height: height != null ? height! * 0.5 : 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(borderRadius),
                        topRight: Radius.circular(borderRadius),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.14),
                          Colors.white.withOpacity(0.05),
                          Colors.transparent,
                        ],
                        stops: const [0, 0.3, 0.6],
                      ),
                    ),
                  ),
                ),

                // Top rim (refraction line)
                Positioned(
                  top: 0,
                  left: borderRadius * 0.3,
                  right: borderRadius * 0.3,
                  child: Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          rimColor ?? Colors.white.withOpacity(0.28),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // Content
                if (padding != null)
                  Padding(padding: padding!, child: child)
                else
                  child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Glowing status dot
class StatusDot extends StatefulWidget {
  final bool online;
  final double size;

  const StatusDot({super.key, required this.online, this.size = 7});

  @override
  State<StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<StatusDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 1.0, end: 0.4).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final color = widget.online ? AppColors.online : AppColors.offline;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(widget.online ? _anim.value : 1),
          boxShadow: widget.online ? [
            BoxShadow(color: color.withOpacity(0.6), blurRadius: 8),
            BoxShadow(color: color.withOpacity(0.3), blurRadius: 20),
          ] : null,
        ),
      ),
    );
  }
}

// Liquid glass pill button
class GlassPill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color? activeColor;

  const GlassPill({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = activeColor ?? AppColors.violet;
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        borderRadius: 20,
        weight: active ? GlassWeight.thick : GlassWeight.thin,
        rimColor: active ? color.withOpacity(0.5) : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w700 : FontWeight.w400,
            color: active ? Colors.white : Colors.white54,
          ),
        ),
      ),
    );
  }
}

// Progress bar with shimmer
class GlassProgressBar extends StatelessWidget {
  final double value; // 0.0 - 1.0
  final Color color;
  final double height;

  const GlassProgressBar({
    super.key,
    required this.value,
    required this.color,
    this.height = 3,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(height),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: value.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(height),
            gradient: LinearGradient(
              colors: [color.withOpacity(0.6), color],
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.6),
                blurRadius: 8,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
