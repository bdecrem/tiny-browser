#!/bin/bash

echo "Building TinyBrowser..."
xcrun swift build --configuration release

echo "Launching TinyBrowser..."
./.build/release/TinyBrowser &

echo "TinyBrowser launched!"