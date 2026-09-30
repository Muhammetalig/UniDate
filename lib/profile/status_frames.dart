import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Profil fotoğrafının dışına yerleşen yazılı durum çerçevesi.
class StatusFrame {
  final String id;
  final String label;
  final Color color;

  const StatusFrame(this.id, this.label, this.color);

  static const all = [
    StatusFrame('friends', 'ARKADAŞ ARIYORUM', Color(0xFF2563EB)),
    StatusFrame('relationship', 'İLİŞKİYE AÇIĞIM', Color(0xFFC026D3)),
    StatusFrame('available', 'BUGÜN MÜSAİTİM', Color(0xFF16A34A)),
    StatusFrame('bored', 'CANIM SIKILIYOR, MESAJ AT', Color(0xFFEA580C)),
  ];

  static StatusFrame? byId(String? id) {
    for (final frame in all) {
      if (frame.id == id) return frame;
    }
    return null;
  }
}

/// Firestore'daki `statusFrames` ve `statusFrameShown` alanlarının okunmuş hali.
/// Durumlar kullanıcı kapatana kadar açık kalır; süre sınırı yoktur.
class StatusFrameSelection {
  /// Açık durumlar, [StatusFrame.all] sırasıyla.
  final List<StatusFrame> active;

  /// Fotoğrafta gösterilen çerçeve; açık durum yoksa null.
  final StatusFrame? shown;

  const StatusFrameSelection._(this.active, this.shown);

  factory StatusFrameSelection.of(Iterable<String> activeIds, String? shownId) {
    final ids = activeIds.toSet();
    final active = StatusFrame.all.where((f) => ids.contains(f.id)).toList();
    final preferred = StatusFrame.byId(shownId);
    final shown = preferred != null && active.contains(preferred)
        ? preferred
        : (active.isEmpty ? null : active.first);
    return StatusFrameSelection._(active, shown);
  }

  factory StatusFrameSelection.fromUserData(Map<String, dynamic>? data) {
    final raw = data?['statusFrames'];
    return StatusFrameSelection.of(
      raw is List ? raw.whereType<String>() : const <String>[],
      data?['statusFrameShown'] as String?,
    );
  }

  /// Fotoğrafın altında küçük etiket olarak gösterilecek diğer açık durumlar.
  List<StatusFrame> get others => active.where((f) => f != shown).toList();

  Map<String, dynamic> toFirestore() => {
    'statusFrames': active.map((f) => f.id).toList(),
    'statusFrameShown': shown?.id,
  };
}

/// Fotoğrafı küçültmeden etrafına yarı şeffaf bir halka çizer; yazı halkanın
/// alt kısmında, fotoğrafın dışında kalır.
class StatusFramedAvatar extends StatelessWidget {
  final Widget avatar;
  final double avatarSize;
  final StatusFrame? frame;

  static const double ringWidth = 17;

  const StatusFramedAvatar({
    super.key,
    required this.avatar,
    required this.avatarSize,
    this.frame,
  });

  @override
  Widget build(BuildContext context) {
    final frame = this.frame;
    if (frame == null) return avatar;
    final size = avatarSize + ringWidth * 2;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _StatusRingPainter(
                frame,
                DefaultTextStyle.of(context).style.fontFamily,
              ),
            ),
          ),
          avatar,
        ],
      ),
    );
  }
}

class _StatusRingPainter extends CustomPainter {
  final StatusFrame frame;
  final String? fontFamily;

  _StatusRingPainter(this.frame, this.fontFamily);

