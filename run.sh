#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"

flutter run -d chrome --dart-define-from-file=.env
