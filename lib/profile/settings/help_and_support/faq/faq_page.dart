import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class FAQPage extends StatefulWidget {
  const FAQPage({super.key});

  @override
  State<FAQPage> createState() => _FAQPageState();
}

class _FAQPageState extends State<FAQPage> {
  int? _expandedIndex;

  final List<Map<String, String>> _faqs = [
    {
      'question': 'UniHub nedir?',
      'answer':
          'UniHub, üniversite öğrencilerinin kampüste birlikte çalışma, sosyalleşme ve kaynak paylaşımı yapabilecekleri bir platformdur. Öğrenciler odalar oluşturabilir, arkadaşlarıyla iletişim kurabilir ve kampüs etkinliklerini takip edebilirler.',
    },
    {
      'question': 'Oda nasıl oluşturabilirim?',
      'answer':
          'Ana sayfadaki harita üzerinde istediğiniz konumu seçin ve "Oda Oluştur" butonuna tıklayın. Oda ismini, açıklamasını ve katılımcı sayısını belirleyin. Oluşturduğunuz oda harita üzerinde görünür olacaktır.',
    },
    {
      'question': 'Arkadaş nasıl ekleyebilirim?',
      'answer':
          'Profilinde arkadaş eklemek istediğiniz kişiyi bulun ve "Arkadaş Ekle" butonuna tıklayın. Diğer kişi isteği kabul ettiğinde arkadaş listenize eklenecektir.',
    },
    {
      'question': 'Bildirimlerimi nasıl yönetebilirim?',
      'answer':
          'Ayarlar > Bildirimler bölümünden mesaj bildirimleri, oda davetleri, arkadaşlık istekleri ve sistem bildirimlerini açıp kapatabilirsiniz.',
    },
    {
      'question': 'Profilimi nasıl düzenleyebilirim?',
      'answer':
          'Profil sayfanıza gidin ve "Düzenle" butonuna tıklayın. Profil fotoğrafınızı, adınızı, hakkınızda bilgisini ve sosyal medya hesaplarınızı güncelleyebilirsiniz.',
    },
    {
      'question': 'Hesabımı nasıl silebilirim?',
      'answer':
          'Ayarlar > Hesabın > Hesabı Sil bölümünden hesabınızı kalıcı olarak silebilirsiniz. Bu işlem geri alınamaz ve tüm verileriniz silinecektir.',
    },
    {
      'question': 'Birini nasıl engelleyebilirim?',
      'answer':
          'Engellemek istediğiniz kişinin profiline gidin ve sağ üstteki menüden "Engelle" seçeneğini seçin. Ya da Ayarlar > Güvenlik & Gizlilik > Engellenen Kullanıcılar bölümünden yönetebilirsiniz.',
    },
    {
      'question': 'Şifremi unuttum, ne yapmalıyım?',
      'answer':
          'Giriş ekranında "Şifremi Unuttum" linkine tıklayın. E-posta adresinizi girin ve size gönderilen link ile şifrenizi sıfırlayabilirsiniz.',
    },
    {
      'question': 'Gizlilik ayarlarım neler?',
      'answer':
          'Ayarlar > Güvenlik & Gizlilik > Gizlilik Ayarları bölümünden profilinizin görünürlüğünü, kimler mesaj gönderebileceğini ve konum paylaşımı gibi ayarları yönetebilirsiniz.',
    },
    {
      'question': 'Uygulamada hata bulursam ne yapmalıyım?',
      'answer':
          'Yardım & Destek > Yardım Talebi Oluştur bölümünden karşılaştığınız sorunu bizimle paylaşabilirsiniz. Ekibimiz en kısa sürede size dönüş yapacaktır.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Sık Sorulan Sorular'),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        elevation: 0,
        automaticallyImplyLeading: true,
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const FaIcon(
                      FontAwesomeIcons.circleInfo,
                      color: Color(0xFF2563EB),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Aradığınızı bulamadınız mı? Yardım talebi oluşturabilirsiniz.',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white : const Color(0xFF2D3748),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // FAQ items
              ...List.generate(_faqs.length, (index) {
                final faq = _faqs[index];
                final isExpanded = _expandedIndex == index;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _expandedIndex = isExpanded ? null : index;
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  faq['question']!,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF2D3748),
                                  ),
                                ),
                              ),
                              FaIcon(
                                isExpanded
                                    ? FontAwesomeIcons.chevronUp
                                    : FontAwesomeIcons.chevronDown,
                                size: 14,
                                color: const Color(0xFF2563EB),
                              ),
                            ],
                          ),
                          if (isExpanded) ...[
                            const SizedBox(height: 12),
                            Container(
                              height: 1,
                              color: theme.dividerColor,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              faq['answer']!,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.5,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
