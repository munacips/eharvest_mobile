import 'package:flutter/material.dart';

class CountBadge extends StatelessWidget {
  final int count;
  final Color backgroundColor;
  final Color foregroundColor;

  const CountBadge({
    super.key,
    required this.count,
    this.backgroundColor = Colors.red,
    this.foregroundColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return const SizedBox.shrink();
    }

    final label = count > 99 ? '99+' : count.toString();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      constraints: const BoxConstraints(minWidth: 20),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: foregroundColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
