import 'package:flutter/material.dart';

/// Palet warna & sistem desain Duolingo versi Biru Gelap Hitam (Midnight Electric Blue).
class DuoColors {
  // Latar belakang
  static const Color background = Color(0xFF0B0F19); // Hitam pekat kebiruan (deep void)
  static const Color backgroundAlt = Color(0xFF0E1424); // Sedikit lebih terang untuk layer tertentu

  // Permukaan / Kartu Konten
  static const Color surface = Color(0xFF151E30); // Midnight navy untuk card/box
  static const Color surfaceElevated = Color(0xFF1B263D); // Elevasi kedua
  static const Color surfaceBorder = Color(0xFF263550); // Garis tepi tegas khas kartu Duolingo
  static const Color surfaceShadow = Color(0xFF090D15); // Bayangan 3D bawah kartu

  // Aksi Utama — Biru Elektrik Duolingo (Electric Azure)
  static const Color primaryBlue = Color(0xFF1CB0F6);
  static const Color primaryBlueShadow = Color(0xFF147EB0);

  // Tombol Sekunder / Abu-Biru Gelap
  static const Color secondaryButton = Color(0xFF222F47);
  static const Color secondaryButtonBorder = Color(0xFF334566);
  static const Color secondaryButtonShadow = Color(0xFF151E30);

  // Aksen Gamifikasi Duolingo
  static const Color streakGold = Color(0xFFFFC800); // Koin / Wallet / XP
  static const Color streakGoldShadow = Color(0xFFD99B00);

  static const Color heartRed = Color(0xFFFF4B4B); // Batal / Logout / Kesalahan
  static const Color heartRedShadow = Color(0xFFD93636);

  static const Color questGreen = Color(0xFF58CC02); // Sukses / Selesai / Biometrik Aktif
  static const Color questGreenShadow = Color(0xFF46A302);

  static const Color neonCyan = Color(0xFF00E5FF); // Highlight / Anti-cheat verified
  static const Color neonCyanShadow = Color(0xFF00B0C7);

  // Tipografi
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
}

/// Tombol 3D tebal ("Chunky Button") khas Duolingo dengan animasi tekan (push-down).
class DuoButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color shadowColor;
  final Color textColor;
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
    this.backgroundColor = DuoColors.primaryBlue,
    this.shadowColor = DuoColors.primaryBlueShadow,
    this.textColor = Colors.white,
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
    final bool isEnabled = widget.onPressed != null && !widget.isLoading;
    final double shadowHeight = isEnabled ? widget.shadowHeight : 2.0;
    final Color bg = isEnabled ? widget.backgroundColor : const Color(0xFF1F2B3E);
    final Color shadow = isEnabled ? widget.shadowColor : const Color(0xFF131C2A);
    final Color textCol = isEnabled ? widget.textColor : const Color(0xFF64748B);

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

/// Kartu Konten Berbingkai 3D khas Duolingo.
class DuoCard extends StatelessWidget {
  final Widget child;
  final Color backgroundColor;
  final Color borderColor;
  final Color shadowColor;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double shadowOffset;
  final VoidCallback? onTap;

  const DuoCard({
    super.key,
    required this.child,
    this.backgroundColor = DuoColors.surface,
    this.borderColor = DuoColors.surfaceBorder,
    this.shadowColor = DuoColors.surfaceShadow,
    this.padding = const EdgeInsets.all(16.0),
    this.borderRadius = 18.0,
    this.shadowOffset = 4.0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor, width: 2.0),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
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

/// Chip Gamifikasi Kapsul khas Duolingo (Streak, Wallet, Level).
class DuoChip extends StatelessWidget {
  final Widget icon;
  final String label;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final VoidCallback? onTap;

  const DuoChip({
    super.key,
    required this.icon,
    required this.label,
    this.backgroundColor = DuoColors.surface,
    this.borderColor = DuoColors.surfaceBorder,
    this.textColor = DuoColors.textPrimary,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF090D15),
            offset: Offset(0, 2),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
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
