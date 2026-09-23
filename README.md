# word_wars

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Configuration

Firebase config and URLs live in `.env` (not committed). Copy `.env.example`
to `.env`, fill it in, and pass it to every run and build:

```bash
flutter run --dart-define-from-file=.env
flutter build web --dart-define-from-file=.env
```
