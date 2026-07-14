#!/bin/bash

mkdir -p ./docs/blob
DOCS_FILE=~/docs/permaprost-obsidian-v2/scalable-homelab-rebuild.md
DOCS_DIR=$(dirname "$DOCS_FILE")
DOCS_OUT=./docs/$(basename "$DOCS_FILE")

cp "$DOCS_FILE" "$DOCS_OUT"

# Copy documentation files from Obsidian vault to the this repo
# Ensure to copy all linked images to ./docs/blob
for file in $(grep -oP '!\[\[.*?\]\]' "$DOCS_FILE" | sed 's/!\[\[\(.*\)\]\]/\1/' | cut -d'|' -f1 | tr -d '\r'); do
  found_file=$(find "$DOCS_DIR" -type f -name "$file" -print -quit)
  if [[ -n "$found_file" ]]; then
    cp "$found_file" ./docs/blob/
    perl -0pi -e "s/!\\[\\[\\Q$file\\E(?:\\|[^\\]]+)?\\]\\]/![$file](blob\/$file)/g" "$DOCS_OUT"
  else
    echo "Warning: File '$file' not found under '$DOCS_DIR'. Skipping."
  fi
done