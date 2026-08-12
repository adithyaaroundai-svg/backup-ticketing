#!/bin/bash
# This script creates an empty .env file so that `flutter build web` doesn't crash on Vercel.
touch .env

# Run the Flutter build command
./flutter/bin/flutter build web --release
