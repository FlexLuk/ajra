import 'dart:js_interop';

@JS('playNotificationChime')
external void _playNotificationChime();

@JS('showBrowserNotification')
external void _showBrowserNotification(JSString title, JSString body);

void playWebChime() {
  try {
    _playNotificationChime();
  } catch (_) {}
}

void showWebNotification(String title, String body) {
  try {
    _showBrowserNotification(title.toJS, body.toJS);
  } catch (_) {}
}
