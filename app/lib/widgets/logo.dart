import 'package:flutter/material.dart';

class PaperDropLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final TextStyle? textStyle;

  const PaperDropLogo({
    super.key,
    this.size = 48,
    this.showText = true,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [theme.colorScheme.primary, const Color(0xFF8B5CF6)],
            ),
            borderRadius: BorderRadius.circular(size * 0.2),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withOpacity(0.3),
                blurRadius: size * 0.2,
                offset: Offset(0, size * 0.05),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              Icons.description_outlined,
              size: size * 0.5,
              color: Colors.white,
            ),
          ),
        ),
        if (showText) ...[
          SizedBox(width: size * 0.25),
          Text(
            'PaperDrop',
            style:
                textStyle ??
                TextStyle(
                  fontSize: size * 0.6,
                  fontWeight: FontWeight.w700,
                  color: theme.textTheme.titleLarge?.color,
                  letterSpacing: -0.5,
                ),
          ),
        ],
      ],
    );
  }
}

class PaperDropIcon extends StatelessWidget {
  final double size;

  const PaperDropIcon({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [theme.colorScheme.primary, const Color(0xFF8B5CF6)],
        ),
        borderRadius: BorderRadius.circular(size * 0.2),
      ),
      child: Center(
        child: Icon(
          Icons.description_outlined,
          size: size * 0.5,
          color: Colors.white,
        ),
      ),
    );
  }
}
