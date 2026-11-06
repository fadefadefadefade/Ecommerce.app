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
    const ink = Alvy.navy;
    Widget label(String t) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(t, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: ink)),
        );
    return Scaffold(
      backgroundColor: Alvy.page,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // The brand mark in a soft orange disc, then ALVY and the welcome line.
                    Center(
                      child: Container(
                        width: 104,
                        height: 104,
                        padding: const EdgeInsets.all(22),
                        decoration: const BoxDecoration(color: Color(0xFFFFDBD1), shape: BoxShape.circle),
                        child: Image.asset('assets/images/logo-mark.png', fit: BoxFit.contain),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('ALVY', style: Alvy.display(size: 36, weight: FontWeight.w800)),
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(left: 3, bottom: 11),
                        decoration: const BoxDecoration(color: Alvy.orange, shape: BoxShape.circle),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    const Text('Welcome back to ALVY', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: Alvy.textSub)),
                    const SizedBox(height: 26),

                    // The credentials card.
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: Alvy.cardShadow),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                        Text('Log in to your account', style: Alvy.display(size: 17, weight: FontWeight.w700)),
                        const SizedBox(height: 18),
                        if (_error != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: const Color(0xFFFFDAD6), borderRadius: BorderRadius.circular(12)),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Icon(Icons.error_outline, size: 18, color: Color(0xFF93000A)),
                              const SizedBox(width: 8),
                              Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFF93000A), fontSize: 13, height: 1.35))),
                            ]),
                          ),
                          const SizedBox(height: 16),
                        ],

                        label('Email Address'),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            hintText: 'example@gmail.com',
                            prefixIcon: Icon(Icons.mail_outline_rounded, size: 20),
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 16),
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
                        const SizedBox(height: 18),

                        label('Password'),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            hintText: 'Enter your password',
                            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
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
                        // "Forgot password?" (an emailed reset link).
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(
                              builder: (_) => ForgotPasswordScreen(email: _emailController.text.trim()),
                            )),
                            child: const Text('Forgot Password?', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Login button
                        Container(
                          height: 54,
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), boxShadow: _isLoading ? null : Alvy.buttonShadow),
                          child: FilledButton(
                            onPressed: _isLoading ? null : _handleLogin,
                            style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            child: _isLoading
                                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                    Text('Log In to ALVY', style: Alvy.display(size: 17, color: Colors.white, weight: FontWeight.w700)),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.arrow_forward, size: 20),
                                  ]),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 26),

                    // Register link
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text("Don't have an account?  ", style: TextStyle(fontSize: 15, color: Alvy.textSub)),
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
                          child: const Text('Sign Up', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.verified_user_outlined, size: 15, color: Alvy.textMuted),
                      SizedBox(width: 6),
                      Text('Your account is protected by ALVY', style: TextStyle(fontSize: 12.5, color: Alvy.textMuted, fontWeight: FontWeight.w600)),
                    ]),
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
