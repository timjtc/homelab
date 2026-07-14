#!/bin/bash

mkdir -p ./docs/blob
DOCS_FILE=~/docs/permaprost-obsidian-v2/scalable-homelab-rebuild.md
DOCS_DIR=$(dirname "$DOCS_FILE")
DOCS_OUT=./docs/$(basename "$DOCS_FILE")
DOCS_BODY=$(mktemp)

trap 'rm -f "$DOCS_BODY"' EXIT

cp "$DOCS_FILE" "$DOCS_OUT"

awk '
  NR == 1 && /^---$/ { in_front_matter = 1; next }
  in_front_matter && /^---$/ { in_front_matter = 0; next }
  !in_front_matter { print }
' "$DOCS_FILE" > "$DOCS_BODY"

# Copy documentation files from Obsidian vault to the this repo
# Ensure to copy all linked images to ./docs/blob
for blob in $(grep -oP '!\[\[.*?\]\]' "$DOCS_BODY" | sed 's/!\[\[\(.*\)\]\]/\1/' | cut -d'|' -f1 | tr -d '\r'); do
  found_file=$(find "$DOCS_DIR" -type f -name "$blob" -print -quit)
  if [[ -n "$found_file" ]]; then
    cp "$found_file" ./docs/blob/
    # Convert Obsidian-style image links to standard
    perl -0pi -e "s/!\\[\\[\\Q$blob\\E(?:\\|[^\\]]+)?\\]\\]/![$blob](blob\/$blob)/g" "$DOCS_OUT"
  else
    echo "Warning: File '$blob' not found under '$DOCS_DIR'. Skipping."
  fi
done

for ref in $(grep -oP '(?<!\!)\[\[.*?\]\]' "$DOCS_BODY" | sed 's/\[\[\(.*\)\]\]/\1/' | cut -d'|' -f1 | tr -d '\r'); do
  case "$ref" in
    \#*|*.kanban)
      continue
      ;;
  esac

  found_file=$(find "$DOCS_DIR" -type f -name "$ref.md" -print -quit)
  if [[ -n "$found_file" ]]; then
    cp "$found_file" ./docs/
    new_ref=$(basename "$found_file" .md)
    perl -0pi -e "s/\\[\\[\\Q$ref\\E(?:\\|[^\\]]+)?\\]\\]/[$new_ref]($new_ref.md)/g" "$DOCS_OUT"
  else
    echo "Warning: Reference '$ref' not found under '$DOCS_DIR'. Skipping."
  fi
done