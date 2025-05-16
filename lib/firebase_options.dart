import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Update these with your Firebase project details from the Firebase console.
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
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // Replace the following with your Firebase project credentials

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC9elxmOQWScMLTKiiLDVCz5yhzLBrTVCI',
    appId: '1:1027925552365:android:55a0b1b77442e947d3b0e4',
    messagingSenderId: '1027925552365',
    projectId: 'hisabkitab-45625',
    storageBucket: 'hisabkitab-45625.firebasestorage.app',
  );

  // Use values from google-services.json for Android

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAJiKtUG2Q0Piodoa6SFcR495zXexYBPsc',
    appId: '1:1027925552365:ios:801c489bf2eb89c8d3b0e4',
    messagingSenderId: '1027925552365',
    projectId: 'hisabkitab-45625',
    storageBucket: 'hisabkitab-45625.firebasestorage.app',
    iosBundleId: 'com.example.hisabkitab',
  );

  // Use values from GoogleService-Info.plist for iOS

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAJiKtUG2Q0Piodoa6SFcR495zXexYBPsc',
    appId: '1:1027925552365:ios:801c489bf2eb89c8d3b0e4',
    messagingSenderId: '1027925552365',
    projectId: 'hisabkitab-45625',
    storageBucket: 'hisabkitab-45625.firebasestorage.app',
    iosBundleId: 'com.example.hisabkitab',
  );

  // Use values from GoogleService-Info.plist for macOS

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBIz2eqm20dPzaDkUQ59npDWgFm_89sa60',
    appId: '1:1027925552365:web:f5e60fdf5843ae97d3b0e4',
    messagingSenderId: '1027925552365',
    projectId: 'hisabkitab-45625',
    authDomain: 'hisabkitab-45625.firebaseapp.com',
    storageBucket: 'hisabkitab-45625.firebasestorage.app',
    measurementId: 'G-M2QS21X00S',
  );

  // Use values from Firebase console for web app

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBIz2eqm20dPzaDkUQ59npDWgFm_89sa60',
    appId: '1:1027925552365:web:dd4a224113678f4bd3b0e4',
    messagingSenderId: '1027925552365',
    projectId: 'hisabkitab-45625',
    authDomain: 'hisabkitab-45625.firebaseapp.com',
    storageBucket: 'hisabkitab-45625.firebasestorage.app',
    measurementId: 'G-9XQTZ6GM6J',
  );

}