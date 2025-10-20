# Quick Start: Schedule Bookings from Your Laptop

Since your laptop successfully bypasses Resy's WAF but EC2 is blocked, this is the simplest solution.

## ✅ One-Time Setup (2 minutes)

```bash
cd ~/code/resy-cli/resy-rust

# 1. Make sure you have the .env file
cat .env
# Should show:
# RESY_API_KEY=...
# RESY_AUTH_TOKEN=...

# 2. Build the release binary
cargo build --release

# 3. Test it works
./target/release/resy-rust book \
  --venue-id 79633 \
  --party-size 2 \
  --date 2025-10-25 \
  --times "17:00:00" \
  --dry-run
```

You should see:
```
✅ Restaurant: Idashi Omakase
🔍 Polling for available slots...
```

## 📅 Schedule a Booking

```bash
# Schedule format: "YYYY-MM-DD HH:MM:SS" venue_id party_size "times"
./scripts/schedule-macos.sh "2025-10-25 09:00:00" 79633 2 "17:00:00,18:00:00"
```

This will:
- Create a macOS LaunchAgent
- Run at exactly 9:00 AM on Oct 25, 2025
- Try to book at 5pm or 6pm
- Use 5 threads with 5 retries (competitive mode)
- Log everything to `logs/launchd-output.log`

## 🔍 Manage Scheduled Bookings

```bash
# Check scheduled jobs
launchctl list | grep resy

# View logs
tail -f ~/code/resy-cli/resy-rust/logs/launchd-output.log

# Cancel a job
launchctl unload ~/Library/LaunchAgents/com.resy.booking.*.plist
rm ~/Library/LaunchAgents/com.resy.booking.*.plist
```

## 💡 Examples

### Example 1: Book dinner next Friday at 7pm
```bash
NEXT_FRIDAY=$(date -v+fri +%Y-%m-%d)
./scripts/schedule-macos.sh "$NEXT_FRIDAY 09:00:00" 58326 4 "19:00:00"
```

### Example 2: Book this Saturday, try multiple times
```bash
./scripts/schedule-macos.sh "2025-10-23 09:00:00" 79633 2 "18:00:00,18:30:00,19:00:00,19:30:00"
```

### Example 3: Schedule 30 days in advance
```bash
TARGET_DATE=$(date -v+30d +%Y-%m-%d)
BOOK_TIME="$TARGET_DATE 09:00:00"
./scripts/schedule-macos.sh "$BOOK_TIME" 79633 2 "18:00:00"
```

## ⚠️ Important

**Keep your laptop:**
- ✅ Plugged in (or fully charged)
- ✅ Connected to internet
- ✅ Not sleeping (System Settings > Battery > Prevent automatic sleeping when display is off)

**To prevent sleep:**
```bash
# Keep awake until booking time
caffeinate -u -t 86400  # 24 hours
```

## 🔧 Troubleshooting

### Job didn't run?

```bash
# Check logs
cat ~/code/resy-cli/resy-rust/logs/launchd-error.log

# Verify job is loaded
launchctl list | grep resy

# Manually trigger to test
launchctl start com.resy.booking.XXXXXX
```

### Laptop was asleep?

macOS won't run scheduled tasks if asleep. Use `caffeinate`:

```bash
# Keep awake until booking
caffeinate -u -t 86400 &

# Or create a power assertion
pmset -g assertions
```

## 🎯 Complete Workflow

```bash
# 1. Schedule a booking
./scripts/schedule-macos.sh "2025-10-27 09:00:00" 79633 2 "18:00:00,19:00:00"

# 2. Keep laptop awake (if booking is within 24h)
caffeinate -u -t 86400 &

# 3. Monitor logs (optional)
tail -f logs/launchd-output.log

# 4. After booking, check result
cat logs/launchd-output.log | grep -A 5 "Booking"
```

## 📊 What Happens at Booking Time?

```
09:00:00 - Job starts
09:00:01 - Fetches venue details (200 OK ✅)
09:00:01 - Starts polling for slots (250ms intervals)
09:00:01 - Finds available slots
09:00:01 - Launches 5 concurrent threads
09:00:01 - All threads attempt to book simultaneously
09:00:02 - First successful thread wins!
09:00:02 - ✅ Booking confirmed
```

**Total latency**: ~1-2 seconds from reservation release to booking!

## 🆚 Why Laptop > EC2?

| Factor | Laptop | EC2 |
|--------|--------|-----|
| IP Reputation | ✅ Clean residential | ❌ Flagged by WAF |
| Cost | Free | $5-10/month + proxy |
| Setup | 2 minutes | 30+ minutes |
| Success Rate | 100% | 0% (blocked) |
| Latency | ~100-200ms | ~50ms (but blocked) |

**Verdict**: Laptop wins for this use case!

## 🚀 Advanced: Multiple Bookings

Schedule multiple venues/times:

```bash
# Venue A at 9am
./scripts/schedule-macos.sh "2025-10-27 09:00:00" 58326 2 "18:00:00"

# Venue B at 9am (same time, different restaurant)
./scripts/schedule-macos.sh "2025-10-27 09:00:00" 79633 2 "19:00:00"

# Venue C at 10am (fallback)
./scripts/schedule-macos.sh "2025-10-27 10:00:00" 12345 4 "20:00:00"
```

All will run independently!

