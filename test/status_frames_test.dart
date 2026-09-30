import 'package:flutter_test/flutter_test.dart';
import 'package:unihub/profile/status_frames.dart';

void main() {
  List<String> ids(List<StatusFrame> frames) =>
      frames.map((f) => f.id).toList();

  test('no frame for existing accounts without the fields', () {
    final selection = StatusFrameSelection.fromUserData({'firstName': 'Ali'});
    expect(selection.active, isEmpty);
    expect(selection.shown, isNull);
    expect(selection.others, isEmpty);
  });

  test('chosen frame is shown and the rest become tags', () {
    final selection = StatusFrameSelection.fromUserData({
      'statusFrames': ['bored', 'friends', 'available'],
      'statusFrameShown': 'available',
    });
    expect(ids(selection.active), ['friends', 'available', 'bored']);
    expect(selection.shown?.id, 'available');
    expect(ids(selection.others), ['friends', 'bored']);
  });

  test('falls back to the first active frame if the chosen one is off', () {
    final selection = StatusFrameSelection.of(['relationship'], 'friends');
    expect(selection.shown?.id, 'relationship');
    expect(selection.others, isEmpty);
  });

  test('unknown ids are ignored', () {
    final selection = StatusFrameSelection.of(['old', 'friends'], 'old');
    expect(ids(selection.active), ['friends']);
    expect(selection.shown?.id, 'friends');
  });

  test('round-trips through Firestore fields', () {
    final fields = StatusFrameSelection.of([
      'available',
      'friends',
    ], 'available').toFirestore();
    expect(fields, {
      'statusFrames': ['friends', 'available'],
      'statusFrameShown': 'available',
    });
    final none = StatusFrameSelection.of(const [], null).toFirestore();
    expect(none, {'statusFrames': <String>[], 'statusFrameShown': null});
  });
}
