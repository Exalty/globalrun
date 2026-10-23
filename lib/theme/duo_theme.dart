import 'package:flutter/material.dart';

/// Struktur palet warna untuk tema dinamis (Light Mode & Dark Mode).
class DuoColorPalette {
  final bool isDark;
  final Color background;
  final Color backgroundAlt;
  final Color surface;
  final Color surfaceElevated;
  final Color surfaceBorder;
  final Color surfaceShadow;
  final Color primaryBlue;
  final Color primaryBlueShadow;
  final Color secondaryButton;
  final Color secondaryButtonBorder;
  final Color secondaryButtonShadow;
  final Color secondaryButtonText;
  final Color streakGold;
  final Color streakGoldShadow;
  final Color heartRed;
  final Color heartRedShadow;
  final Color questGreen;
  final Color questGreenShadow;
  final Color neonCyan;
  final Color neonCyanShadow;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color inputFill;

  const DuoColorPalette({
    required this.isDark,
    required this.background,
    required this.backgroundAlt,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceBorder,
    required this.surfaceShadow,
    required this.primaryBlue,
    required this.primaryBlueShadow,
    required this.secondaryButton,
    required this.secondaryButtonBorder,
    required this.secondaryButtonShadow,
    required this.secondaryButtonText,
    required this.streakGold,
    required this.streakGoldShadow,
    required this.heartRed,
    required this.heartRedShadow,
    required this.questGreen,
    required this.questGreenShadow,
    required this.neonCyan,
    required this.neonCyanShadow,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.inputFill,
  });
}

/// Token warna & sistem desain Duolingo.
class DuoColors {
  // ─── PALET MODE GELAP (Midnight Electric Blue) ───
  static const DuoColorPalette darkPalette = DuoColorPalette(
    isDark: true,
    background: Color(0xFF0B0F19), // Hitam pekat kebiruan (deep void)
    backgroundAlt: Color(0xFF0E1424),
    surface: Color(0xFF151E30), // Midnight navy untuk kartu
    surfaceElevated: Color(0xFF1B263D),
    surfaceBorder: Color(0xFF263550), // Garis tepi tegas khas kartu Duolingo
    surfaceShadow: Color(0xFF090D15), // Bayangan 3D bawah kartu
    primaryBlue: Color(0xFF1CB0F6), // Biru elektrik cerah
    primaryBlueShadow: Color(0xFF147EB0),
    secondaryButton: Color(0xFF222F47),
    secondaryButtonBorder: Color(0xFF334566),
    secondaryButtonShadow: Color(0xFF151E30),
    secondaryButtonText: Colors.white,
    streakGold: Color(0xFFFFC800),
    streakGoldShadow: Color(0xFFD99B00),
    heartRed: Color(0xFFFF4B4B),
    heartRedShadow: Color(0xFFD93636),
    questGreen: Color(0xFF58CC02),
    questGreenShadow: Color(0xFF46A302),
    neonCyan: Color(0xFF00E5FF),
    neonCyanShadow: Color(0xFF00B0C7),
    textPrimary: Colors.white,
    textSecondary: Color(0xFF94A3B8),
    textMuted: Color(0xFF64748B),
    inputFill: Color(0xFF0B0F19),
  );

