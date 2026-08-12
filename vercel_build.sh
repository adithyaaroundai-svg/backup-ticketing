#!/bin/bash
# This script creates a .env file so that `flutter build web` doesn't crash on Vercel.
# We add a dummy variable so the file is not 0 bytes, ensuring Flutter bundles it.
echo "BUILD_PLATFORM=VERCEL" > .env

# Run the Flutter build command
./flutter/bin/flutter build web --release