  static const _letterGap = 0.9;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    const ring = StatusFramedAvatar.ringWidth;
    final radius = size.width / 2 - ring / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ring
        ..color = frame.color.withValues(alpha: 0.45),
    );
    // İnce dış kenar: aynı renkteki kapak fotoğrafında da halka seçilsin.
    canvas.drawCircle(
      center,
      size.width / 2 - 0.75,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: 0.7),
    );

    final letters = [
      for (final char in frame.label.characters)
        TextPainter(
          text: TextSpan(
            text: char,
            style: TextStyle(
              fontFamily: fontFamily,
              color: Colors.white,
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              shadows: [Shadow(color: Colors.black38, blurRadius: 2)],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(),
    ];
    final textWidth =
        letters.fold<double>(0, (sum, l) => sum + l.width) +
        _letterGap * (letters.length - 1);
    final textSweep = textWidth / radius;

    // Yazının arkasındaki bölüm biraz daha koyu, okunabilirlik için.
    const pad = 0.18;
    canvas.drawArc(
      rect,
      math.pi / 2 - textSweep / 2 - pad,
      textSweep + pad * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ring
        ..strokeCap = StrokeCap.round
        ..color = frame.color.withValues(alpha: 0.8),
    );

    // Alt yay boyunca soldan sağa: açı π/2'nin solundan sağına azalır.
    var angle = math.pi / 2 + textSweep / 2;
    for (final letter in letters) {
      final charAngle = angle - (letter.width / 2) / radius;
      canvas.save();
      canvas.translate(
        center.dx + radius * math.cos(charAngle),
        center.dy + radius * math.sin(charAngle),
      );
      canvas.rotate(charAngle - math.pi / 2);
      letter.paint(canvas, Offset(-letter.width / 2, -letter.height / 2));
      canvas.restore();
      angle -= (letter.width + _letterGap) / radius;
    }
  }

  @override
  bool shouldRepaint(_StatusRingPainter oldDelegate) =>
      oldDelegate.frame != frame || oldDelegate.fontFamily != fontFamily;
}

/// Fotoğrafın altında gösterilen küçük durum etiketi.
class StatusFrameTag extends StatelessWidget {
  final StatusFrame frame;

  const StatusFrameTag(this.frame, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: frame.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: frame.color.withValues(alpha: 0.5)),
      ),
      child: Text(
        frame.label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: frame.color,
        ),
      ),
    );
  }
}

/// "Durumum ve çerçevem" düzenleme ekranı. Kaydedilirse yeni seçimi döndürür.
Future<StatusFrameSelection?> showStatusFrameEditor(
  BuildContext context, {
  required Widget avatar,
  required double avatarSize,
  required StatusFrameSelection initial,
}) {
  final activeIds = initial.active.map((f) => f.id).toSet();
  String? shownId = initial.shown?.id;

  return showModalBottomSheet<StatusFrameSelection>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) {
        final selection = StatusFrameSelection.of(activeIds, shownId);
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Durumum ve çerçevem',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Açtığın durumlar sen kapatana kadar profilinde görünür.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                // Önizleme
                Center(
                  child: StatusFramedAvatar(
                    avatar: avatar,
                    avatarSize: avatarSize,
                    frame: selection.shown,
                  ),
                ),
                if (selection.others.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final f in selection.others) StatusFrameTag(f),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                for (final frame in StatusFrame.all)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: CircleAvatar(
                      radius: 8,
                      backgroundColor: frame.color,
                    ),
                    title: Text(frame.label),
                    activeTrackColor: frame.color,
                    value: activeIds.contains(frame.id),
                    onChanged: (on) => setSheetState(() {
                      if (on) {
                        activeIds.add(frame.id);
                        // İlk açılan durum doğrudan fotoğrafa gelsin.
                        if (selection.shown == null) shownId = frame.id;
                      } else {
                        activeIds.remove(frame.id);
                      }
                    }),
                  ),
                if (selection.active.length > 1) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Fotoğrafta görünecek çerçeve',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final frame in selection.active)
                        ChoiceChip(
                          label: Text(frame.label),
                          selected: selection.shown == frame,
                          selectedColor: frame.color.withValues(alpha: 0.2),
                          onSelected: (_) =>
                              setSheetState(() => shownId = frame.id),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(sheetContext, selection),
                  child: const Text('Kaydet'),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
