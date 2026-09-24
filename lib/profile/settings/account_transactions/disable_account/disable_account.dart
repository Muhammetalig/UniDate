import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:unihub/sign_transactions/login_page.dart';

class DisableAccountPage extends StatefulWidget {
  const DisableAccountPage({super.key});

  @override
  State<DisableAccountPage> createState() => _DisableAccountPageState();
}

class _DisableAccountPageState extends State<DisableAccountPage> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String? _selectedReason;

  final List<String> _reasons = [
    'Geçici olarak ara vermek istiyorum',
    'Gizlilik endişelerim var',
    'Uygulama ihtiyacımı karşılamıyor',
    'Çok fazla bildirim alıyorum',
    'Başka bir hesap oluşturacağım',
    'Diğer',
  ];

  Future<void> _disableAccount() async {
    if (_passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen şifrenizi giriniz'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen bir neden seçiniz'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hesabı Devre Dışı Bırak'),
        content: const Text(
          'Hesabınızı devre dışı bırakmak istediğinizden emin misiniz?\n\n'
          'Hesabınız devre dışı bırakıldığında:\n'
          '• Profiliniz diğer kullanıcılara görünmeyecek\n'
          '• Mesajlaşma yapamayacaksınız\n'
          '• Odalara katılamayacaksınız\n\n'
          'Hesabınızı istediğiniz zaman yeniden aktif edebilirsiniz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Devre Dışı Bırak'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.email != null) {
        // Şifre ile yeniden kimlik doğrulama
        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: _passwordController.text,
        );

        await user.reauthenticateWithCredential(credential);

        // Firestore'da hesabı devre dışı bırak
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'isDisabled': true,
          'disabledAt': FieldValue.serverTimestamp(),
          'disableReason': _selectedReason,
          'disableNote': _reasonController.text.trim(),
        });

        // Çıkış yap
        await FirebaseAuth.instance.signOut();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Hesabınız başarıyla devre dışı bırakıldı'),
              backgroundColor: Colors.green,
            ),
          );

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
            (route) => false,
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Bir hata oluştu';
      
      switch (e.code) {
        case 'wrong-password':
          errorMessage = 'Şifre yanlış';
          break;
        case 'requires-recent-login':
          errorMessage = 'Bu işlem için yeniden giriş yapmalısınız';
          break;
        default:
          errorMessage = 'Bir hata oluştu: ${e.message}';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Beklenmeyen bir hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Hesabını Devre Dışı Bırak'),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        elevation: 0,
        automaticallyImplyLeading: true,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Warning card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: isDark ? Colors.orange[400] : Colors.orange[700],
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dikkat!',
                          style: TextStyle(
                            color: isDark ? Colors.orange[300] : Colors.orange[900],
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Hesabınızı devre dışı bıraktığınızda profiliniz görünmez olacak ve uygulama özelliklerini kullanamazsınız. İstediğiniz zaman tekrar giriş yaparak hesabınızı aktif edebilirsiniz.',
                          style: TextStyle(
                            color: isDark ? Colors.orange[200] : Colors.orange[800],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Reason selection
            Text(
              'Neden devre dışı bırakmak istiyorsunuz?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 12),
            
            ..._reasons.map((reason) {
              final isSelected = _selectedReason == reason;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF2563EB)
                        : (isDark ? const Color(0xFF2D2D2D) : const Color(0xFFE5E7EB)),
                    width: isSelected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  color: theme.cardColor,
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  leading: Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: isSelected ? const Color(0xFF2563EB) : (isDark ? Colors.grey[600] : const Color(0xFF9CA3AF)),
                  ),
                  title: Text(
                    reason,
                    style: TextStyle(
                      fontSize: 15,
                      color: theme.textTheme.bodyLarge?.color,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  onTap: () {
                    setState(() {
                      // toggleable davranış: aynı seçenek tekrar seçilirse kaldır
                      _selectedReason = isSelected ? null : reason;
                    });
                  },
                ),
              );
            }),

            const SizedBox(height: 20),

            // Additional notes
            if (_selectedReason == 'Diğer') ...[
              Text(
                'Ek Açıklama (İsteğe bağlı)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFE5E7EB),
                  ),
                  borderRadius: BorderRadius.circular(8),
                  color: theme.cardColor,
                ),
                child: TextFormField(
                  controller: _reasonController,
                  maxLines: 3,
                  maxLength: 200,
                  style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                  decoration: InputDecoration(
                    hintText: 'Nedeninizi bizimle paylaşın (isteğe bağlı)',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.grey[600] : const Color(0xFF9CA3AF),
                      fontSize: 16,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Password field
            Text(
              'Şifrenizi Girin',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFE5E7EB),
                ),
                borderRadius: BorderRadius.circular(8),
                color: theme.cardColor,
              ),
              child: TextFormField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                decoration: InputDecoration(
                  hintText: 'Onaylamak için şifrenizi giriniz',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.grey[600] : const Color(0xFF9CA3AF),
                    fontSize: 16,
                  ),
                  prefixIcon: Icon(
                    Icons.lock_outline,
                    color: isDark ? Colors.grey[600] : const Color(0xFF9CA3AF),
                    size: 20,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: isDark ? Colors.grey[600] : const Color(0xFF9CA3AF),
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // What happens section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: isDark ? Border.all(
                  color: const Color(0xFF2D2D2D),
                ) : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hesabınız devre dışı bırakıldığında:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoItem('Profiliniz diğer kullanıcılara görünmeyecek', isDark),
                  _buildInfoItem('Mesajlaşma yapamayacaksınız', isDark),
                  _buildInfoItem('Odalara katılamayacaksınız', isDark),
                  _buildInfoItem('Bildirim almayacaksınız', isDark),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: isDark ? Colors.blue[400] : Colors.blue[700],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Hesabınız kalıcı olarak silinmeyecek, tekrar giriş yaparak aktif edebilirsiniz.',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.blue[300] : Colors.blue[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Disable button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _disableAccount,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Hesabımı Devre Dışı Bırak',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.close,
            size: 16,
            color: isDark ? Colors.red[400] : Colors.red[700],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[400] : Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

