import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Added for HapticFeedback
import 'package:firebase_auth/firebase_auth.dart';
import '/home_screen.dart'; 
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true; // State for password visibility

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showToast("PLEASE FILL ALL FIELDS");
      return;
    }
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen()));
      }
    } on FirebaseAuthException catch (e) {
      _showToast(e.message ?? "ACCESS DENIED");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showToast("ENTER YOUR EMAIL IN THE ADDRESS FIELD ABOVE");
      return;
    }
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _showToast("RESET PROTOCOL LINK SENT TO EMAIL");
    } on FirebaseAuthException catch (e) {
      _showToast(e.message ?? "RESET PROTOCOL FAILED");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, 
          style: const TextStyle(fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFFD32F2F), 
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4EC),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: SizedBox(
            // Ensures full height coverage for centering while allowing scroll
            height: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  _buildHeader(),
                  const SizedBox(height: 50),
                  _buildPanel(),
                  const SizedBox(height: 30),
                  _buildSignupButton(),
                  const Spacer(flex: 3),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        const Text("SCREENIQUE", 
          style: TextStyle(
            color: Color(0xFF111111),
            fontWeight: FontWeight.w900, 
            letterSpacing: 4,          
            fontSize: 48,               
            height: 1.0,
            fontFamily: 'Impact',
          )),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          color: const Color(0xFFD32F2F),
          child: const Text("ENCRYPTED ACCESS", 
            style: TextStyle(
              color: Color(0xFFF4F4EC), 
              fontSize: 10, 
              letterSpacing: 4, 
              fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4EC),
        border: Border.all(color: const Color(0xFF111111), width: 2.0),
        boxShadow: const [BoxShadow(color: Color(0xFF111111), offset: Offset(6, 6))],
      ),
      child: Column(
        children: [
          _buildInput(_emailController, "EMAIL ADDRESS", Icons.alternate_email_rounded),
          const SizedBox(height: 20),
          _buildInput(_passwordController, "SECURITY KEY", Icons.lock_outline_rounded, isObscure: true),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _isLoading ? null : _handleForgotPassword,
              child: const Text(
                "FORGOT PASSWORD?",
                style: TextStyle(
                  color: Color(0xFF454545),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildActionButton(),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFD32F2F),
          shape: const RoundedRectangleBorder(side: BorderSide(color: Color(0xFF111111), width: 2)),
          elevation: 0,
        ),
        onPressed: _isLoading ? null : _handleLogin,
        child: _isLoading 
          ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Color(0xFFF4F4EC), strokeWidth: 2))
          : const Text("INITIALIZE LOGIN", 
              style: TextStyle(color: Color(0xFFF4F4EC), fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 13)),
      ),
    );
  }

  Widget _buildInput(TextEditingController controller, String hint, IconData icon, {bool isObscure = false}) {
    return TextField(
      controller: controller,
      obscureText: isObscure ? _obscurePassword : false,
      style: const TextStyle(color: Color(0xFF111111), fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.5),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF454545), fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.bold),
        prefixIcon: Icon(icon, color: const Color(0xFF111111), size: 20),
        suffixIcon: isObscure 
          ? IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: const Color(0xFF111111),
                size: 20,
              ),
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() => _obscurePassword = !_obscurePassword);
              },
            )
          : null,
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
        filled: true,
        fillColor: const Color(0xFFF4F4EC),
        enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF111111), width: 2)),
        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFD32F2F), width: 2)),
      ),
    );
  }

  Widget _buildSignupButton() {
    return TextButton(
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SignupScreen())),
      child: RichText(
        text: const TextSpan(
          style: TextStyle(color: Color(0xFF454545), fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.bold),
          children: [
            TextSpan(text: "NEW USER? "),
            TextSpan(
              text: "CREATE ARCHIVE", 
              style: TextStyle(color: Color(0xFFD32F2F), fontWeight: FontWeight.w900)
            ),
          ],
        ),
      ),
    );
  }
}
