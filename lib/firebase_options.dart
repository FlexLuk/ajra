// Configuration Firebase pour AJRA
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return web;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDemoKeyAjraMauritius2026',
    appId: '1:100000000000:web:ajra0000000000',
    messagingSenderId: '100000000000',
    projectId: 'ajra-app',
    authDomain: 'ajra-app.firebaseapp.com',
    storageBucket: 'ajra-app.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDemoKeyAjraMauritius2026',
    appId: '1:100000000000:android:ajra0000000000',
    messagingSenderId: '100000000000',
    projectId: 'ajra-app',
    storageBucket: 'ajra-app.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDemoKeyAjraMauritius2026',
    appId: '1:100000000000:ios:ajra0000000000',
    messagingSenderId: '100000000000',
    projectId: 'ajra-app',
    storageBucket: 'ajra-app.appspot.com',
    iosBundleId: 'com.ajra.ajra',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDemoKeyAjraMauritius2026',
    appId: '1:100000000000:ios:ajra0000000000',
    messagingSenderId: '100000000000',
    projectId: 'ajra-app',
    storageBucket: 'ajra-app.appspot.com',
    iosBundleId: 'com.ajra.ajra',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDemoKeyAjraMauritius2026',
    appId: '1:100000000000:web:ajra0000000000',
    messagingSenderId: '100000000000',
    projectId: 'ajra-app',
    authDomain: 'ajra-app.firebaseapp.com',
    storageBucket: 'ajra-app.appspot.com',
  );
}
