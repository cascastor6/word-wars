import 'package:flutter/material.dart';

import 'package:word_wars/data/online.dart';

/// Asks for a game code or invite link and returns the code, or null if none was given.
Future<String?> showJoinCodeDialog(BuildContext context) async {
  final ctl = TextEditingController();
  final code = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Join a game'),
      content: TextField(
        controller: ctl,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(hintText: 'Game code or link'),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, ctl.text), child: const Text('Join')),
      ],
    ),
  );
  if (code == null || code.trim().isEmpty) return null;
  final t = code.trim();
  return t.contains('/') ? codeFromLink(Uri.parse(t)) : t.toUpperCase();
}