  // ─── PALET MODE TERANG (Duolingo Light Electric) ───
  static const DuoColorPalette lightPalette = DuoColorPalette(
    isDark: false,
    background: Color(0xFFF8FAFC), // Putih soft / cloud slate
    backgroundAlt: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF), // Kartu putih bersih
    surfaceElevated: Color(0xFFF1F5F9),
    surfaceBorder: Color(0xFFE2E8F0), // Border abu-abu tegas 2px
    surfaceShadow: Color(0xFFCBD5E1), // Bayangan bawah 3D abu-abu slate
    primaryBlue: Color(0xFF1CB0F6), // Tetap biru elektrik khas Duolingo
    primaryBlueShadow: Color(0xFF147EB0),
    secondaryButton: Color(0xFFF1F5F9),
    secondaryButtonBorder: Color(0xFFE2E8F0),
    secondaryButtonShadow: Color(0xFFCBD5E1),
    secondaryButtonText: Color(0xFF1E293B),
    streakGold: Color(0xFFFFB800),
    streakGoldShadow: Color(0xFFD99B00),
    heartRed: Color(0xFFFF4B4B),
    heartRedShadow: Color(0xFFD93636),
    questGreen: Color(0xFF58CC02),
    questGreenShadow: Color(0xFF46A302),
    neonCyan: Color(0xFF0284C7),
    neonCyanShadow: Color(0xFF0369A1),
    textPrimary: Color(0xFF0F172A), // Teks hitam/slate pekat kontras tinggi
    textSecondary: Color(0xFF475569),
    textMuted: Color(0xFF94A3B8),
    inputFill: Color(0xFFF1F5F9),
  );

  /// Helper untuk mengambil palet aktif sesuai konteks tema saat ini (Light / Dark).
  static DuoColorPalette of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? darkPalette : lightPalette;
  }

  // Kompatibilitas konstanta statis
  static const Color background = Color(0xFF0B0F19);
  static const Color backgroundAlt = Color(0xFF0E1424);
  static const Color surface = Color(0xFF151E30);
  static const Color surfaceElevated = Color(0xFF1B263D);
  static const Color surfaceBorder = Color(0xFF263550);
  static const Color surfaceShadow = Color(0xFF090D15);
  static const Color primaryBlue = Color(0xFF1CB0F6);
  static const Color primaryBlueShadow = Color(0xFF147EB0);
  static const Color secondaryButton = Color(0xFF222F47);
  static const Color secondaryButtonBorder = Color(0xFF334566);
  static const Color secondaryButtonShadow = Color(0xFF151E30);
  static const Color streakGold = Color(0xFFFFC800);
  static const Color streakGoldShadow = Color(0xFFD99B00);
  static const Color heartRed = Color(0xFFFF4B4B);
  static const Color heartRedShadow = Color(0xFFD93636);
  static const Color questGreen = Color(0xFF58CC02);
  static const Color questGreenShadow = Color(0xFF46A302);
  static const Color neonCyan = Color(0xFF00E5FF);
  static const Color neonCyanShadow = Color(0xFF00B0C7);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
}

/// Definisi ThemeData Flutter untuk Light Mode dan Dark Mode.
class DuoThemeData {
  static ThemeData get lightTheme {
    const palette = DuoColors.lightPalette;
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: palette.background,
      colorScheme: const ColorScheme.light(
        primary: DuoColors.primaryBlue,
        secondary: DuoColors.streakGold,
        surface: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Color(0xFF0F172A)),
        titleTextStyle: TextStyle(
          color: Color(0xFF0F172A),
          fontWeight: FontWeight.w900,
          fontSize: 18,
          letterSpacing: 1.2,
        ),
      ),
      dividerColor: palette.surfaceBorder,
      fontFamily: 'Roboto',
    );
  }

  static ThemeData get darkTheme {
    const palette = DuoColors.darkPalette;
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: palette.background,
      colorScheme: const ColorScheme.dark(
        primary: DuoColors.primaryBlue,
        secondary: DuoColors.streakGold,
        surface: DuoColors.surface,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: DuoColors.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 18,
          letterSpacing: 1.2,
        ),
      ),
      dividerColor: palette.surfaceBorder,
      fontFamily: 'Roboto',
    );
  }
}

