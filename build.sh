#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"

flutter build web --release --dart-define-from-file=.env
firebase deploy
flutter build apk --release --dart-define-from-file=.env
