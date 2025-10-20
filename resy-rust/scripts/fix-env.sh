#!/bin/bash

# Fix common .env file issues

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$PROJECT_ROOT/.env"

echo "════════════════════════════════════════════════════════"
echo ".env File Fixer"
echo "════════════════════════════════════════════════════════"
echo ""

if [ ! -f "$ENV_FILE" ]; then
    echo "❌ .env file not found at $ENV_FILE"
    exit 1
fi

# Backup original
cp "$ENV_FILE" "${ENV_FILE}.backup"
echo "✅ Created backup: ${ENV_FILE}.backup"

# Fix Windows line endings
if grep -q $'\r' "$ENV_FILE" 2>/dev/null; then
    echo "🔧 Fixing Windows line endings..."
    sed -i.tmp 's/\r$//' "$ENV_FILE"
    rm -f "${ENV_FILE}.tmp"
    echo "✅ Fixed line endings"
fi

# Remove UTF-8 BOM if present
if [ "$(head -c 3 $ENV_FILE | od -A n -t x1 2>/dev/null)" = " ef bb bf" ]; then
    echo "🔧 Removing UTF-8 BOM..."
    sed -i.tmp '1s/^\xEF\xBB\xBF//' "$ENV_FILE"
    rm -f "${ENV_FILE}.tmp"
    echo "✅ Removed BOM"
fi

# Remove quotes from values
if grep -q '"' "$ENV_FILE"; then
    echo "🔧 Removing quotes from values..."
    sed -i.tmp 's/^RESY_API_KEY="\(.*\)"$/RESY_API_KEY=\1/' "$ENV_FILE"
    sed -i.tmp 's/^RESY_AUTH_TOKEN="\(.*\)"$/RESY_AUTH_TOKEN=\1/' "$ENV_FILE"
    rm -f "${ENV_FILE}.tmp"
    echo "✅ Removed quotes"
fi

# Remove spaces around =
if grep -E "^\s*RESY_[A-Z_]+\s*=" "$ENV_FILE" | grep -q " "; then
    echo "🔧 Removing spaces around = sign..."
    sed -i.tmp 's/^\s*RESY_API_KEY\s*=\s*/RESY_API_KEY=/' "$ENV_FILE"
    sed -i.tmp 's/^\s*RESY_AUTH_TOKEN\s*=\s*/RESY_AUTH_TOKEN=/' "$ENV_FILE"
    rm -f "${ENV_FILE}.tmp"
    echo "✅ Removed spaces"
fi

# Trim trailing whitespace from values
echo "🔧 Trimming whitespace from values..."
sed -i.tmp 's/=\(.*\)[[:space:]]*$/=\1/' "$ENV_FILE"
sed -i.tmp 's/^\([^=]*=\)[[:space:]]*/\1/' "$ENV_FILE"
rm -f "${ENV_FILE}.tmp"

echo ""
echo "════════════════════════════════════════════════════════"
echo "Fixed .env file:"
echo "════════════════════════════════════════════════════════"
cat "$ENV_FILE"

echo ""
echo "════════════════════════════════════════════════════════"
echo "✅ .env file has been fixed!"
echo "════════════════════════════════════════════════════════"
echo ""
echo "Original backed up to: ${ENV_FILE}.backup"
echo ""
echo "Now test with:"
echo "  ./scripts/test-connection.sh"

