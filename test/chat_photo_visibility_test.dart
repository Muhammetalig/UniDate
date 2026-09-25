import 'package:flutter_test/flutter_test.dart';
import 'package:unihub/services/chat_photo_visibility.dart';

void main() {
  const ownerId = 'owner';
  const viewerId = 'viewer';
  const photo = 'https://example.com/photo.jpg';

  String? visibleFor(String? setting, {bool isFriend = false, String? viewer}) {
    return ChatPhotoVisibility.visibleUrl(
      {
        'profileImages': [photo],
        if (setting != null) 'chatPhotoVisibility': setting,
      },
      ownerId: ownerId,
      viewerId: viewer ?? viewerId,
      friendIds: isFriend ? {ownerId} : <String>{},
    );
  }

  test('everyone is the default for existing accounts', () {
    expect(visibleFor(null), photo);
    expect(visibleFor('everyone'), photo);
  });

  test('friends can see the photo only while friendship is accepted', () {
    expect(visibleFor('friends'), isNull);
    expect(visibleFor('friends', isFriend: true), photo);
  });

  test('nobody else can see the photo, but the owner can', () {
    expect(visibleFor('none', isFriend: true), isNull);
    expect(visibleFor('none', viewer: ownerId), photo);
  });

  test('legacy single photo field is supported', () {
    expect(
      ChatPhotoVisibility.visibleUrl(
        {'profileImageUrl': photo},
        ownerId: ownerId,
        viewerId: viewerId,
        friendIds: <String>{},
      ),
      photo,
    );
  });
}
