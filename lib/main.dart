import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/auth/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer2<AuthProvider, ThemeProvider>(
        builder: (context, auth, theme, _) => MaterialApp(
          title: 'ALVY',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFfa4e1c),
              primary: const Color(0xFFfa4e1c),
            ),
            scaffoldBackgroundColor: const Color(0xFFfbeee8),
            textTheme: GoogleFonts.interTextTheme(),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFfa4e1c),
              primary: const Color(0xFFfa4e1c),
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: const Color(0xFF121212),
            textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
          ),
          // Only buyer screens are theme-aware so far; other roles stay light.
          themeMode: auth.user?.isBuyer == true ? theme.mode : ThemeMode.light,
          home: const AuthWrapper(),
        ),
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  AuthProvider? _authProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authProvider = context.read<AuthProvider>();
      _authProvider!.addListener(_onAuthStateChanged);
      _authProvider!.checkAuthStatus();
    });
  }

  @override
  void dispose() {
    try {
      _authProvider?.removeListener(_onAuthStateChanged);
    } catch (e) {
      // Ignore errors during dispose
      debugPrint('⚠️  Error removing AuthWrapper listener: $e');
    }
    super.dispose();
  }

  void _onAuthStateChanged() {
    debugPrint('🔔 AuthProvider listener triggered - rebuilding!');
    if (mounted) {
      setState(() {
        // Force rebuild when auth state changes
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        debugPrint('🔍 AuthWrapper rebuild - isLoading: ${authProvider.isLoading}, user: ${authProvider.user?.email ?? 'null'}, role: ${authProvider.user?.role ?? 'null'}');
        
        // Show loading spinner while authenticating
        if (authProvider.isLoading) {
          debugPrint('⏳ Showing loading spinner');
          return const Scaffold(
            backgroundColor: Color(0xFFfbeee8),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFFfa4e1c)),
                  SizedBox(height: 16),
                  Text('Logging in...', style: TextStyle(color: Color(0xFF6b90aa))),
                ],
              ),
            ),
          );
        }

        // Show login screen if no user
        if (authProvider.user == null) {
          debugPrint('🔑 Showing login screen (no user)');
          return const LoginScreen();
        }

        // User is authenticated, route to appropriate screen
        debugPrint('🚀 User authenticated, routing to role-based screen');
        try {
          return authProvider.getMainScreenForRole();
        } catch (e) {
          debugPrint('💥 Error in getMainScreenForRole: $e');
          // Fallback to login screen on error
          return const LoginScreen();
        }
      },
    );
  }
}
