#!/bin/bash

# Debug how the Rust binary is reading environment variables
# This compares shell vs Rust env loading

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "════════════════════════════════════════════════════════"
echo "Environment Variable Debug Tool"
echo "════════════════════════════════════════════════════════"
echo ""

# Check .env file
echo "1️⃣  Checking .env file format..."
if [ ! -f "$PROJECT_ROOT/.env" ]; then
    echo "❌ .env file not found"
    exit 1
fi

# Show file with special characters visible
echo "File contents (showing special characters):"
cat -A "$PROJECT_ROOT/.env" | grep -E "RESY_API_KEY|RESY_AUTH_TOKEN"
echo ""

# Check for Windows line endings
if grep -q $'\r' "$PROJECT_ROOT/.env" 2>/dev/null; then
    echo "⚠️  WARNING: File has Windows line endings (\\r\\n)"
    echo "   This can cause issues. Fix with:"
    echo "   dos2unix .env"
    echo "   OR: sed -i 's/\\r$//' .env"
    echo ""
else
    echo "✅ No Windows line endings detected"
fi

# Check for BOM
if [ "$(head -c 3 $PROJECT_ROOT/.env | od -A n -t x1)" = " ef bb bf" ]; then
    echo "⚠️  WARNING: File has UTF-8 BOM"
    echo "   Remove with: sed -i '1s/^\xEF\xBB\xBF//' .env"
    echo ""
else
    echo "✅ No BOM detected"
fi

# Load variables using source (like bash does)
echo ""
echo "2️⃣  Testing bash source method..."
source "$PROJECT_ROOT/.env"

echo "Bash sees:"
echo "  API Key length: ${#RESY_API_KEY}"
echo "  Auth Token length: ${#RESY_AUTH_TOKEN}"
echo "  API Key (first 20): '${RESY_API_KEY:0:20}'"
echo "  Auth Token (first 20): '${RESY_AUTH_TOKEN:0:20}'"

# Check for whitespace
if [[ "$RESY_API_KEY" =~ ^[[:space:]] ]] || [[ "$RESY_API_KEY" =~ [[:space:]]$ ]]; then
    echo "⚠️  WARNING: API Key has leading or trailing whitespace!"
fi

if [[ "$RESY_AUTH_TOKEN" =~ ^[[:space:]] ]] || [[ "$RESY_AUTH_TOKEN" =~ [[:space:]]$ ]]; then
    echo "⚠️  WARNING: Auth Token has leading or trailing whitespace!"
fi

# Test with actual binary
echo ""
echo "3️⃣  Testing how Rust binary reads .env..."

BINARY="$PROJECT_ROOT/target/release/resy-rust"
if [ ! -f "$BINARY" ]; then
    echo "❌ Binary not found. Build with: cargo build --release"
    exit 1
fi

# Create a test program to see what Rust sees
cat > /tmp/test-env-rust.sh << 'EOFSCRIPT'
#!/bin/bash
cd "$1"
source .env
export RESY_API_KEY
export RESY_AUTH_TOKEN

# Run a simple curl test
curl -s -w "\nHTTP_CODE: %{http_code}\n" \
    -H "authorization: ResyAPI api_key=\"${RESY_API_KEY}\"" \
    -H "x-resy-auth-token: ${RESY_AUTH_TOKEN}" \
    -H "x-resy-universal-auth: ${RESY_AUTH_TOKEN}" \
    -H "user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36" \
    -H "origin: https://resy.com" \
    -H "referrer: https://resy.com" \
    -H "x-origin: https://resy.com" \
    -H "cache-control: no-cache" \
    "https://api.resy.com/2/config?venue_id=58326" 2>&1 | tail -5
EOFSCRIPT

chmod +x /tmp/test-env-rust.sh
/tmp/test-env-rust.sh "$PROJECT_ROOT"

echo ""
echo "4️⃣  Checking for hidden issues..."

# Check if values have quotes
if grep -q '"' "$PROJECT_ROOT/.env"; then
    echo "⚠️  WARNING: .env file contains quotes"
    echo "   Variables should NOT be quoted"
    echo "   Wrong: RESY_API_KEY=\"abc123\""
    echo "   Right: RESY_API_KEY=abc123"
    grep '"' "$PROJECT_ROOT/.env"
fi

# Check for spaces around =
if grep -E "^\s*RESY_[A-Z_]+\s*=\s*" "$PROJECT_ROOT/.env" | grep -v "^RESY_[A-Z_]*="; then
    echo "⚠️  WARNING: Found spaces around = sign"
    echo "   Wrong: RESY_API_KEY = abc123"
    echo "   Right: RESY_API_KEY=abc123"
fi

echo ""
echo "5️⃣  Testing actual binary environment loading..."
cd "$PROJECT_ROOT"

# Test if binary can read .env
if ! "$BINARY" book --venue-id 58326 --party-size 2 --date 2025-12-31 --times "18:00:00" --dry-run 2>&1 | head -20; then
    echo ""
    echo "❌ Binary execution failed"
    echo "Check the error above"
fi

echo ""
echo "════════════════════════════════════════════════════════"
echo "Recommendations:"
echo "════════════════════════════════════════════════════════"
echo ""
echo "If you saw any warnings above, fix them."
echo ""
echo "If no warnings but still getting 500 errors:"
echo "1. Your credentials might have expired - get fresh ones"
echo "2. Try recreating .env from scratch:"
echo "   rm .env"
echo "   nano .env"
echo "   # Paste credentials with NO quotes, NO spaces"
echo ""
echo "3. Test with absolute minimal command:"
echo "   cd $PROJECT_ROOT"
echo "   RUST_LOG=debug ./target/release/resy-rust book \\"
echo "     --venue-id 58326 --party-size 2 \\"
echo "     --date 2025-12-31 --times \"18:00:00\" --dry-run"

