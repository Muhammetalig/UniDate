import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class PrivacySettingsPage extends StatefulWidget {
  const PrivacySettingsPage({super.key});

  @override
  State<PrivacySettingsPage> createState() => _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends State<PrivacySettingsPage> {
  final User? user = FirebaseAuth.instance.currentUser;
  bool isLoading = true;

  // Privacy settings
  bool hideFromOtherUniversities = false;
  String messagePrivacy = 'everyone'; // everyone, friends, none
  String profilePrivacy = 'public';   // public, friends

  @override
  void initState() {
    super.initState();
    _loadPrivacySettings();
  }

  Future<void> _loadPrivacySettings() async {
    if (user == null) return;

    setState(() => isLoading = true);

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        setState(() {
          hideFromOtherUniversities = data['hideFromOtherUniversities'] ?? false;
          messagePrivacy = data['messagePrivacy'] ?? 'everyone';
          profilePrivacy = data['profilePrivacy'] ?? 'public';
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint('privacy_settings: Gizlilik ayarları yüklenirken hata: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _updatePrivacySetting(String field, dynamic value) async {
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .update({field: value});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ayar güncellendi'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Gizlilik Ayarları'),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        elevation: 0,
        automaticallyImplyLeading: true,
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // University visibility
                  _buildSettingSection(
                    'Üniversite Dışı Görünürlük',
                    'Profilinizi aynı üniversite dışındaki kullanıcılara gösterme',
                    FontAwesomeIcons.school,
                    SwitchListTile(
                      value: hideFromOtherUniversities,
                      onChanged: (value) {
                        setState(() => hideFromOtherUniversities = value);
                        _updatePrivacySetting('hideFromOtherUniversities', value);
                      },
                      title: Text(
                        hideFromOtherUniversities
                            ? 'Sadece üniversitem görebilir'
                            : 'Herkes görebilir',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Message privacy
                  _buildSettingSection(
                    'Kimlerin Mesaj Atabileceğini Seç',
                    'Mesaj gönderebilecek kişileri belirleyin',
                    FontAwesomeIcons.message,
                    Column(
                      children: [
                        _buildPrivacyOption(
                          context,
                          icon: FontAwesomeIcons.globe,
                          title: 'Herkes',
                          value: 'everyone',
                          groupValue: messagePrivacy,
                          onChanged: (value) {
                            setState(() => messagePrivacy = value!);
                            _updatePrivacySetting('messagePrivacy', value);
                          },
                        ),
                        const SizedBox(height: 8),
                        _buildPrivacyOption(
                          context,
                          icon: FontAwesomeIcons.users,
                          title: 'Arkadaşlar',
                          value: 'friends',
                          groupValue: messagePrivacy,
                          onChanged: (value) {
                            setState(() => messagePrivacy = value!);
                            _updatePrivacySetting('messagePrivacy', value);
                          },
                        ),
                        const SizedBox(height: 8),
                        _buildPrivacyOption(
                          context,
                          icon: FontAwesomeIcons.ban,
                          title: 'Hiç Kimse',
                          value: 'none',
                          groupValue: messagePrivacy,
                          onChanged: (value) {
                            setState(() => messagePrivacy = value!);
                            _updatePrivacySetting('messagePrivacy', value);
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Profile privacy
                  _buildSettingSection(
                    'Profil Gizliliği',
                    'Profilinizi kimlerin görüntüleyebileceğini seçin',
                    FontAwesomeIcons.user,
                    Column(
                      children: [
                        _buildPrivacyOption(
                          context,
                          icon: FontAwesomeIcons.globe,
                          title: 'Herkese Açık',
                          value: 'public',
                          groupValue: profilePrivacy,
                          onChanged: (value) {
                            setState(() => profilePrivacy = value!);
                            _updatePrivacySetting('profilePrivacy', value);
                          },
                        ),
                        const SizedBox(height: 8),
                        _buildPrivacyOption(
                          context,
                          icon: FontAwesomeIcons.users,
                          title: 'Arkadaşlar',
                          value: 'friends',
                          groupValue: profilePrivacy,
                          onChanged: (value) {
                            setState(() => profilePrivacy = value!);
                            _updatePrivacySetting('profilePrivacy', value);
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Info box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FaIcon(
                          FontAwesomeIcons.info,
                          color: theme.brightness == Brightness.dark
                              ? Colors.blue[400]
                              : Colors.blue[700],
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Gizlilik ayarlarınız anında aktif olur. Bu ayarlar profilinizin ve mesajlarınızın görünürlüğünü kontrol eder.',
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.brightness == Brightness.dark
                                  ? Colors.blue[300]
                                  : Colors.blue[700],
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPrivacyOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required String groupValue,
    required ValueChanged<String?> onChanged,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isSelected = value == groupValue;

    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2563EB).withValues(alpha: 0.1)
              : (isDark ? const Color(0xFF1F1F1F) : Colors.grey[100]),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF2563EB)
                : (isDark ? const Color(0xFF2D2D2D) : Colors.grey[300]!),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            FaIcon(
              FontAwesomeIcons.globe,
              color: isSelected
                  ? const Color(0xFF2563EB)
                  : (isDark ? Colors.grey[400] : Colors.grey[600]),
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? (isDark ? Colors.white : Colors.black)
                      : (isDark ? Colors.grey[300] : Colors.grey[800]),
                ),
              ),
            ),
            if (isSelected)
              const FaIcon(
                FontAwesomeIcons.circleCheck,
                color: Color(0xFF2563EB),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingSection(
    String title,
    String description,
    IconData icon,
    Widget content,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFE5E7EB),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: FaIcon(
                  icon,
                  color: const Color(0xFF2563EB),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          content,
        ],
      ),
    );
  }
}