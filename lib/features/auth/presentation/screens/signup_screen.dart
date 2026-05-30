import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Added for HapticFeedback
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/home_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true; // State for password visibility

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (_emailController.text.isEmpty || 
        _passwordController.text.isEmpty || 
        _nameController.text.isEmpty) {
      _showToast("PLEASE FILL ALL ARCHIVAL FIELDS");
      return;
    }
        
    setState(() => _isLoading = true);
    try {
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'premium': false,
        'watchedCount': 0, // Initializing count for DNA analysis
      });

      if (mounted) {
        HapticFeedback.heavyImpact(); // Success haptic
        Navigator.pushAndRemoveUntil(
          context, 
          MaterialPageRoute(builder: (context) => const HomeScreen()), 
          (route) => false
        );
      }
    } catch (e) {
      _showToast("INITIALIZATION FAILED: CHECK DATA");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFD32F2F),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      )
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
            height: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF111111), size: 22),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const Spacer(),
                  _buildHeader(),
                  const SizedBox(height: 40),
                  _buildPanel(),
                  const Spacer(flex: 2),
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
        const Text(
          "SCREENIQUE",
          style: TextStyle(
            color: Color(0xFF111111),
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
            fontSize: 48,
            height: 1.0,
            fontFamily: 'Impact',
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          color: const Color(0xFFD32F2F),
          child: const Text(
            "ESTABLISH IDENTITY",
            style: TextStyle(
              color: Color(0xFFF4F4EC),
              fontSize: 10,
              letterSpacing: 4,
              fontWeight: FontWeight.bold,
            ),
          ),
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
          _buildInput(_nameController, "FULL NAME", Icons.person_outline_rounded),
          const SizedBox(height: 20),
          _buildInput(_emailController, "ARCHIVAL EMAIL", Icons.alternate_email_rounded),
          const SizedBox(height: 20),
          _buildInput(_passwordController, "SECURITY KEY", Icons.lock_open_rounded, isObscure: true),
          const SizedBox(height: 40),
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
        onPressed: _isLoading ? null : _handleSignup,
        child: _isLoading 
          ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Color(0xFFF4F4EC), strokeWidth: 2))
          : const Text("INITIALIZE JOURNEY", 
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
}
