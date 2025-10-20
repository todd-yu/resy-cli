#!/bin/bash

# Examples of using run.sh

echo "═══════════════════════════════════════════════════════════"
echo "Examples for run.sh"
echo "═══════════════════════════════════════════════════════════"
echo ""

echo "1. Run with all defaults (dry run):"
echo "   ./scripts/run.sh"
echo ""

echo "2. Quick test with specific venue:"
echo "   VENUE_ID=12345 ./scripts/run.sh"
echo ""

echo "3. Actual booking (not dry run):"
echo "   DRY_RUN=false VENUE_ID=12345 TIMES=\"19:00:00\" ./scripts/run.sh"
echo ""

echo "4. Change multiple parameters with env vars:"
echo "   VENUE_ID=12345 PARTY_SIZE=4 THREADS=10 RETRIES=5 ./scripts/run.sh"
echo ""

echo "5. Pass through all CLI arguments:"
echo "   ./scripts/run.sh --venue-id 12345 --party-size 4 --date 2025-12-31 --times \"19:00:00\""
echo ""

echo "6. Mix env vars with arguments (env vars act as defaults):"
echo "   THREADS=10 RETRIES=5 ./scripts/run.sh --venue-id 12345 --times \"19:00:00\""
echo ""

echo "7. Custom log file:"
echo "   LOG_FILE=/tmp/my-booking.log ./scripts/run.sh"
echo ""

echo "8. Maximum competition mode:"
echo "   THREADS=10 RETRIES=5 DRY_RUN=false ./scripts/run.sh --venue-id 12345 --times \"19:00:00\" --poll-interval-ms 100"
echo ""

echo "9. Quick competitive booking (ready for production):"
echo "   DRY_RUN=false VENUE_ID=58326 TIMES=\"19:00:00,19:30:00\" ./scripts/run.sh"
echo ""

echo "10. Schedule with 'at' (macOS):"
echo "    echo 'DRY_RUN=false VENUE_ID=12345 TIMES=\"19:00:00\" /full/path/to/scripts/run.sh' | at 09:00 AM Nov 15"
echo ""

echo "═══════════════════════════════════════════════════════════"
echo "Environment Variables:"
echo "═══════════════════════════════════════════════════════════"
echo "VENUE_ID        - Restaurant venue ID (default: 58326)"
echo "PARTY_SIZE      - Number of people (default: 2)"
echo "RESERVATION_DATE- Date YYYY-MM-DD (default: 7 days from today)"
echo "TIMES           - Comma-separated HH:MM:SS (default: 18:00:00,19:00:00)"
echo "THREADS         - Concurrent booking threads (default: 5)"
echo "RETRIES         - Retry attempts per thread (default: 3)"
echo "LOG_FILE        - Path to log file (default: logs/booking_<timestamp>.log)"
echo "DRY_RUN         - Set to 'false' to actually book (default: true)"
echo "═══════════════════════════════════════════════════════════"

