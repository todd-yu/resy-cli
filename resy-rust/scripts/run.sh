#!/bin/bash

# Resy booking script with sensible defaults
# Usage: ./run.sh [options]
# All options are passed through to the resy-rust binary

set -e

# Get script directory and find the binary
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BINARY="$PROJECT_ROOT/target/release/resy-rust"

# Check if binary exists
if [ ! -f "$BINARY" ]; then
    echo "Error: Binary not found at $BINARY"
    echo "Run 'cargo build --release' first"
    exit 1
fi

# Default values
DEFAULT_LOG_FILE="$PROJECT_ROOT/logs/booking_$(date +%Y%m%d_%H%M%S).log"
DEFAULT_VENUE_ID="58326"
DEFAULT_PARTY_SIZE="2"
DEFAULT_DATE=$(date -v+7d +%Y-%m-%d 2>/dev/null || date -d "+7 days" +%Y-%m-%d 2>/dev/null || date +%Y-%m-%d)
DEFAULT_TIMES="18:00:00,19:00:00"
DEFAULT_THREADS="5"
DEFAULT_RETRIES="3"

# Parse arguments or use defaults
VENUE_ID="${VENUE_ID:-$DEFAULT_VENUE_ID}"
PARTY_SIZE="${PARTY_SIZE:-$DEFAULT_PARTY_SIZE}"
RESERVATION_DATE="${RESERVATION_DATE:-$DEFAULT_DATE}"
TIMES="${TIMES:-$DEFAULT_TIMES}"
THREADS="${THREADS:-$DEFAULT_THREADS}"
RETRIES="${RETRIES:-$DEFAULT_RETRIES}"
LOG_FILE="${LOG_FILE:-$DEFAULT_LOG_FILE}"
DRY_RUN="${DRY_RUN:-true}"

# Create logs directory
mkdir -p "$PROJECT_ROOT/logs"

# If arguments are passed, use them directly; otherwise use env vars/defaults
if [ $# -eq 0 ]; then
    echo "════════════════════════════════════════════════════════"
    echo "Using default configuration:"
    echo "  Venue ID: $VENUE_ID"
    echo "  Party Size: $PARTY_SIZE"
    echo "  Date: $RESERVATION_DATE"
    echo "  Times: $TIMES"
    echo "  Threads: $THREADS"
    echo "  Retries: $RETRIES"
    echo "  Log File: $LOG_FILE"
    echo "  Dry Run: $DRY_RUN"
    echo ""
    echo "To customize, either:"
    echo "  1. Set environment variables: VENUE_ID=123 ./run.sh"
    echo "  2. Pass arguments: ./run.sh --venue-id 123 --party-size 4"
    echo "════════════════════════════════════════════════════════"
    echo ""

    exec "$BINARY" book \
        --venue-id "$VENUE_ID" \
        --party-size "$PARTY_SIZE" \
        --date "$RESERVATION_DATE" \
        --times "$TIMES" \
        --threads "$THREADS" \
        --retries "$RETRIES" \
        --log-file "$LOG_FILE" \
        $([ "$DRY_RUN" = "true" ] && echo "--dry-run")
else
    # Pass all arguments through, but add default log file if not specified
    if ! [[ "$*" =~ --log-file ]]; then
        echo "Using default log file: $LOG_FILE"
        exec "$BINARY" book "$@" --log-file "$LOG_FILE"
    else
        exec "$BINARY" book "$@"
    fi
fi