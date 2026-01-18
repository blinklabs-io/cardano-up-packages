#!/usr/bin/env bash
# Validates filename version matches content version for all packages

set -euo pipefail

ERRORS=0
CHECKED=0

for file in packages/*/*.yaml; do
  # Skip if no files match
  [[ -e "$file" ]] || continue

  # Extract package name from YAML content
  package_name=$(grep -E '^name:' "$file" | head -1 | awk '{print $2}')

  # Extract version from filename by removing package name prefix
  # e.g., cardano-cli-10.1.1.0.yaml with name "cardano-cli" -> 10.1.1.0
  filename=$(basename "$file" .yaml)
  filename_version="${filename#"${package_name}-"}"

  # Extract version from YAML content
  content_version=$(grep -E '^version:' "$file" | head -1 | awk '{print $2}')

  CHECKED=$((CHECKED + 1))

  if [[ "$filename_version" != "$content_version" ]]; then
    echo "ERROR: Version mismatch in $file"
    echo "  Filename version: $filename_version"
    echo "  Content version:  $content_version"
    ERRORS=$((ERRORS + 1))
  fi
done

echo ""
echo "Checked $CHECKED package files"

if [[ $ERRORS -gt 0 ]]; then
  echo "Found $ERRORS version mismatch(es)"
  exit 1
else
  echo "All versions match"
  exit 0
fi
