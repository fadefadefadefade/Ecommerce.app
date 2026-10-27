import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'forgot_password_screen.dart';
import 'otp_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _error;

  AuthProvider? _authProvider;

  @override
  void initState() {
    super.initState();
    // Add listener to AuthProvider for direct navigation handling
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _authProvider = Provider.of<AuthProvider>(context, listen: false)
          ..addListener(_handleAuthStateChange);
        // e.g. "Your session expired. Please log in again." after 30 idle minutes.
        final notice = _authProvider!.takeNotice();
        if (notice != null) setState(() => _error = notice);
      }
    });
  }

  @override
  void dispose() {
    // Uses the saved reference: looking up context in dispose() is unsafe.
    _authProvider?.removeListener(_handleAuthStateChange);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
  
  void _handleAuthStateChange() {
    if (!mounted) return; // Guard against calling on unmounted widget
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    debugPrint('🔔 AuthProvider listener triggered - isAuthenticated: ${authProvider.isAuthenticated}');
    
    if (authProvider.isAuthenticated && authProvider.user != null) {
      debugPrint('🚀 Direct navigation triggered by AuthProvider listener');
      _navigateToMainScreen(authProvider);
    }
  }
  
  void _navigateToMainScreen(AuthProvider authProvider) {
    if (!mounted) return; // Guard against navigation on unmounted widget
    
    final targetScreen = authProvider.getMainScreenForRole();
    debugPrint('🎯 Direct listener navigation to: ${targetScreen.runtimeType}');
    
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => targetScreen),
      (route) => false,
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final authProvider = context.read<AuthProvider>();
    final result = await authProvider.login(
      _emailController.text.trim(),
      _passwordController.text,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.ok) {
      // The listener / AuthWrapper opens the account's part of the app; this is the fallback.
      if (ModalRoute.of(context)?.isCurrent == true && authProvider.user != null) {
        _navigateToMainScreen(authProvider);
      }
    } else if (result.needsOtp) {
      // Sign-up never finished: confirm the emailed code first (the web's code step).
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => OtpScreen(
          otpToken: result.otpToken!,
          message: result.message,
          maskedEmail: result.maskedEmail,
          cooldown: result.cooldown,
        ),
      ));
    } else {
      setState(() => _error = result.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 440),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE6EDF2)),
                boxShadow: Alvy.liftShadow,
              ),
              padding: const EdgeInsets.all(32),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Image.asset('assets/images/logo-mark.png', width: 52, height: 52),
                      const SizedBox(width: 10),
                      Text('ALVY', style: Alvy.display(size: 30)),
                    ]),
                    const SizedBox(height: 24),

                    // Title
                    Text('Welcome back', style: Alvy.display(size: 26)),
                    const SizedBox(height: 8),
                    const Text(
                      'Enter your details to login',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B90AA),
                      ),
                    ),
                    const SizedBox(height: 20),


                    if (_error != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Text(_error!, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13)),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Email Field
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Email Address',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF002B4D),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: 'example@gmail.com',
                            hintStyle: const TextStyle(color: Color(0xFF6B90AA)),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFE6EDF2)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFE6EDF2)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFfa4e1c), width: 2),
                            ),
                            contentPadding: const EdgeInsets.all(14),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())) {
                              return 'Invalid email. Please check the format (e.g. name@gmail.com)';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Password Field
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Password',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF002B4D),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            hintText: '••••••••',
                            hintStyle: const TextStyle(color: Color(0xFF6B90AA)),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFE6EDF2)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFE6EDF2)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFfa4e1c), width: 2),
                            ),
                            contentPadding: const EdgeInsets.all(14),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                color: const Color(0xFF6B90AA),
                              ),
                              onPressed: () {
                                setState(() => _obscurePassword = !_obscurePassword);
                              },
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            return null;
                          },
                        ),
                        // The website's "Forgot password?" (an emailed reset link).
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(
                              builder: (_) => ForgotPasswordScreen(email: _emailController.text.trim()),
                            )),
                            child: const Text('Forgot password?', style: TextStyle(color: Color(0xFFfa4e1c), fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Login Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFfa4e1c),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Log In',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward, size: 20),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Register Link
                    Wrap(
                      alignment: WrapAlignment.center,
                      children: [
                        const Text(
                          "Don't have an account? ",
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B90AA),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RegisterScreen(),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Create an Account',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF002B4D),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
