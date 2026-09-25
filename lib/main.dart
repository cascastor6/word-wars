import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'firebase_options.dart';
import 'presentation/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final raw = await rootBundle.loadString('assets/words.txt');
  final words = raw.split('\n').map((w) => w.trim()).where((w) => w.isNotEmpty).toSet();
  runApp(HexWordDuelApp(words: words));
}
