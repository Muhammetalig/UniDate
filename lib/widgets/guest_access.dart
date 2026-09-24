import 'package:flutter/material.dart';
import '../home/home_page.dart';
import '../sign_transactions/login_page.dart';

/// Temporary guest browsing without creating a Firebase account.
class GuestAccessButton extends StatelessWidget {
  const GuestAccessButton({super.key});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      icon: const Icon(Icons.person_outline),
      label: const Text('Misafir olarak devam et'),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const HomePage()),
      ),
    );
  }
}

class GuestAccountPrompt extends StatelessWidget {
  final String title;

  const GuestAccountPrompt({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_outline, size: 64),
              const SizedBox(height: 16),
              const Text('Misafir olarak geziniyorsunuz.',
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text(
                'Mesajlaşmak, arkadaş eklemek ve profil oluşturmak için giriş yapın. Herhangi bir e-posta adresiyle kayıt olabilirsiniz.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute<void>(builder: (_) => const LoginPage()),
                  (route) => route.isFirst,
                ),
                child: const Text('Giriş Yap / Kayıt Ol'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
