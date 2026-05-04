import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';

/// A compact number input with minus / plus buttons and a suffix label
/// for the units (e.g., "sec", "%"). Supports doubles via [isDouble].
class NumericStepper extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final double step;
  final String suffix;
  final bool isDouble;
  final ValueChanged<double> onChanged;

  const NumericStepper({
    super.key,
    required this.value,
    required this.onChanged,
    required this.suffix,
    this.min = 0,
    this.max = 100,
    this.step = 1,
    this.isDouble = false,
  });

  @override
  State<NumericStepper> createState() => _NumericStepperState();
}

class _NumericStepperState extends State<NumericStepper> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _format(widget.value));
  }

  @override
  void didUpdateWidget(covariant NumericStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    final incoming = _format(widget.value);
    if (incoming != _controller.text) {
      _controller.value = TextEditingValue(
        text: incoming,
        selection: TextSelection.collapsed(offset: incoming.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _format(double v) {
    if (widget.isDouble) {
      return v.toStringAsFixed(0);
    }
    return v.toInt().toString();
  }

  double _clamp(double v) {
    if (v < widget.min) return widget.min;
    if (v > widget.max) return widget.max;
    return v;
  }

  void _bump(double delta) {
    final next = _clamp(widget.value + delta);
    widget.onChanged(next);
  }

  void _commit(String raw) {
    final parsed = double.tryParse(raw);
    if (parsed == null) {
      _controller.text = _format(widget.value);
      return;
    }
    widget.onChanged(_clamp(parsed));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperButton(
            icon: Icons.remove,
            onTap: widget.value <= widget.min ? null : () => _bump(-widget.step),
          ),
          SizedBox(
            width: 64,
            height: 36,
            child: Center(
              child: TextField(
                controller: _controller,
                textAlign: TextAlign.center,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: false,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                onSubmitted: _commit,
                onEditingComplete: () => _commit(_controller.text),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
          Container(
            height: 36,
            alignment: Alignment.center,
            padding: const EdgeInsets.only(right: 10, left: 2),
            child: Text(
              widget.suffix,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.neutral,
              ),
            ),
          ),
          _StepperButton(
            icon: Icons.add,
            onTap: widget.value >= widget.max ? null : () => _bump(widget.step),
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _StepperButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        width: 34,
        height: 36,
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 15,
          color: enabled ? AppColors.seed : AppColors.neutral.withOpacity(0.4),
        ),
      ),
    );
  }
}
