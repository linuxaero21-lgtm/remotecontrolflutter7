/**
 * virtual_touchpad.dart — Widget touchpad virtuale
 *
 * Rileva il tocco e lo spostamento delle dita e li traduce
 * in comandi MOUSE per il server. Supporta anche tap per click.
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VirtualTouchpad extends StatefulWidget {
  final Function(double pctX, double pctY) onMove;
  final VoidCallback onTap;
  final VoidCallback onSecondaryTap;
  final bool enabled;

  const VirtualTouchpad({
    super.key,
    required this.onMove,
    required this.onTap,
    required this.onSecondaryTap,
    this.enabled = true,
  });

  @override
  State<VirtualTouchpad> createState() => _VirtualTouchpadState();
}

class _VirtualTouchpadState extends State<VirtualTouchpad> {
  // Per debounce del movimento
  DateTime _lastMoveTime = DateTime.now();
  static const Duration _moveDebounce = Duration(milliseconds: 30);

  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.enabled
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
              : Colors.grey.withValues(alpha: 0.2),
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Listener(
          onPointerDown: (event) {
            if (!widget.enabled) return;
            _isDragging = false;
          },
          onPointerMove: (event) {
            if (!widget.enabled) return;
            _isDragging = true;

            final now = DateTime.now();
            if (now.difference(_lastMoveTime) < _moveDebounce) return;
            _lastMoveTime = now;

            final dx = event.localPosition.dx;
            final dy = event.localPosition.dy;

            // Calcola dimensione del touchpad
            final box = context.findRenderObject() as RenderBox;
            final size = box.size;
            if (size.width <= 0 || size.height <= 0) return;

            // Converti in percentuali (0-100)
            final pctX = (dx / size.width * 100).clamp(0.0, 100.0);
            final pctY = (dy / size.height * 100).clamp(0.0, 100.0);

            widget.onMove(pctX, pctY);
          },
          onPointerUp: (event) {
            if (!widget.enabled) return;

            // Se non c'è stato un drag, è un tap
            if (!_isDragging) {
              HapticFeedback.lightImpact();
              widget.onTap();
            }

            _isDragging = false;
          },
          onPointerCancel: (event) {
            _isDragging = false;
          },
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.8,
                colors: [
                  if (widget.enabled)
                    Theme.of(context).colorScheme.primary.withValues(alpha: 0.05)
                  else
                    Colors.transparent,
                  Colors.transparent,
                ],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.touch_app,
                    size: 64,
                    color: widget.enabled
                        ? Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.3)
                        : Colors.grey.withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.enabled
                        ? 'Tocca o trascina qui\nper controllare il mouse'
                        : 'Connettiti prima\ndi usare il touchpad',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: widget.enabled
                          ? Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.4)
                          : Colors.grey.withValues(alpha: 0.3),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
