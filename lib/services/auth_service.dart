import 'package:flutter/material.dart';//para lo visual 
import 'package:supabase_flutter/supabase_flutter.dart';//paara conectar con supabase
import 'package:google_fonts/google_fonts.dart';//tipografia
import 'package:flutter/foundation.dart';

class AuthService {
  final _client = Supabase.instance.client;

  String get _redirectUrl => kIsWeb
    ? 'https://unpuritan-bryon-psittacistic.ngrok-free.app/'
    : 'io.supabase.jibun://login-callback/';

  Future<void> signInWithGoogle() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: _redirectUrl,
      queryParams: {
        'access_type': 'offline',  // get refresh_token
        'prompt': 'consent',
      },
    );
  }

  Future<void> signInWithGitHub() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.github,
      redirectTo: _redirectUrl,
      scopes: 'read:user user:email',
    );
  }

  Future<void> signInWithApple() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: _redirectUrl,
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get authStateChanges =>
      _client.auth.onAuthStateChange;
}