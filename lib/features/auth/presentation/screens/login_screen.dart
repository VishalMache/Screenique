import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lottie/lottie.dart';
import '/home_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
  
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Animation<double> _getFade(double start, double end) {
    return Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      ),
    );
  }

  Animation<Offset> _getSlide(double start, double end) {
    return Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      ),
    );
  }

  void _showForgotPasswordSheet() {
    final resetEmailController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF5EADE),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(28, 12, 28, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF111111).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Reset Password',
                style: TextStyle(
                  color: Color(0xFF111111),
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter',
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Enter your email and we\'ll send you a reset link.',
                style: TextStyle(
                  color: const Color(0xFF111111).withOpacity(0.5),
                  fontFamily: 'Inter',
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: resetEmailController,
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                style: const TextStyle(color: Color(0xFF111111), fontFamily: 'Inter', fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Email address',
                  hintStyle: TextStyle(color: const Color(0xFF111111).withOpacity(0.4), fontFamily: 'Inter'),
                  prefixIcon: Icon(Icons.mail_rounded, color: const Color(0xFF111111).withOpacity(0.4), size: 22),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: const Color(0xFF111111).withOpacity(0.08)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: const Color(0xFF111111).withOpacity(0.08)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF111111), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Spam notice
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8D5B0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 16, color: const Color(0xFF111111).withOpacity(0.6)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'The reset email may land in your Spam or Junk folder.',
                        style: TextStyle(
                          color: const Color(0xFF111111).withOpacity(0.65),
                          fontFamily: 'Inter',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF111111),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    final email = resetEmailController.text.trim();
                    if (email.isEmpty) return;
                    Navigator.pop(ctx);
                    try {
                      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                      if (mounted) {
                        _showMessage('Reset link sent! Check your inbox.');
                      }
                    } catch (e) {
                      if (mounted) _showMessage('Could not send reset email. Check the address.');
                    }
                  },
                  child: const Text('Send Reset Link',
                    style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showMessage("Please fill in all fields.");
      return;
    }
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (mounted) {
        HapticFeedback.heavyImpact();
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on FirebaseAuthException catch (e) {
      _showMessage(e.message ?? "Sign in failed. Please try again.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isGoogleLoading = true);
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        if (mounted) setState(() => _isGoogleLoading = false);
        return;
      }
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        final docRef =
            FirebaseFirestore.instance.collection('users').doc(user.uid);
        final doc = await docRef.get();
        if (!doc.exists) {
          final name = user.displayName ?? 'Cinephile';
          final baseUsername = name.toLowerCase().replaceAll(' ', '_');
          final uniqueUsername = '${baseUsername}_${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
          await docRef.set({
            'name': name,
            'email': user.email ?? '',
            'createdAt': FieldValue.serverTimestamp(),
            'premium': false,
            'watchedCount': 0,
            'bio': 'A lover of cinema.',
            'isPublic': true,
            'username': uniqueUsername,
            'followersCount': 0,
            'followingCount': 0,
            'badges': ['Pioneer'],
          });
        }
      }

      if (mounted) {
        HapticFeedback.heavyImpact();
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      _showMessage("Google sign-in failed. Please try again.");
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: const TextStyle(
                fontFamily: 'Inter', fontSize: 13, color: Colors.white)),
        backgroundColor: const Color(0xFF111111),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5EADE), // Match logo background
      body: Stack(
        children: [
          // Subtle Popcorn Lottie (if it looks good on light theme)
          Positioned.fill(
            child: Opacity(
              opacity: 0.05, // reduced opacity for light theme
              child: Transform.scale(
                scale: 1.2,
                child: Lottie.asset(
                  'assets/animations/Popcorn.json',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // LOGO & HEADER
                    FadeTransition(
                      opacity: _getFade(0.0, 0.4),
                      child: SlideTransition(
                        position: _getSlide(0.0, 0.4),
                        child: Column(
                          children: [
                            Image.asset(
                              'assets/logo11.png',
                              width: 200, // Reduced size to prevent overflow
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Your cinematic archive.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: const Color(0xFF111111).withOpacity(0.6),
                                fontSize: 16,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),

                    // GOOGLE BUTTON
                    FadeTransition(
                      opacity: _getFade(0.1, 0.5),
                      child: SlideTransition(
                        position: _getSlide(0.1, 0.5),
                        child: _buildGoogleButton(),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // DIVIDER
                    FadeTransition(
                      opacity: _getFade(0.2, 0.6),
                      child: Row(
                        children: [
                          Expanded(
                              child: Container(height: 1, color: const Color(0xFF111111).withOpacity(0.1))),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'or',
                              style: TextStyle(
                                color: const Color(0xFF111111).withOpacity(0.4),
                                fontFamily: 'Inter',
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Expanded(
                              child: Container(height: 1, color: const Color(0xFF111111).withOpacity(0.1))),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),

                    // FIELDS
                    FadeTransition(
                      opacity: _getFade(0.3, 0.7),
                      child: SlideTransition(
                        position: _getSlide(0.3, 0.7),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _buildEmailField(),
                            const SizedBox(height: 16),
                            _buildPasswordField(),
                            const SizedBox(height: 10),
                            GestureDetector(
                              onTap: _showForgotPasswordSheet,
                              child: Text(
                                'Forgot password?',
                                style: TextStyle(
                                  color: const Color(0xFF111111).withOpacity(0.5),
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),

                    // LOGIN BUTTON
                    FadeTransition(
                      opacity: _getFade(0.4, 0.8),
                      child: SlideTransition(
                        position: _getSlide(0.4, 0.8),
                        child: _buildLoginButton(),
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // SIGNUP LINK
                    FadeTransition(
                      opacity: _getFade(0.5, 0.9),
                      child: SlideTransition(
                        position: _getSlide(0.5, 0.9),
                        child: _buildSignupLink(),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleButton() {
    return GestureDetector(
      onTap: _isGoogleLoading ? null : _handleGoogleSignIn,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF111111).withOpacity(0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: _isGoogleLoading
            ? const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(color: Color(0xFF111111), strokeWidth: 2),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/google_logo.png',
                    width: 24,
                    height: 24,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Continue with Google',
                    style: TextStyle(
                      color: Color(0xFF111111),
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildEmailField() {
    return _AuthTextField(
      controller: _emailController,
      hint: 'Email address',
      prefixIcon: Icons.mail_rounded,
      keyboardType: TextInputType.emailAddress,
    );
  }

  Widget _buildPasswordField() {
    return _AuthTextField(
      controller: _passwordController,
      hint: 'Password',
      prefixIcon: Icons.lock_rounded,
      obscureText: _obscurePassword,
      suffixIcon: IconButton(
        icon: Icon(
          _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
          color: const Color(0xFF111111).withOpacity(0.4),
          size: 20,
        ),
        onPressed: () {
          HapticFeedback.selectionClick();
          setState(() => _obscurePassword = !_obscurePassword);
        },
      ),
    );
  }

  Widget _buildLoginButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _handleLogin,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF111111).withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: _isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text(
                  'Sign In',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildSignupLink() {
    return Center(
      child: GestureDetector(
        onTap: () => Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const SignupScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            )),
        child: RichText(
          text: TextSpan(
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: const Color(0xFF111111).withOpacity(0.5),
            ),
            children: const [
              TextSpan(text: "Don't have an account? "),
              TextSpan(
                text: "Sign Up",
                style: TextStyle(
                  color: Color(0xFF111111),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData prefixIcon;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;

  const _AuthTextField({
    required this.controller,
    required this.hint,
    required this.prefixIcon,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(
        color: Color(0xFF111111),
        fontFamily: 'Inter',
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: const Color(0xFF111111).withOpacity(0.4),
          fontFamily: 'Inter',
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        prefixIcon: Icon(prefixIcon, color: const Color(0xFF111111).withOpacity(0.4), size: 22),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: const Color(0xFF111111).withOpacity(0.08), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: const Color(0xFF111111).withOpacity(0.08), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF111111), width: 1.5),
        ),
      ),
    );
  }
}
