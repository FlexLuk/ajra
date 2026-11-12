import 'sound_helper_stub.dart' if (dart.library.js_interop) 'sound_helper_web.dart';

void playPlatformChime() {
  playWebChime();
}

void showPlatformWebNotification(String title, String body) {
  showWebNotification(title, body);
}
