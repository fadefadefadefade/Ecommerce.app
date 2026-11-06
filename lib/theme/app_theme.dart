import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// ALVY Commerce design tokens (Mobile design/…/alvy_commerce/DESIGN.md, the Stitch screens): a warm cream page,
/// white rounded cards with soft shadows, the web's bright ALVY orange (#FA4E1C) for actions, warm beige fills for inputs and secondary
/// buttons, Plus Jakarta Sans for headings and prices, Inter for text.
/// (The names navy/orange are kept so every screen picks up the new colors.)
class Alvy {
  static const navy = Color(0xFF1E1B17); // ink: headings and main text
  static const navyLight = Color(0xFF33302C);
  static const slate = Color(0xFF406185); // secondary: links, store names, info
  static const orange = Color(0xFFFA4E1C); // primary actions
  static const orangeDark = Color(0xFFD93D0E);
  static const orangeLight = Color(0xFFFF7A45);
  static const orangeSoft = Color(0xFFFFF1EE);
  static const page = Color(0xFFFFF8F2);
  static const surface = Colors.white;
  static const subtle = Color(0xFFF4EDE6); // input shells, secondary buttons, chips
  static const subtleHigh = Color(0xFFEEE7E0);
  static const border = Color(0xFFEEE7E0);
  static const input = Color(0xFFE8E1DB);
  static const text = navy;
  static const textSub = Color(0xFF5C4039);
  static const textMuted = Color(0xFF8A716A);
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFB45309);
  static const danger = Color(0xFFDC2626);

  /// Hero banners and highlight panels.
  static const gradient = LinearGradient(colors: [orange, orangeLight], begin: Alignment.topLeft, end: Alignment.bottomRight);

  /// Soft, warm card shadows (no hard borders).
  static const cardShadow = [BoxShadow(color: Color(0x0F2A1A10), blurRadius: 14, offset: Offset(0, 3))];
  static const liftShadow = [BoxShadow(color: Color(0x1A2A1A10), blurRadius: 24, offset: Offset(0, 8))];
  static const buttonShadow = [BoxShadow(color: Color(0x47FA4E1C), blurRadius: 10, offset: Offset(0, 3))];

  /// Headings and prices.
  static TextStyle display({double size = 20, Color color = navy, FontWeight weight = FontWeight.w800}) =>
      GoogleFonts.plusJakartaSans(fontSize: size, fontWeight: weight == FontWeight.w900 ? FontWeight.w800 : weight, color: color, height: 1.2, letterSpacing: -0.2);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final dark = b == Brightness.dark;
    final bg = dark ? const Color(0xFF15110E) : page;
    final card = dark ? const Color(0xFF211C18) : surface;
    final fill = dark ? const Color(0xFF2B2520) : subtle;
    final line = dark ? const Color(0xFF3A322C) : border;
    final ink = dark ? const Color(0xFFF2E6DE) : text;
    final sub = dark ? const Color(0xFFD6C2B8) : textSub;
    final muted = dark ? const Color(0xFFA48F85) : textMuted;
    final action = dark ? orangeLight : orange;
    final tint = dark ? const Color(0xFF3D2116) : orangeSoft;

    final base = ThemeData(useMaterial3: true, brightness: b);
    final body = GoogleFonts.interTextTheme(base.textTheme).apply(bodyColor: ink, displayColor: ink);
    final head = GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(bodyColor: ink, displayColor: ink);
    final textTheme = body.copyWith(
      displayLarge: head.displayLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
      displayMedium: head.displayMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4),
      displaySmall: head.displaySmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.3),
      headlineLarge: head.headlineLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
      headlineMedium: head.headlineMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.2),
      headlineSmall: head.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.2),
      titleLarge: head.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.2),
      titleMedium: head.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );
    final r8 = BorderRadius.circular(10);
    final r12 = BorderRadius.circular(12);
    final buttonText = GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14.5, letterSpacing: 0.1);
    OutlineInputBorder field(Color c, [double w = 1]) => OutlineInputBorder(borderRadius: r12, borderSide: BorderSide(color: c, width: w));

    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: orange,
        brightness: b,
        primary: action,
        onPrimary: Colors.white,
        primaryContainer: tint,
        onPrimaryContainer: dark ? const Color(0xFFFFDBD1) : orangeDark,
        secondary: dark ? const Color(0xFFA8C9F3) : slate,
        onSecondary: Colors.white,
        surface: card,
        onSurface: ink,
        onSurfaceVariant: sub,
        surfaceContainerLowest: card,
        surfaceContainerLow: dark ? const Color(0xFF1C1814) : const Color(0xFFFAF2EB),
        surfaceContainer: fill,
        surfaceContainerHigh: dark ? const Color(0xFF332C26) : subtleHigh,
        surfaceContainerHighest: dark ? const Color(0xFF3A322C) : input,
        outline: line,
        outlineVariant: line,
        error: danger,
      ),
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      dividerColor: line,
      dividerTheme: DividerThemeData(color: line, thickness: 1, space: 1),
      // A light header: white bar, dark title, soft shadow underneath.
      appBarTheme: AppBarTheme(
        backgroundColor: card,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1.5,
        shadowColor: const Color(0x332A1A10),
        centerTitle: false,
        titleSpacing: 20,
        systemOverlayStyle: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(statusBarColor: Colors.transparent),
        titleTextStyle: GoogleFonts.plusJakartaSans(fontSize: 18.5, fontWeight: FontWeight.w700, color: ink, letterSpacing: -0.2),
        iconTheme: IconThemeData(color: ink, size: 23),
        actionsIconTheme: IconThemeData(color: dark ? ink : slate, size: 23),
      ),
      cardTheme: CardThemeData(
        color: card,
        surfaceTintColor: Colors.transparent,
        elevation: dark ? 0 : 1.5,
        shadowColor: const Color(0x262A1A10),
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: dark ? BorderSide(color: line) : BorderSide.none),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: action,
          foregroundColor: Colors.white,
          disabledBackgroundColor: action.withValues(alpha: 0.4),
          disabledForegroundColor: Colors.white,
          textStyle: buttonText,
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: r8),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: action,
          foregroundColor: Colors.white,
          disabledBackgroundColor: action.withValues(alpha: 0.4),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          textStyle: buttonText,
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: r8),
        ),
      ),
      // Secondary buttons: a warm beige shell with dark text (Cart, Chat with Shop, Details…).
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          backgroundColor: fill,
          side: BorderSide(color: fill),
          textStyle: buttonText,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          shape: RoundedRectangleBorder(borderRadius: r8),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: action, textStyle: buttonText.copyWith(fontWeight: FontWeight.w600)),
      ),
      iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: dark ? ink : null)),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: action,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: const StadiumBorder(),
      ),
      // Inputs: a filled beige shell, no outline until focused.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fill,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: TextStyle(color: sub),
        floatingLabelStyle: TextStyle(color: action, fontWeight: FontWeight.w600),
        hintStyle: TextStyle(color: muted),
        helperStyle: TextStyle(color: muted),
        prefixIconColor: muted,
        suffixIconColor: muted,
        border: field(fill),
        enabledBorder: field(fill),
        disabledBorder: field(fill),
        focusedBorder: field(action, 1.5),
        errorBorder: field(danger),
        focusedErrorBorder: field(danger, 1.5),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: fill,
        selectedColor: tint,
        secondarySelectedColor: tint,
        disabledColor: fill,
        side: BorderSide.none,
        labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: ink),
        secondaryLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: action),
        checkmarkColor: action,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        height: 68,
        indicatorColor: tint,
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        shadowColor: const Color(0x332A1A10),
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(color: s.contains(WidgetState.selected) ? action : sub, size: 24)),
        labelTextStyle: WidgetStateProperty.resolveWith((s) => GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
              color: s.contains(WidgetState.selected) ? action : sub,
            )),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: action,
        unselectedLabelColor: sub,
        indicatorColor: action,
        indicatorSize: TabBarIndicatorSize.label,
        indicator: UnderlineTabIndicator(borderSide: BorderSide(color: action, width: 3), borderRadius: BorderRadius.circular(3)),
        dividerColor: line,
        labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
        unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: dark ? line : input,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: GoogleFonts.plusJakartaSans(fontSize: 19, fontWeight: FontWeight.w700, color: ink),
        contentTextStyle: GoogleFonts.inter(fontSize: 14, color: sub, height: 1.45),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF33302C),
        contentTextStyle: GoogleFonts.inter(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w500),
        actionTextColor: const Color(0xFFFFB5A1),
        shape: RoundedRectangleBorder(borderRadius: r12),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: sub,
        textColor: ink,
        shape: RoundedRectangleBorder(borderRadius: r12),
        titleTextStyle: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w600, color: ink),
        subtitleTextStyle: GoogleFonts.inter(fontSize: 12.5, color: sub),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: action, linearTrackColor: fill),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? action : null),
        side: BorderSide(color: muted, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      radioTheme: RadioThemeData(fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? action : muted)),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : null),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? action : null),
        trackOutlineColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? action : null),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? action : fill),
          foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : ink),
          side: WidgetStatePropertyAll(BorderSide(color: fill)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: r8)),
          textStyle: WidgetStatePropertyAll(GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: card,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shadowColor: const Color(0x332A1A10),
        shape: RoundedRectangleBorder(borderRadius: r12),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(menuStyle: MenuStyle(backgroundColor: WidgetStatePropertyAll(card))),
      expansionTileTheme: ExpansionTileThemeData(iconColor: action, collapsedIconColor: muted, shape: const Border(), collapsedShape: const Border()),
    );
  }
}
