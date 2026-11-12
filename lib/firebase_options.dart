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
    apiKey: 'AIzaSyDpL4tWPo-VNHgps40HyHuhX1lRHrIpByY',
    appId: '1:682841193589:web:4e19112847e42844ce8c3c',
    messagingSenderId: '682841193589',
    projectId: 'ajra-app-8ae42',
    authDomain: 'ajra-app-8ae42.firebaseapp.com',
    storageBucket: 'ajra-app-8ae42.firebasestorage.app',
    measurementId: 'G-CSVP28B886',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD0WcZ07RA8LVnkapjN70jOEcJS20Xs-1Q',
    appId: '1:682841193589:android:430950f6072bc9b5ce8c3c',
    messagingSenderId: '682841193589',
    projectId: 'ajra-app-8ae42',
    storageBucket: 'ajra-app-8ae42.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCbpYDRkv3joHgpxEF4hbpU1C5rTz9dzKw',
    appId: '1:682841193589:ios:059f93e67a9db3d6ce8c3c',
    messagingSenderId: '682841193589',
    projectId: 'ajra-app-8ae42',
    storageBucket: 'ajra-app-8ae42.firebasestorage.app',
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
    apiKey: 'AIzaSyDpL4tWPo-VNHgps40HyHuhX1lRHrIpByY',
    appId: '1:682841193589:web:845470d6dea3aa9ece8c3c',
    messagingSenderId: '682841193589',
    projectId: 'ajra-app-8ae42',
    authDomain: 'ajra-app-8ae42.firebaseapp.com',
    storageBucket: 'ajra-app-8ae42.firebasestorage.app',
    measurementId: 'G-0NC2ZHXM9X',
  );
}
