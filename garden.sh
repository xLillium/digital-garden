#!/usr/bin/env bash

### Configuration
VAULT="$HOME/Documents/Vault/Main"
QZ_ROOT="$HOME/Documents/digital-garden/quartz"
QZ_CONTENT="$QZ_ROOT/content"

### Functions
cleanup_content() {
  echo "→ Cleaning Quartz content folder"
  rm -rf "$QZ_CONTENT"
  mkdir -p "$QZ_CONTENT"
}

generate_homepage() {
  echo "→ Generating homepage from vault"
  cd "$VAULT"
  homepage_file=$(grep -rlZ "^quartz-homepage: true" --include="*.md" . | tr -d '\0' | head -n1)
  if [[ -n "$homepage_file" ]]; then
    rel="${homepage_file#./}"
    echo "   • Using '$rel' as homepage"
    mkdir -p "$QZ_CONTENT"
    cp "$homepage_file" "$QZ_CONTENT/index.md"
  else
    echo "   ! No file marked as homepage (quartz-homepage: true)"
    echo "   ! Please add that frontmatter to one file"
    exit 1
  fi
}

export_published() {
  echo "→ Exporting published notes from $VAULT"
  cd "$VAULT"
  find . -type f -name "*.md" -print0 \
  | xargs -0 grep -lZ "^publish: true" \
  | while IFS= read -r -d '' file; do
      rel="${file#./}"
      mkdir -p "$QZ_CONTENT/$(dirname "$rel")"
      cp "$file" "$QZ_CONTENT/$rel"
    done
}

build_quartz() {
  echo "→ Building Quartz"
  cd "$QZ_ROOT"
  npx quartz build
}

serve_quartz() {
  echo "→ Serving Quartz locally"
  cd "$QZ_ROOT"
  npx quartz build --serve
}

sync_quartz() {
  echo "→ Syncing Quartz with GitHub Pages"
  cd "$QZ_ROOT"
  npx quartz sync
}

### Usage
usage() {
  cat <<EOF
Usage: $(basename "$0") <command>

Commands:
  serve     Clean, export, build & serve locally
  publish   Clean, export, build & sync to GitHub Pages
EOF
  exit 1
}

### Main
if [[ $# -ne 1 ]]; then
  usage
fi

case "$1" in
  serve)
    cleanup_content
    generate_homepage
    export_published
    serve_quartz
    ;;
  publish)
    cleanup_content
    generate_homepage
    export_published
    build_quartz
    sync_quartz
    ;;
  *)
    usage
    ;;
esac

