import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';

/// One performance pad. The entire surface is the touch target:
/// * tap      -> trigger / fade-stop
/// * long press -> open pad settings
class PadWidget extends StatefulWidget {
  const PadWidget({
    super.key,
    required this.pad,
    required this.active,
    required this.soloed,
    required this.dimmedBySolo,
    required this.onTap,
    required this.onLongPress,
  });

  final PadConfig pad;
  final bool active;
  final bool soloed;
  final bool dimmedBySolo;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  State<PadWidget> createState() => _PadWidgetState();
}

class _PadWidgetState extends State<PadWidget>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
    lowerBound: 0.55,
    upperBound: 1.0,
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant PadWidget old) {
    super.didUpdateWidget(old);
    if (widget.active && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.active && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 1.0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pad = widget.pad;
    final color = pad.color;
    final assigned = pad.isAssigned;
    final active = widget.active;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final glow = active ? _pulse.value : 0.0;
          return AnimatedScale(
            scale: _pressed ? 0.965 : 1.0,
            duration: const Duration(milliseconds: 70),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: widget.dimmedBySolo ? 0.35 : 1.0,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: active
                        ? [
                            Color.lerp(StageColors.surfaceRaised,
                                color, 0.28)!,
                            Color.lerp(StageColors.surface, color, 0.10)!,
                          ]
                        : [
                            StageColors.surfaceRaised,
                            StageColors.surface,
                          ],
                  ),
                  border: Border.all(
                    width: active ? 2.0 : 1.2,
                    color: active
                        ? color.withOpacity(0.55 + 0.45 * glow)
                        : assigned
                            ? color.withOpacity(0.35)
                            : StageColors.stroke,
                  ),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: color.withOpacity(0.40 * glow),
                            blurRadius: 26,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Stack(
                  children: [
                    // Top edge accent strip — readable from a distance.
                    Positioned(
                      top: 10,
                      left: 14,
                      right: 14,
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          color: assigned
                              ? color.withOpacity(active ? 0.95 : 0.45)
                              : StageColors.stroke,
                        ),
                      ),
                    ),
                    // Solo badge.
                    if (widget.soloed)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: StageColors.warn,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text(
                            'SOLO',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ),
                    // Name + status.
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              pad.displayName.toUpperCase(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .displayMedium!
                                  .copyWith(
                                    fontSize: 22,
                                    color: assigned
                                        ? StageColors.textPrimary
                                        : StageColors.textSecondary
                                            .withOpacity(0.5),
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              !assigned
                                  ? 'HOLD TO ASSIGN'
                                  : active
                                      ? (pad.loop ? 'PLAYING · LOOP' : 'PLAYING')
                                      : (pad.loop ? 'LOOP' : 'ONE-SHOT'),
                              style: TextStyle(
                                fontSize: 10.5,
                                letterSpacing: 1.6,
                                fontWeight: FontWeight.w600,
                                color: active
                                    ? color
                                    : StageColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
