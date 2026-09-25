import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  GoogleAuthService._();

  static final GoogleAuthService instance = GoogleAuthService._();
  Future<void>? _initialization;

  Future<UserCredential> signIn() async {
    if (kIsWeb) {
      return FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
    }

    _initialization ??= GoogleSignIn.instance.initialize(
      clientId: (Platform.isIOS || Platform.isMacOS)
          ? _optionalEnv('GOOGLE_IOS_CLIENT_ID')
          : null,
      serverClientId: _optionalEnv('GOOGLE_WEB_CLIENT_ID'),
    );
    await _initialization;

    final googleUser = await GoogleSignIn.instance.authenticate();
    final googleAuth = googleUser.authentication;
    final credential = GoogleAuthProvider.credential(idToken: googleAuth.idToken);
    return FirebaseAuth.instance.signInWithCredential(credential);
  }

  /// Creates only missing profile fields; an existing profile is never reset.
  Future<bool> needsUniversity(User user) async {
    final reference = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final snapshot = await reference.get();
    if (!snapshot.exists) {
      final names = (user.displayName ?? '').trim().split(RegExp(r'\s+'));
      await reference.set({
        'email': user.email,
        'firstName': names.first == '' ? '' : names.first,
        'lastName': names.length > 1 ? names.skip(1).join(' ') : '',
        'profileImageUrl': user.photoURL,
        'university': null,
        'department': null,
        'class': null,
        'bio': '',
        'joinedRooms': <String>[],
        'isVerified': true,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    }

    if (snapshot.data()?['isVerified'] != true) {
      await reference.set({'isVerified': true}, SetOptions(merge: true));
    }
    final university = snapshot.data()?['university'] as String?;
    return university == null || university.trim().isEmpty;
  }

  String? _optionalEnv(String key) {
    final value = dotenv.env[key]?.trim();
    return value == null || value.isEmpty ? null : value;
  }
}
