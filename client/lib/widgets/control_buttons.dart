/**
 * control_buttons.dart — Pulsanti di controllo (click, tastiera, scroll)
 */

import 'package:flutter/material.dart';

class ControlButtons extends StatelessWidget {
  final VoidCallback onLeftClick;
  final VoidCallback onRightClick;
  final VoidCallback onDoubleClick;
  final VoidCallback onOpenKeyboard;
  final bool enabled;

  const ControlButtons({
    super.key,
    required this.onLeftClick,
    required this.onRightClick,
    required this.onDoubleClick,
    required this.onOpenKeyboard,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Click sinistro
        Expanded(
          child: _ActionButton(
            icon: Icons.touch_app,
            label: 'Click Sin.',
            color: Colors.green,
            onPressed: enabled ? onLeftClick : null,
          ),
        ),
        const SizedBox(width: 8),

        // Click destro
        Expanded(
          child: _ActionButton(
            icon: Icons.touch_app_outlined,
            label: 'Click Des.',
            color: Colors.red,
            onPressed: enabled ? onRightClick : null,
          ),
        ),
        const SizedBox(width: 8),

        // Doppio click
        Expanded(
          child: _ActionButton(
            icon: Icons.double_arrow,
            label: 'Doppio',
            color: Colors.orange,
            onPressed: enabled ? onDoubleClick : null,
          ),
        ),
        const SizedBox(width: 8),

        // Tastiera
        Expanded(
          child: _ActionButton(
            icon: Icons.keyboard,
            label: 'Tastiera',
            color: Colors.blue,
            onPressed: enabled ? onOpenKeyboard : null,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          decoration: BoxDecoration(
            color: onPressed != null
                ? color.withValues(alpha: isDark ? 0.15 : 0.1)
                : Colors.grey.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: onPressed != null
                  ? color.withValues(alpha: 0.3)
                  : Colors.grey.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 26,
                color: onPressed != null
                    ? color
                    : Colors.grey.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: onPressed != null
                      ? (isDark ? Colors.white70 : Colors.black87)
                      : Colors.grey.withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
