#!/bin/bash

# Test Resy API connection and credentials
# Run this on your VM to diagnose issues

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "════════════════════════════════════════════════════════"
echo "Resy Connection Diagnostic Tool"
echo "════════════════════════════════════════════════════════"
echo ""

# Check .env file exists
echo "1️⃣  Checking .env file..."
if [ ! -f "$PROJECT_ROOT/.env" ]; then
    echo "❌ .env file not found at $PROJECT_ROOT/.env"
    echo "   Create it with:"
    echo "   cd $PROJECT_ROOT"
    echo "   cp env.example .env"
    echo "   nano .env"
    exit 1
fi
echo "✅ .env file exists"
echo ""

# Load environment variables
source "$PROJECT_ROOT/.env"

# Check credentials are set
echo "2️⃣  Checking credentials..."
if [ -z "$RESY_API_KEY" ] || [ "$RESY_API_KEY" = "your_api_key_here" ]; then
    echo "❌ RESY_API_KEY not set or still has default value"
    echo "   Edit .env and add your actual API key"
    exit 1
fi

if [ -z "$RESY_AUTH_TOKEN" ] || [ "$RESY_AUTH_TOKEN" = "your_auth_token_here" ]; then
    echo "❌ RESY_AUTH_TOKEN not set or still has default value"
    echo "   Edit .env and add your actual auth token"
    exit 1
fi

echo "✅ Credentials are set"
echo "   API Key: ${RESY_API_KEY:0:20}..."
echo "   Auth Token: ${RESY_AUTH_TOKEN:0:20}..."
echo ""

# Check network connectivity
echo "3️⃣  Testing network connectivity..."
if ! ping -c 1 api.resy.com &> /dev/null; then
    echo "⚠️  Cannot ping api.resy.com"
    echo "   This might be normal (ICMP blocked), checking HTTP..."
else
    echo "✅ Can ping api.resy.com"
fi

if ! curl -s --max-time 5 https://api.resy.com &> /dev/null; then
    echo "❌ Cannot reach api.resy.com via HTTPS"
    echo "   Check firewall/network settings"
    exit 1
fi
echo "✅ Can reach api.resy.com via HTTPS"
echo ""

# Test API with curl
echo "4️⃣  Testing API authentication with curl..."
VENUE_ID="${1:-58326}"  # Use argument or default

RESPONSE=$(curl -s -w "\n%{http_code}" \
    -H "authorization: ResyAPI api_key=\"${RESY_API_KEY}\"" \
    -H "x-resy-auth-token: ${RESY_AUTH_TOKEN}" \
    -H "x-resy-universal-auth: ${RESY_AUTH_TOKEN}" \
    -H "user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36" \
    -H "origin: https://resy.com" \
    -H "referrer: https://resy.com" \
    -H "x-origin: https://resy.com" \
    -H "cache-control: no-cache" \
    "https://api.resy.com/2/config?venue_id=${VENUE_ID}")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -n -1)

echo "HTTP Status Code: $HTTP_CODE"

case $HTTP_CODE in
    200)
        echo "✅ Authentication successful!"
        VENUE_NAME=$(echo "$BODY" | grep -o '"name":"[^"]*"' | head -1 | cut -d'"' -f4)
        if [ -n "$VENUE_NAME" ]; then
            echo "   Restaurant: $VENUE_NAME"
        fi
        echo ""
        echo "════════════════════════════════════════════════════════"
        echo "✅ All checks passed! Your setup is working correctly."
        echo "════════════════════════════════════════════════════════"
        ;;
    401|403)
        echo "❌ Authentication failed (${HTTP_CODE})"
        echo "   Your credentials are invalid or expired"
        echo ""
        echo "To get fresh credentials:"
        echo "1. Go to https://resy.com and log in"
        echo "2. Open browser DevTools (F12)"
        echo "3. Go to Network tab"
        echo "4. Make a search or reservation"
        echo "5. Find an api.resy.com request"
        echo "6. Look at Request Headers for:"
        echo "   - authorization: ResyAPI api_key=\"...\""
        echo "   - x-resy-auth-token: ..."
        echo ""
        echo "Update your .env file with the new credentials"
        exit 1
        ;;
    500)
        echo "❌ Server error (500)"
        echo "   This usually means authentication failed"
        echo ""
        echo "Common causes:"
        echo "1. Invalid or expired credentials"
        echo "2. Malformed API key or auth token"
        echo "3. Whitespace in credentials"
        echo ""
        echo "Check your .env file:"
        cat "$PROJECT_ROOT/.env"
        echo ""
        echo "Make sure there are NO spaces around the = sign"
        echo "Make sure there are NO quotes around the values"
        echo "Correct: RESY_API_KEY=abc123"
        echo "Wrong:   RESY_API_KEY = \"abc123\""
        exit 1
        ;;
    000)
        echo "❌ Cannot connect to API"
        echo "   Check network/firewall settings"
        exit 1
        ;;
    *)
        echo "⚠️  Unexpected status code: $HTTP_CODE"
        echo "Response body:"
        echo "$BODY" | head -20
        exit 1
        ;;
esac

# Test finding slots
echo ""
echo "5️⃣  Testing slot search..."
DATE=$(date -d "+7 days" +%Y-%m-%d 2>/dev/null || date -v+7d +%Y-%m-%d 2>/dev/null || date +%Y-%m-%d)

RESPONSE=$(curl -s -w "\n%{http_code}" \
    -H "authorization: ResyAPI api_key=\"${RESY_API_KEY}\"" \
    -H "x-resy-auth-token: ${RESY_AUTH_TOKEN}" \
    -H "x-resy-universal-auth: ${RESY_AUTH_TOKEN}" \
    -H "user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36" \
    -H "origin: https://resy.com" \
    -H "referrer: https://resy.com" \
    -H "x-origin: https://resy.com" \
    -H "cache-control: no-cache" \
    "https://api.resy.com/4/find?party_size=2&venue_id=${VENUE_ID}&day=${DATE}&lat=0&long=0")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)

if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Slot search successful!"
    echo "   Can query availability for $DATE"
else
    echo "⚠️  Slot search returned: $HTTP_CODE"
    echo "   This might be normal if no slots are available"
fi

echo ""
echo "════════════════════════════════════════════════════════"
echo "🎉 Connection test complete!"
echo "════════════════════════════════════════════════════════"
echo ""
echo "If all checks passed, try running:"
echo "  cd $PROJECT_ROOT"
echo "  ./scripts/run.sh --venue-id $VENUE_ID --dry-run"

