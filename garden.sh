#!/usr/bin/env bash

### Configuration
VAULT="$HOME/Documents/Vault/Main"
QZ_ROOT="$HOME/Documents/digital-garden/quartz"
QZ_CONTENT="$QZ_ROOT/content"

### Functions
cleanup_content() {
  echo "→ Cleaning Quartz content folder"
  
  if [[ -d "$QZ_CONTENT" ]]; then
      rm -rf "$QZ_CONTENT"
  fi

  mkdir -p "$QZ_CONTENT"
}

generate_homepage() {
  echo "→ Generating homepage from vault"

  cd "$VAULT"
  homepage_file=$(grep -rlZ "^quartz-homepage: true" --include="*.md" . | tr -d '\0' | head -n1)

  if [[ -n "$homepage_file" ]]; then
    rel="${homepage_file#./}"
    echo "   • Using '$rel' as homepage"
    cp "$homepage_file" "$QZ_CONTENT/index.md"
  else
    echo "   ! No file marked as homepage (quartz-homepage: true)"
    echo "   ! Please add that frontmatter to one file"
    exit 1
  fi
}

export_published() {
  echo "→ Exporting published notes"

  cd "$VAULT"
  find . \
    -path "./00 - System" -prune -o \
    -path "./00-System"    -prune -o \
    -type f -name "*.md"    -print \
  | awk '
    {
      file = $0
      is_homepage = 0
      is_published = 0
      category = ""
      title = ""

      # Read and parse the file
      while ((getline line < file) > 0) {
        if (line ~ /^quartz-homepage: true/) is_homepage = 1
        if (line ~ /^publish: true/) is_published = 1
        if (line ~ /^Category:/) {
          category = substr(line, index(line, ":") + 1)
          gsub(/^[ \t]+|[ \t]+$/, "", category)
        }
        if (line ~ /^title:/) {
          title = substr(line, index(line, ":") + 1)
          gsub(/^[ \t]+|[ \t]+$/, "", title)
        }
      }
      close(file)

      # Skip homepage and unpublished
      if (is_homepage || !is_published) next

      # Set defaults
      if (category == "") category = "Uncategorized"
      if (title == "") {
        n = split(file, parts, "/")
        title = parts[n]
        gsub(/\.md$/, "", title)
      }

      # Slugify title
      slug = tolower(title)
      gsub(/[^a-z0-9]+/, "-", slug)
      gsub(/^-|-$/, "", slug)

      # Output the copy command
      print file "|" category "|" slug
    }
  ' | while IFS='|' read -r file category slug; do
    dest_dir="$QZ_CONTENT/$category"
    dest_file="$dest_dir/$slug.md"

    echo "   • $file → $category/$slug.md"
    mkdir -p "$dest_dir"
    cp "$file" "$dest_file"
  done
}

serve_quartz() {
  echo "→ Serving Quartz locally"
  cd "$QZ_ROOT"
  npx quartz build --serve
}

sync_quartz() {
  echo "→ Syncing Quartz with GitHub Pages"
  cd "$QZ_ROOT"
  npx quartz build
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
[[ $# -eq 1 ]] || usage

cleanup_content
generate_homepage
export_published

case "$1" in
  serve)   serve_quartz ;;
  publish) sync_quartz ;;
  *)       usage ;;
esac