/// Tombol 3D tebal ("Chunky Button") khas Duolingo dengan animasi tekan (push-down).
class DuoButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? shadowColor;
  final Color? textColor;
  final Widget? icon;
  final double height;
  final double? width;
  final double borderRadius;
  final double shadowHeight;
  final bool isLoading;

  const DuoButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.backgroundColor,
    this.shadowColor,
    this.textColor,
    this.icon,
    this.height = 52.0,
    this.width,
    this.borderRadius = 16.0,
    this.shadowHeight = 4.0,
    this.isLoading = false,
  });

  @override
  State<DuoButton> createState() => _DuoButtonState();
}

class _DuoButtonState extends State<DuoButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final palette = DuoColors.of(context);
    final bool isEnabled = widget.onPressed != null && !widget.isLoading;
    final double shadowHeight = isEnabled ? widget.shadowHeight : 2.0;

    final Color defaultBg = palette.primaryBlue;
    final Color defaultShadow = palette.primaryBlueShadow;
    final Color defaultText = Colors.white;

    final Color bg = isEnabled
        ? (widget.backgroundColor ?? defaultBg)
        : (palette.isDark ? const Color(0xFF1F2B3E) : const Color(0xFFE2E8F0));
    final Color shadow = isEnabled
        ? (widget.shadowColor ?? defaultShadow)
        : (palette.isDark ? const Color(0xFF131C2A) : const Color(0xFFCBD5E1));
    final Color textCol = isEnabled
        ? (widget.textColor ?? defaultText)
        : palette.textMuted;

    return GestureDetector(
      onTapDown: isEnabled ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: isEnabled
          ? (_) {
              setState(() => _isPressed = false);
              widget.onPressed?.call();
            }
          : null,
      onTapCancel: isEnabled ? () => setState(() => _isPressed = false) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 70),
        width: widget.width,
        height: widget.height,
        padding: EdgeInsets.only(top: _isPressed ? shadowHeight : 0),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: _isPressed
                ? []
                : [
                    BoxShadow(
                      color: shadow,
                      offset: Offset(0, shadowHeight),
                      blurRadius: 0,
                    ),
                  ],
          ),
          child: Center(
            child: widget.isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(textCol),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.icon != null) ...[
                        widget.icon!,
                        const SizedBox(width: 8),
                      ],
                      Text(
                        widget.text.toUpperCase(),
                        style: TextStyle(
                          color: textCol,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Kartu Konten Berbingkai 3D khas Duolingo yang otomatis menyesuaikan tema.
class DuoCard extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? shadowColor;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double shadowOffset;
  final VoidCallback? onTap;

  const DuoCard({
    super.key,
    required this.child,
    this.backgroundColor,
    this.borderColor,
    this.shadowColor,
    this.padding = const EdgeInsets.all(16.0),
    this.borderRadius = 18.0,
    this.shadowOffset = 4.0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = DuoColors.of(context);
    final bg = backgroundColor ?? palette.surface;
    final border = borderColor ?? palette.surfaceBorder;
    final shadow = shadowColor ?? palette.surfaceShadow;

    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: border, width: 2.0),
        boxShadow: [
          BoxShadow(
            color: shadow,
            offset: Offset(0, shadowOffset),
            blurRadius: 0,
          ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: content,
      );
    }
    return content;
  }
}

/// Chip Gamifikasi Kapsul khas Duolingo yang otomatis menyesuaikan tema.
class DuoChip extends StatelessWidget {
  final Widget? icon;
  final String label;
  final Widget? trailing;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? textColor;
  final VoidCallback? onTap;

  const DuoChip({
    super.key,
    this.icon,
    required this.label,
    this.trailing,
    this.backgroundColor,
    this.borderColor,
    this.textColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = DuoColors.of(context);
    final bg = backgroundColor ?? palette.surface;
    final border = borderColor ?? palette.surfaceBorder;
    final text = textColor ?? palette.textPrimary;
    final shadow = palette.surfaceShadow;

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: shadow,
            offset: const Offset(0, 2),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            icon!,
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: text,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 6),
            trailing!,
          ],
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: chip,
      );
    }
    return chip;
  }
}
