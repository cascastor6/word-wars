import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'data/word_entry.dart';
import 'firebase_options.dart';
import 'presentation/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final definitions = await loadWordEntries();
  runApp(HexWordDuelApp(words: definitions.keys.toSet(), definitions: definitions));
}
