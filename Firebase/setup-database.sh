#!/bin/bash
#
# KiddoTasks — Firebase database setup
#
# Installs/builds the Cloud Functions, then deploys the Firestore security
# rules and Cloud Functions to the selected Firebase project.
#
# One-time prerequisites (run from the repo root):
#   npm install -g firebase-tools
#   firebase login
#   firebase use --add        # pick your project; creates .firebaserc
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FUNCTIONS_DIR="$REPO_ROOT/Firebase/functions"

echo "=========================================="
echo "  KiddoTasks Firebase setup"
echo "=========================================="

# 1. Prerequisites
echo ""
echo "1. Checking prerequisites..."

if ! command -v firebase >/dev/null 2>&1; then
    echo "❌ Firebase CLI not found. Install with: npm install -g firebase-tools"
    exit 1
fi
echo "   ✅ Firebase CLI installed"

if [ ! -f "$REPO_ROOT/.firebaserc" ]; then
    echo "⚠️  No .firebaserc found — which Firebase project should this deploy to?"
    echo "   Run:  firebase use --add   (from $REPO_ROOT), then re-run this script."
    exit 1
fi
echo "   ✅ Firebase project selected (.firebaserc present)"

if [ ! -f "$FUNCTIONS_DIR/package.json" ]; then
    echo "❌ Functions package.json not found at $FUNCTIONS_DIR"
    exit 1
fi
echo "   ✅ Functions package found"

# 2. Install + build functions
echo ""
echo "2. Installing Functions dependencies..."
(cd "$FUNCTIONS_DIR" && npm install)
echo "   ✅ Dependencies installed"

echo ""
echo "3. Building TypeScript..."
(cd "$FUNCTIONS_DIR" && npm run build)
echo "   ✅ Build complete"

# 3. Login check
echo ""
echo "4. Checking Firebase authentication..."
if ! firebase projects:list >/dev/null 2>&1; then
    echo "❌ Not logged in to Firebase. Please run: firebase login"
    exit 1
fi
echo "   ✅ Logged in to Firebase"

# 4. Deploy rules + functions
echo ""
echo "5. Deploying Firestore rules and Cloud Functions..."
(cd "$REPO_ROOT" && firebase deploy --only firestore:rules,functions)
echo "   ✅ Deployed"

cat <<'EOF'

==========================================
  Setup complete!
==========================================

Next steps for the iOS app:
  1. Firebase console → Project settings → Your apps → download
     GoogleService-Info.plist for bundle id com.kiddotasks.app
  2. Drag it into the Kiddotasks group in Xcode (Kiddotasks target checked)
  3. Add the Firebase iOS SDK via SPM if you have not yet:
     https://github.com/firebase/firebase-ios-sdk (12.0.0)
     Products: FirebaseAuth, FirebaseFirestore, FirebaseFunctions
  4. Build & run → Create family (bootstraps the Firestore data)

Local testing without touching the cloud:
  firebase emulators:start      # auth :9099, firestore :8080, functions :5001
  Run the app with FIREBASE_EMULATE=1 to point the SDK at the emulators.
EOF
