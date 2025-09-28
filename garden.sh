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

fix_attachment_links() {
  echo "→ Fixing attachment links in published notes"

  find "$QZ_CONTENT" -name "*.md" -type f | while read -r note; do
    # Skip homepage
    [[ "$(basename "$note")" == "index.md" ]] && continue

    # Fix Obsidian-style attachment links - convert ![[filename]] to ![](path)
    sed -i 's/!\[\[\([^]]*\.\(png\|jpg\|jpeg\|gif\|svg\|pdf\|mp4\|mov\)\)\]\]/![\1](\/attachments\/\1)/g' "$note"

    # Fix relative paths (corrected - using \2 instead of \3)
    sed -i 's|!\[\([^]]*\)\](\.\.\/00 - System\/Attachments\/\([^)]*\))|![\1](/attachments/\2)|g' "$note"
    sed -i 's|!\[\([^]]*\)\](00 - System\/Attachments\/\([^)]*\))|![\1](/attachments/\2)|g' "$note"
  done
}

copy_attachments() {
  echo "→ Copying attachments referenced by published notes"

  cd "$VAULT"
  attachments_dir="00 - System/Attachments"

  if [[ ! -d "$attachments_dir" ]]; then
    echo "   • No attachments directory found"
    return
  fi

  mkdir -p "$QZ_CONTENT/attachments"

  # Find all attachment references and copy them with URL-safe names
  find "$QZ_CONTENT" -name "*.md" -exec cat {} \; | \
  grep -o 'Pasted image [0-9]*\.png\|[a-zA-Z0-9_-]*\.\(png\|jpg\|jpeg\|gif\|svg\|pdf\)' | \
  sort -u | while read -r filename; do
    if [[ -f "$attachments_dir/$filename" ]]; then
      # Create URL-safe version of filename (replace spaces with dashes)
      safe_filename=$(echo "$filename" | sed 's/ /-/g')

      # Copy with the URL-safe name
      cp "$attachments_dir/$filename" "$QZ_CONTENT/attachments/$safe_filename"
      echo "   • Copied: $filename → $safe_filename"

      # Update all references in the published notes to use the safe filename
      find "$QZ_CONTENT" -name "*.md" -exec sed -i "s|/attachments/$filename|/attachments/$safe_filename|g" {} \;
    fi
  done

  file_count=$(ls "$QZ_CONTENT/attachments" 2>/dev/null | wc -l || echo "0")
  echo "   • Total attachments copied: $file_count"
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
fix_attachment_links    # Fix links first
copy_attachments

case "$1" in
  serve)   serve_quartz ;;
  publish) sync_quartz ;;
  *)       usage ;;
esac

