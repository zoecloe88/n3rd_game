#!/usr/bin/env dart
// Script to upload MP4 video assets to Firebase Storage
// Run with: dart scripts/upload_videos_to_firebase.dart

import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  print('🚀 Uploading MP4 video files to Firebase Storage...\n');

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyAv1x4IfDQuaRLWJSjxSsNy5Aai1F260So',
        appId: '1:68201275359:ios:98246017c23c3fe3dd6e6a',
        messagingSenderId: '68201275359',
        projectId: 'wordn3rd-7bd5d',
        storageBucket: 'wordn3rd-7bd5d.firebasestorage.app',
      ),
    );
  } catch (e) {
    print('❌ Failed to initialize Firebase: $e');
    print('\n💡 Alternative: Use Firebase Console to upload manually:');
    print('   https://console.firebase.google.com/project/wordn3rd-7bd5d/storage');
    exit(1);
  }

  final storage = FirebaseStorage.instance;
  final assetsDir = Directory('assets');
  
  if (!assetsDir.existsSync()) {
    print('❌ Assets directory not found!');
    exit(1);
  }

  // List of MP4 files to upload
  final videos = [
    'loginscreen.mp4',
    'titlescreen.mp4',
    'settingscreen.mp4',
    'statscreen.mp4',
    'modeselectionscreen.mp4',
    'modeselection2.mp4',
    'modeselection3.mp4',
    'modeselectiontransitionscreen.mp4',
    'wordoftheday.mp4',
    'edition.mp4',
    'youthscreen.mp4',
    'logoloadingscreen.mp4',
  ];

  int successCount = 0;
  int failCount = 0;

  for (final video in videos) {
    final file = File('${assetsDir.path}/$video');
    
    if (!file.existsSync()) {
      print('⚠️  File not found: $video');
      failCount++;
      continue;
    }

    try {
      print('📹 Uploading $video...');
      final ref = storage.ref('public/videos/$video');
      await ref.putFile(file);
      
      final url = await ref.getDownloadURL();
      print('   ✅ Uploaded: $url');
      successCount++;
    } catch (e) {
      print('   ❌ Failed to upload $video: $e');
      failCount++;
    }
  }

  print('\n📊 Summary:');
  print('   ✅ Success: $successCount');
  print('   ❌ Failed: $failCount');
  print('\n📝 Files are accessible at:');
  print('   gs://wordn3rd-7bd5d.firebasestorage.app/public/videos/[filename]');
  print('\n💡 View in Firebase Console:');
  print('   https://console.firebase.google.com/project/wordn3rd-7bd5d/storage');
}

