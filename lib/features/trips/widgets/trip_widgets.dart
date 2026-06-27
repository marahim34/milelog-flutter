import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Shared visual primitives for the Trip Details / Edit Trip / Ended Trip
/// screens — split out because all three compose the same design-system
/// pieces (decoded from design_handoff_milelog/prototype's bundled HTML
/// exports, not the stale flows.jsx copy in this repo).

class StatusChip extends StatelessWidget {
  const StatusChip({required this.label, required this.color, this.icon, super.key});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space8,
        vertical: AppTheme.space4,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: AppTheme.space4),
          ],
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  letterSpacing: 1.0,
                ),
          ),
        ],
      ),
    );
  }
}

/// One box of the Distance/Duration/Avg-speed recap grid.
class StatBox extends StatelessWidget {
  const StatBox({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space10,
        vertical: AppTheme.space10,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceInset,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppTheme.space4),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: colors.textDimmer, letterSpacing: 0.6),
          ),
        ],
      ),
    );
  }
}

class ValidationMessage extends StatelessWidget {
  const ValidationMessage({required this.message, required this.isDanger, super.key});

  final String message;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final color = isDanger ? colors.danger : colors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space10,
        vertical: AppTheme.space10,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 15, color: color),
          const SizedBox(width: AppTheme.space8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: colors.textPrimary, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

class SegmentButton extends StatelessWidget {
  const SegmentButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.space10),
        decoration: BoxDecoration(
          color: selected ? colors.accentTint : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: selected ? colors.accent : colors.textDim),
            const SizedBox(width: AppTheme.space8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: selected ? colors.accent : colors.textDim,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class OdoField extends StatelessWidget {
  const OdoField({
    required this.label,
    required this.controller,
    required this.onChanged,
    this.error = false,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final color = error ? colors.danger : colors.textDimmer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
        ),
        const SizedBox(height: AppTheme.space4),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: error ? TextStyle(color: colors.danger) : null,
          decoration: InputDecoration(
            suffixText: 'km',
            enabledBorder: error
                ? OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
                    borderSide: BorderSide(color: colors.danger),
                  )
                : null,
            focusedBorder: error
                ? OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
                    borderSide: BorderSide(color: colors.danger, width: 2),
                  )
                : null,
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// A single row in the read-only "Classification" card on Trip Details
/// (Type / Odometer / Company).
class DetailRow extends StatelessWidget {
  const DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.accent = false,
    this.showDivider = true,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool accent;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space16,
        vertical: AppTheme.space14,
      ),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(bottom: BorderSide(color: colors.border))
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: colors.accentTint,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 18, color: colors.accent),
          ),
          const SizedBox(width: AppTheme.space10),
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: colors.textDimmer, letterSpacing: 0.8),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: accent ? colors.accent : colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
