#!/bin/bash
export PATH="$PATH:$(pwd)/flutter/bin"
flutter build web --release --no-tree-shake-icons \
  --dart-define=GROQ_API_KEY="$App_ElGuiaYA" \
  --dart-define=GEMINI_API_KEY="$GEMINI_API_KEY" \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"

# Copiar landing de descarga al output de Vercel
cp public/descarga.html build/web/descarga.html 2>/dev/null || true
