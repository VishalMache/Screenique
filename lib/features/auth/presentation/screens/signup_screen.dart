import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lottie/lottie.dart';
import '/home_screen.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with TickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
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
    _nameController.dispose();
    _usernameController.dispose();
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

  Future<void> _handleSignup() async {
    if (_nameController.text.isEmpty ||
        _usernameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      _showMessage("Please fill in all fields.");
      return;
    }
    
    final username = _usernameController.text.trim().toLowerCase();
    if (username.contains(' ')) {
      _showMessage("Username cannot contain spaces.");
      return;
    }

    if (_passwordController.text.trim().length < 6) {
      _showMessage("Password must be at least 6 characters.");
      return;
    }
    setState(() => _isLoading = true);
    try {
      // Check if username is taken
      final usernameCheck = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: username)
          .get();
          
      if (usernameCheck.docs.isNotEmpty) {
        _showMessage("This username is already taken.");
        setState(() => _isLoading = false);
        return;
      }

      final userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final name = _nameController.text.trim();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
        'name': name,
        'email': _emailController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'premium': false,
        'watchedCount': 0,
        'bio': 'A lover of cinema.',
        'isPublic': true,
        'username': username,
        'followersCount': 0,
        'followingCount': 0,
        'badges': ['Pioneer'],
      });

      if (mounted) {
        HapticFeedback.heavyImpact();
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      _showMessage("Sign up failed. Please check your details.");
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
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
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
      backgroundColor: const Color(0xFFF5EADE),
      body: Stack(
        children: [
          // Lottie Background Animation
          Positioned.fill(
            child: Opacity(
              opacity: 0.05,
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
                    // BACK BUTTON
                    FadeTransition(
                      opacity: _getFade(0.0, 0.3),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 44,
                            height: 44,
                            margin: const EdgeInsets.only(bottom: 24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF111111).withOpacity(0.08)),
                            ),
                            child: const Icon(Icons.arrow_back_ios_new_rounded,
                                color: Color(0xFF111111), size: 18),
                          ),
                        ),
                      ),
                    ),
                    
                    // HEADER
                    FadeTransition(
                      opacity: _getFade(0.1, 0.4),
                      child: SlideTransition(
                        position: _getSlide(0.1, 0.4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Image.asset(
                              'assets/logo11.png',
                              width: 180, // Reduced size to prevent overflow
                              fit: BoxFit.contain,
                              alignment: Alignment.centerLeft,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Create your cinematic archive today.',
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
                    const SizedBox(height: 40),

                    // GOOGLE BUTTON
                    FadeTransition(
                      opacity: _getFade(0.2, 0.5),
                      child: SlideTransition(
                        position: _getSlide(0.2, 0.5),
                        child: _buildGoogleButton(),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // DIVIDER
                    FadeTransition(
                      opacity: _getFade(0.3, 0.6),
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
                      opacity: _getFade(0.4, 0.7),
                      child: SlideTransition(
                        position: _getSlide(0.4, 0.7),
                        child: Column(
                          children: [
                            _buildNameField(),
                            const SizedBox(height: 16),
                            _buildUsernameField(),
                            const SizedBox(height: 16),
                            _buildEmailField(),
                            const SizedBox(height: 16),
                            _buildPasswordField(),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 32),

                    // SIGNUP BUTTON
                    FadeTransition(
                      opacity: _getFade(0.5, 0.8),
                      child: SlideTransition(
                        position: _getSlide(0.5, 0.8),
                        child: _buildSignupButton(),
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // LOGIN LINK
                    FadeTransition(
                      opacity: _getFade(0.6, 0.9),
                      child: SlideTransition(
                        position: _getSlide(0.6, 0.9),
                        child: _buildLoginLink(),
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

  Widget _buildNameField() => _AuthTextField(
        controller: _nameController,
        hint: 'Full name',
        prefixIcon: Icons.person_rounded,
      );

  Widget _buildUsernameField() => _AuthTextField(
        controller: _usernameController,
        hint: 'Unique username (lowercase)',
        prefixIcon: Icons.alternate_email_rounded,
      );

  Widget _buildEmailField() => _AuthTextField(
        controller: _emailController,
        hint: 'Email address',
        prefixIcon: Icons.mail_rounded,
        keyboardType: TextInputType.emailAddress,
      );

  Widget _buildPasswordField() => _AuthTextField(
        controller: _passwordController,
        hint: 'Password (min 6 chars)',
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

  Widget _buildSignupButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _handleSignup,
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
                  'Create Account',
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

  Widget _buildLoginLink() {
    return Center(
      child: GestureDetector(
        onTap: () => Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const LoginScreen(),
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
              TextSpan(text: "Already have an account? "),
              TextSpan(
                text: "Sign In",
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
