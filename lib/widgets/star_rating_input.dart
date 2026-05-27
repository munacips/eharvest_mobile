import 'package:flutter/material.dart';

class StarRatingInput extends StatelessWidget {
  final int rating;
  final ValueChanged<int> onChanged;
  final bool enabled;
  final double size;

  const StarRatingInput({
    super.key,
    required this.rating,
    required this.onChanged,
    this.enabled = true,
    this.size = 30,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: List.generate(5, (index) {
        final starValue = index + 1;
        final selected = starValue <= rating;
        return InkResponse(
          onTap: enabled ? () => onChanged(starValue) : null,
          radius: size,
          child: Icon(
            selected ? Icons.star : Icons.star_border,
            color: selected ? Colors.amber.shade700 : Colors.grey.shade400,
            size: size,
          ),
        );
      }),
    );
  }
}
