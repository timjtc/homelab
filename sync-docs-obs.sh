#!/bin/bash

mkdir -p ./docs/blob

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 <docs-file> [docs-file ...]"
  exit 1
fi

DOCS_FILES=("$@")

process_docs_file() {
  local DOCS_FILE="$1"
  local DOCS_DIR
  local DOCS_OUT
  local DOCS_BODY

  if [[ ! -f "$DOCS_FILE" ]]; then
    echo "Warning: Docs file '$DOCS_FILE' not found. Skipping."
    return
  fi

  DOCS_DIR=$(dirname "$DOCS_FILE")
  DOCS_OUT=./docs/$(basename "$DOCS_FILE")
  DOCS_BODY=$(mktemp)

  cp "$DOCS_FILE" "$DOCS_OUT"

  awk '
    NR == 1 && /^---$/ { in_front_matter = 1; next }
    in_front_matter && /^---$/ { in_front_matter = 0; next }
    !in_front_matter { print }
  ' "$DOCS_FILE" > "$DOCS_BODY"

  # Copy documentation files from Obsidian vault to this repo.
  # Ensure linked images are copied to ./docs/blob.
  while IFS= read -r blob; do
    blob=${blob//$'\r'/}
    [[ -z "$blob" ]] && continue

    found_file=$(find "$DOCS_DIR" -type f -name "$blob" -print -quit)
    if [[ -n "$found_file" ]]; then
      cp "$found_file" ./docs/blob/
      # Convert Obsidian-style image links to standard Markdown links.
      perl -0pi -e "s/!\\[\\[\\Q$blob\\E(?:\\|[^\\]]+)?\\]\\]/![$blob](blob\/$blob)/g" "$DOCS_OUT"
    else
      echo "Warning: File '$blob' not found under '$DOCS_DIR'. Skipping."
    fi
  done < <(grep -oP '!\[\[.*?\]\]' "$DOCS_BODY" | sed 's/!\[\[\(.*\)\]\]/\1/' | cut -d'|' -f1)

  while IFS= read -r ref; do
    ref=${ref//$'\r'/}
    [[ -z "$ref" ]] && continue

    case "$ref" in
      \#*|*.kanban)
        continue
        ;;
    esac

    ref=${ref%%|*}
    ref=${ref%%#*}
    [[ -z "$ref" ]] && continue

    found_file=$(find "$DOCS_DIR" -type f -name "$ref.md" -print -quit)
    if [[ -n "$found_file" ]]; then
      cp "$found_file" ./docs/
      new_ref=$(basename "$found_file" .md)
      perl -0pi -e "s/\\[\\[\\Q$ref\\E(?:\\|[^\\]]+)?\\]\\]/[$new_ref]($new_ref.md)/g" "$DOCS_OUT"
    else
      echo "Warning: Reference '$ref' not found under '$DOCS_DIR'. Skipping."
    fi
  done < <(grep -oP '(?<!\!)\[\[.*?\]\]' "$DOCS_BODY" | sed 's/\[\[\(.*\)\]\]/\1/' | tr -d '\r')

  rm -f "$DOCS_BODY"
}

for DOCS_FILE in "${DOCS_FILES[@]}"; do
  process_docs_file "$DOCS_FILE"
done