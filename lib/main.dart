import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/buyer/home_screen.dart';
import 'screens/seller/dashboard_screen.dart';
import 'screens/courier/dashboard_screen.dart';
import 'screens/admin/dashboard_screen.dart';
import 'screens/sorting_center/dashboard_screen.dart';

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
      ],
      child: MaterialApp(
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
        home: const AuthWrapper(),
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().checkAuthStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (authProvider.isLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFFfa4e1c),
              ),
            ),
          );
        }

        if (authProvider.user == null) {
          return const LoginScreen();
        }

        // Route based on user role (customer and buyer are the same)
        final role = authProvider.user!.role;
        switch (role) {
          case 'buyer':
          case 'customer':
            return const BuyerHomeScreen();
          case 'seller':
            return const SellerDashboardScreen();
          case 'courier':
            return const CourierDashboardScreen();
          case 'admin':
            return const AdminDashboardScreen();
          case 'sorting_center':
            return const SortingCenterDashboardScreen();
          default:
            return const LoginScreen();
        }
      },
    );
  }
}
