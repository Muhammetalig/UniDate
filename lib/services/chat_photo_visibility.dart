import 'package:cloud_firestore/cloud_firestore.dart';

class ChatPhotoVisibility {
  static Stream<Set<String>> friendsOf(String? viewerId) {
    if (viewerId == null) return Stream.value(<String>{});
    return FirebaseFirestore.instance
        .collection('friendships')
        .where('users', arrayContains: viewerId)
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .expand(
                (doc) =>
                    (doc.data()['users'] as List? ?? []).whereType<String>(),
              )
              .where((id) => id != viewerId)
              .toSet(),
        );
  }

  static String? visibleUrl(
    Map<String, dynamic> userData, {
    required String ownerId,
    required String? viewerId,
    required Set<String> friendIds,
  }) {
    final setting = userData['chatPhotoVisibility'] as String? ?? 'everyone';
    if (ownerId != viewerId &&
        (setting == 'none' ||
            (setting == 'friends' && !friendIds.contains(ownerId)))) {
      return null;
    }

    final images = userData['profileImages'];
    if (images is List && images.isNotEmpty && images.first is String) {
      final url = images.first as String;
      if (url.isNotEmpty) return url;
    }
    final url = userData['profileImageUrl'];
    return url is String && url.isNotEmpty ? url : null;
  }
}
