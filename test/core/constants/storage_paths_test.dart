import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/constants/storage_paths.dart';

void main() {
  test('StoragePaths.chatAudios está definido', () {
    expect(StoragePaths.chatAudios, 'chat_audios');
  });
}
