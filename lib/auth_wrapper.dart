import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:unihub/sign_transactions/start_up_page.dart';
import 'package:unihub/home/home_page.dart';
import 'package:unihub/services/notification_service.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Bağlantı durumu kontrol ediliyor
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
              ),
            ),
          );
        }
        
        // Kullanıcı oturum açmışsa ana sayfaya yönlendir
        if (snapshot.hasData && snapshot.data != null) {
          // Kullanıcı giriş yaptığında FCM token'ı kaydet
          NotificationService.instance.onUserLogin();
          return const HomePage();
        }
        
        // Kullanıcı oturum açmamışsa başlangıç sayfasına yönlendir
        return const StartupScreen();
      },
    );
  }
}