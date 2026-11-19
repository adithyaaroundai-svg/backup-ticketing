#!/bin/bash
# This script creates a .env file so that `flutter build web` doesn't crash on Vercel.
# We add a dummy variable so the file is not 0 bytes, ensuring Flutter bundles it.
echo "BUILD_PLATFORM=VERCEL" > .env

# Pin Flutter SDK to 3.41.6 (matching local development environment)
# This prevents upstream Flutter updates (like Dart 3.14 / Flutter 3.50) from breaking dependencies.
if [ -d "flutter" ]; then
  cd flutter
  git fetch --depth 1 origin tag 3.41.6:refs/tags/3.41.6 2>/dev/null || true
  git checkout 3.41.6 2>/dev/null || true
  cd ..
fi

# Run the Flutter build command
./flutter/bin/flutter build web --release

