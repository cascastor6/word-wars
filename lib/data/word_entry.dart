import 'dart:convert';

import 'package:flutter/services.dart';

/// A playable word with its part of speech and meaning, from WordNet or
/// Webster's 1913 dictionary.
class WordEntry {
  const WordEntry({required this.word, required this.type, required this.definition});

  WordEntry.fromJson(Map<String, dynamic> j)
    : word = j['word'] as String,
      type = j['type'] as String,
      definition = j['definition'] as String;

  final String word;

  /// noun, verb, adjective, adverb, pronoun, preposition, conjunction,
  /// interjection or article.
  final String type;
  final String definition;

  Map<String, dynamic> toJson() => {'word': word, 'type': type, 'definition': definition};
}

/// Every word in assets/words.json, keyed by the uppercase word. Playable
/// words without a definition aren't in it.
Future<Map<String, WordEntry>> loadWordEntries() async {
  final raw = await rootBundle.loadString('assets/words.json');
  return {
    for (final j in (jsonDecode(raw) as List).cast<Map<String, dynamic>>())
      j['word'] as String: WordEntry.fromJson(j),
  };
}
