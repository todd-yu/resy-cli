#!/bin/bash
# Quick test to verify booking works from laptop

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BINARY="$PROJECT_ROOT/target/release/resy-rust"

echo "🧪 Testing Resy booking from laptop..."
echo ""

# Check binary
if [ ! -f "$BINARY" ]; then
    echo "❌ Binary not found. Building..."
    cd "$PROJECT_ROOT"
    cargo build --release
fi

# Check .env
if [ ! -f "$PROJECT_ROOT/.env" ]; then
    echo "❌ .env file not found!"
    echo "Create $PROJECT_ROOT/.env with:"
    echo "  RESY_API_KEY=your_key"
    echo "  RESY_AUTH_TOKEN=your_token"
    exit 1
fi

# Test booking
echo "Testing with venue 79633 (Idashi Omakase)..."
echo ""

"$BINARY" book \
    --venue-id 79633 \
    --party-size 2 \
    --date 2025-10-25 \
    --times "17:00:00,18:00:00" \
    --dry-run \
    --threads 1 \
    --retries 1 \
    --poll-timeout-secs 5

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ SUCCESS! Your laptop can book reservations."
    echo ""
    echo "Next steps:"
    echo "  1. Schedule a booking: ./scripts/schedule-macos.sh \"2025-10-25 09:00:00\" 79633 2 \"17:00:00\""
    echo "  2. Keep laptop awake: caffeinate -u -t 86400 &"
    echo "  3. Monitor logs: tail -f $PROJECT_ROOT/logs/launchd-output.log"
else
    echo ""
    echo "❌ FAILED! Check the error above."
    echo ""
    echo "Common issues:"
    echo "  - Invalid credentials in .env"
    echo "  - Network connectivity"
    echo "  - Venue ID doesn't exist"
fi

