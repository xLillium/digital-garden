#!/usr/bin/env bash
VAULT="$HOME/Documents/Vault/Main"
QZ_ROOT="$HOME/Documents/digital-garden/quartz"
QZ_CONTENT="$QZ_ROOT/content"

echo "→ Cleaning Quartz content folder"
rm -rf "$QZ_CONTENT"
mkdir -p "$QZ_CONTENT"

echo "→ Exporting published notes from $VAULT"
cd "$VAULT"

find . -type f -name "*.md" -print0 \
  | xargs -0 grep -lZ "^publish: true" \
  | while IFS= read -r -d '' file; do
      rel="${file#./}"
      mkdir -p "$QZ_CONTENT/$(dirname "$rel")"
      cp "$file" "$QZ_CONTENT/$rel"
    done

# 5. Run Quartz build & sync from project root
echo "→ Building and serving Quartz locally"
cd "$QZ_ROOT"
npx quartz build --serve
# npx quartz build
# npx quartz sync --no-pull
