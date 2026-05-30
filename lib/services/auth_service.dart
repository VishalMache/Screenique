import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Stream to listen to auth state changes (Used by your AuthWrapper in main.dart)
  Stream<User?> get user => _auth.authStateChanges();

  // Sign In with Email and Password
  Future<UserCredential?> signIn(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email, 
        password: password
      );
    } on FirebaseAuthException catch (e) {
      // You can print specific error codes here for debugging
      print("Login Error: ${e.code}");
      return null;
    }
  }

  // Sign Up with Email and Password
  Future<UserCredential?> signUp(String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email, 
        password: password
      );
    } on FirebaseAuthException catch (e) {
      print("Signup Error: ${e.code}");
      return null;
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
  }
// lib/services/auth_service.dart

Future<void> sendPasswordResetEmail(String email) async {
  try {
    await _auth.sendPasswordResetEmail(email: email);
  } on FirebaseAuthException catch (e) {
    print("Reset Error: ${e.code}");
    throw e; // Pass the error back to the UI
  }
}
}