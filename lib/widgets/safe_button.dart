import 'package:flutter/material.dart';

/// Texto de botón con ellipsis — evita desbordes en pantallas angostas.
class SafeButtonText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final int maxLines;

  const SafeButtonText(
    this.text, {
    super.key,
    this.style,
    this.textAlign = TextAlign.center,
    this.maxLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign,
      softWrap: true,
      style: style,
    );
  }
}

/// Fila icono + texto flexible para botones Material.
class SafeButtonContent extends StatelessWidget {
  final IconData icon;
  final String label;
  final double iconSize;
  final TextStyle? textStyle;
  final Color? iconColor;
  final int maxLines;

  const SafeButtonContent({
    super.key,
    required this.icon,
    required this.label,
    this.iconSize = 18,
    this.textStyle,
    this.iconColor,
    this.maxLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: iconSize, color: iconColor),
        const SizedBox(width: 8),
        Flexible(
          child: SafeButtonText(
            label,
            style: textStyle,
            maxLines: maxLines,
          ),
        ),
      ],
    );
  }
}

/// Contenido de botón con spinner opcional (estados de carga).
class SafeButtonLoadingContent extends StatelessWidget {
  final bool loading;
  final IconData icon;
  final String idleLabel;
  final String loadingLabel;
  final TextStyle? textStyle;
  final Color? iconColor;
  final Color? spinnerColor;
  final double iconSize;

  const SafeButtonLoadingContent({
    super.key,
    required this.loading,
    required this.icon,
    required this.idleLabel,
    required this.loadingLabel,
    this.textStyle,
    this.iconColor,
    this.spinnerColor,
    this.iconSize = 18,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: iconSize + 2,
            height: iconSize + 2,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: spinnerColor ?? iconColor ?? textStyle?.color,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: SafeButtonText(loadingLabel, style: textStyle),
          ),
        ],
      );
    }
    return SafeButtonContent(
      icon: icon,
      label: idleLabel,
      iconSize: iconSize,
      iconColor: iconColor,
      textStyle: textStyle,
    );
  }
}

/// TextButton con icono — sustituto de TextButton.icon sin desborde.
class SafeTextIconButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final ButtonStyle? style;
  final double iconSize;
  final Color? iconColor;
  final TextStyle? textStyle;
  final int maxLines;

  const SafeTextIconButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.style,
    this.iconSize = 18,
    this.iconColor,
    this.textStyle,
    this.maxLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: style,
      child: SafeButtonContent(
        icon: icon,
        label: label,
        iconSize: iconSize,
        iconColor: iconColor,
        textStyle: textStyle,
        maxLines: maxLines,
      ),
    );
  }
}

/// ElevatedButton con icono — sustituto de ElevatedButton.icon sin desborde.
class SafeElevatedIconButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final ButtonStyle? style;
  final double iconSize;
  final Color? iconColor;
  final TextStyle? textStyle;
  final int maxLines;

  const SafeElevatedIconButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.style,
    this.iconSize = 18,
    this.iconColor,
    this.textStyle,
    this.maxLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: style,
      child: SafeButtonContent(
        icon: icon,
        label: label,
        iconSize: iconSize,
        iconColor: iconColor,
        textStyle: textStyle,
        maxLines: maxLines,
      ),
    );
  }
}

/// OutlinedButton con icono — sustituto de OutlinedButton.icon sin desborde.
class SafeOutlinedIconButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final ButtonStyle? style;
  final double iconSize;
  final Color? iconColor;
  final TextStyle? textStyle;
  final int maxLines;

  const SafeOutlinedIconButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.style,
    this.iconSize = 18,
    this.iconColor,
    this.textStyle,
    this.maxLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: style,
      child: SafeButtonContent(
        icon: icon,
        label: label,
        iconSize: iconSize,
        iconColor: iconColor,
        textStyle: textStyle,
        maxLines: maxLines,
      ),
    );
  }
}

/// FilledButton con icono — sustituto de FilledButton.icon sin desborde.
class SafeFilledIconButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final ButtonStyle? style;
  final double iconSize;
  final Color? iconColor;
  final TextStyle? textStyle;
  final int maxLines;

  const SafeFilledIconButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.style,
    this.iconSize = 18,
    this.iconColor,
    this.textStyle,
    this.maxLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: style,
      child: SafeButtonContent(
        icon: icon,
        label: label,
        iconSize: iconSize,
        iconColor: iconColor,
        textStyle: textStyle,
        maxLines: maxLines,
      ),
    );
  }
}

/// OutlinedButton ancho completo con label seguro.
class SafeOutlinedButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final ButtonStyle? style;

  const SafeOutlinedButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: style,
        child: SafeButtonContent(icon: icon, label: label),
      ),
    );
  }
}

/// ElevatedButton ancho completo con label seguro.
class SafeElevatedButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final ButtonStyle? style;
  final Color? iconColor;
  final TextStyle? textStyle;

  const SafeElevatedButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.style,
    this.iconColor,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: style,
        child: SafeButtonContent(
          icon: icon,
          label: label,
          iconColor: iconColor,
          textStyle: textStyle,
        ),
      ),
    );
  }
}
