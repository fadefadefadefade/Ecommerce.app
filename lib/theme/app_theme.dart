import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// The website's design tokens (components/layout, courier.css, sc layout): navy header and text, ALVY orange for
/// actions, a light grey page, white cards with a hairline border, Inter for text and Nunito for headings.
class Alvy {
  static const navy = Color(0xFF002B4D);
  static const navyLight = Color(0xFF13315C);
  static const orange = Color(0xFFFA4E1C);
  static const orangeDark = Color(0xFFD93D0E);
  static const orangeLight = Color(0xFFFF7A45);
  static const orangeSoft = Color(0xFFFFF1EE);
  static const page = Color(0xFFF5F5F5);
  static const surface = Colors.white;
  static const subtle = Color(0xFFF4F7FA);
  static const border = Color(0xFFE6EDF2);
  static const input = Color(0xFFE0E0E0);
  static const text = navy;
  static const textSub = Color(0xFF4A7A94);
  static const textMuted = Color(0xFF6B90AA);
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFB45309);
  static const danger = Color(0xFFDC2626);

  /// The website's orange gradient (hero banners, highlights).
  static const gradient = LinearGradient(colors: [orange, orangeLight], begin: Alignment.topLeft, end: Alignment.bottomRight);

  /// The website's card shadow.
  static const cardShadow = [BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1))];
  static const liftShadow = [BoxShadow(color: Color(0x14000000), blurRadius: 20, offset: Offset(0, 6))];
  static const buttonShadow = [BoxShadow(color: Color(0x47FA4E1C), blurRadius: 8, offset: Offset(0, 2))];

  static TextStyle display({double size = 20, Color color = navy, FontWeight weight = FontWeight.w800}) =>
      GoogleFonts.nunito(fontSize: size, fontWeight: weight, color: color, height: 1.2);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final dark = b == Brightness.dark;
    final bg = dark ? const Color(0xFF0E1621) : page;
    final card = dark ? const Color(0xFF16212E) : surface;
    final line = dark ? const Color(0xFF26354A) : border;
    final ink = dark ? const Color(0xFFE8EEF4) : text;
    final sub = dark ? const Color(0xFFB5C6D6) : textSub;
    final muted = dark ? const Color(0xFF8AA3B8) : textMuted;

    final base = ThemeData(useMaterial3: true, brightness: b);
    final body = GoogleFonts.interTextTheme(base.textTheme).apply(bodyColor: ink, displayColor: ink);
    final head = GoogleFonts.nunitoTextTheme(base.textTheme).apply(bodyColor: ink, displayColor: ink);
    final textTheme = body.copyWith(
      displayLarge: head.displayLarge?.copyWith(fontWeight: FontWeight.w800),
      displayMedium: head.displayMedium?.copyWith(fontWeight: FontWeight.w800),
      displaySmall: head.displaySmall?.copyWith(fontWeight: FontWeight.w800),
      headlineLarge: head.headlineLarge?.copyWith(fontWeight: FontWeight.w800),
      headlineMedium: head.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
      headlineSmall: head.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
      titleLarge: head.titleLarge?.copyWith(fontWeight: FontWeight.w800),
    );
    final radius6 = BorderRadius.circular(6);
    final buttonText = GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 0.1);
    OutlineInputBorder field(Color c, [double w = 1]) => OutlineInputBorder(borderRadius: radius6, borderSide: BorderSide(color: c, width: w));

    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: orange,
        brightness: b,
        primary: orange,
        onPrimary: Colors.white,
        secondary: navy,
        onSecondary: Colors.white,
        surface: card,
        onSurface: ink,
        outline: line,
        error: danger,
      ),
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      dividerColor: line,
      dividerTheme: DividerThemeData(color: line, thickness: 1, space: 1),
      // The website's sticky header: navy with white icons.
      appBarTheme: AppBarTheme(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 4,
        systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(statusBarColor: navy),
        titleTextStyle: GoogleFonts.nunito(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white),
        iconTheme: const IconThemeData(color: Colors.white, size: 22),
        actionsIconTheme: const IconThemeData(color: Colors.white, size: 22),
      ),
      cardTheme: CardThemeData(
        color: card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: line)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: orange,
          foregroundColor: Colors.white,
          disabledBackgroundColor: orange.withValues(alpha: 0.45),
          disabledForegroundColor: Colors.white,
          textStyle: buttonText,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: radius6),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: orange,
          foregroundColor: Colors.white,
          disabledBackgroundColor: orange.withValues(alpha: 0.45),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          textStyle: buttonText,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: radius6),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: orange,
          side: const BorderSide(color: orange, width: 1.5),
          textStyle: buttonText,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          shape: RoundedRectangleBorder(borderRadius: radius6),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: orange, textStyle: buttonText.copyWith(fontWeight: FontWeight.w600)),
      ),
      iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: dark ? ink : null)),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: orange,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: StadiumBorder(),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        labelStyle: TextStyle(color: sub),
        floatingLabelStyle: const TextStyle(color: orange, fontWeight: FontWeight.w600),
        hintStyle: TextStyle(color: muted),
        helperStyle: TextStyle(color: muted),
        prefixIconColor: muted,
        suffixIconColor: muted,
        border: field(dark ? line : input),
        enabledBorder: field(dark ? line : input),
        focusedBorder: field(orange, 1.5),
        errorBorder: field(danger),
        focusedErrorBorder: field(danger, 1.5),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: card,
        selectedColor: orangeSoft,
        secondarySelectedColor: orangeSoft,
        side: BorderSide(color: line),
        labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: ink),
        secondaryLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: orange),
        checkmarkColor: orange,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 66,
        indicatorColor: orangeSoft,
        shadowColor: Colors.black12,
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(color: s.contains(WidgetState.selected) ? orange : muted, size: 24)),
        labelTextStyle: WidgetStateProperty.resolveWith((s) => GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
              color: s.contains(WidgetState.selected) ? orange : muted,
            )),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: orange,
        unselectedLabelColor: sub,
        indicatorColor: orange,
        dividerColor: line,
        labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
        unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: line,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        titleTextStyle: GoogleFonts.nunito(fontSize: 19, fontWeight: FontWeight.w800, color: ink),
        contentTextStyle: GoogleFonts.inter(fontSize: 14, color: sub, height: 1.45),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: navy,
        contentTextStyle: GoogleFonts.inter(color: Colors.white, fontSize: 13.5),
        actionTextColor: orangeLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      listTileTheme: ListTileThemeData(iconColor: sub, textColor: ink, titleTextStyle: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w500, color: ink)),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: orange),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? orange : null),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      radioTheme: RadioThemeData(fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? orange : muted)),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : null),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? orange : null),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: line)),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(menuStyle: MenuStyle(backgroundColor: WidgetStatePropertyAll(card))),
      expansionTileTheme: ExpansionTileThemeData(iconColor: orange, collapsedIconColor: muted, shape: const Border(), collapsedShape: const Border()),
    );
  }
}
