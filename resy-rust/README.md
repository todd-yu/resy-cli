# Resy Booking CLI (Rust)

Fast, competitive reservation booking for Resy restaurants.

## ✨ Features

- **Blazing Fast**: Written in Rust with optimized HTTP client
- **Competitive Mode**: Multi-threaded booking with configurable retries
- **Smart Polling**: Automatically checks for new reservations
- **Flexible Scheduling**: macOS launchd integration for automated bookings
- **Clean Output**: Beautiful logging to both console and file

## 🚀 Quick Start

### 1. Setup

```bash
# Clone and build
git clone <your-repo>
cd resy-rust
cargo build --release

# Create .env file with your Resy credentials
echo "RESY_API_KEY=your_api_key_here" > .env
echo "RESY_AUTH_TOKEN=your_auth_token_here" >> .env
```

### 2. Test

```bash
./scripts/test-laptop.sh
```

### 3. Book Now

```bash
./target/release/resy-rust book \
  --venue-id 79633 \
  --party-size 2 \
  --date 2025-10-25 \
  --times "18:00:00,19:00:00" \
  --threads 5 \
  --retries 5
```

### 4. Schedule for Later

```bash
# Schedule booking at 9:00 AM on Oct 25
./scripts/schedule-macos.sh "2025-10-25 09:00:00" 79633 2 "18:00:00,19:00:00"

# Keep laptop awake
caffeinate -u -t 86400 &

# Monitor logs
tail -f logs/launchd-output.log
```

## 📖 Usage

### Basic Booking

```bash
resy-rust book \
  --venue-id <VENUE_ID> \
  --party-size <SIZE> \
  --date <YYYY-MM-DD> \
  --times <HH:MM:SS,HH:MM:SS> \
  [--types <Indoor,Outdoor>] \
  [--dry-run]
```

### Competitive Mode (Default)

```bash
resy-rust book \
  --venue-id 79633 \
  --party-size 2 \
  --date 2025-10-25 \
  --times "18:00:00,19:00:00" \
  --threads 5              # Concurrent booking threads
  --retries 5              # Retries per thread
  --poll-interval-ms 250   # Poll every 250ms
  --poll-timeout-secs 120  # Give up after 2 minutes
```

### Options

| Flag | Description | Default |
|------|-------------|---------|
| `--venue-id` | Restaurant venue ID | Required |
| `--party-size` | Number of people | Required |
| `--date` | Reservation date (YYYY-MM-DD) | Required |
| `--times` | Preferred times (comma-separated) | Required |
| `--types` | Seating types (Indoor, Outdoor, etc.) | Any |
| `--threads` | Concurrent booking threads | 5 |
| `--retries` | Retry attempts per thread | 5 |
| `--poll-interval-ms` | Polling interval in milliseconds | 250 |
| `--poll-timeout-secs` | Maximum polling duration in seconds | 120 |
| `--log-file` | Custom log file path | Auto-generated |
| `--dry-run` | Test without booking | false |

## 📅 Scheduling (macOS)

Schedule a booking to run at a specific time:

```bash
./scripts/schedule-macos.sh "<DATETIME>" <VENUE_ID> <PARTY_SIZE> "<TIMES>"
```

### Examples

```bash
# Book for next Friday at 7pm
NEXT_FRIDAY=$(date -v+fri +%Y-%m-%d)
./scripts/schedule-macos.sh "$NEXT_FRIDAY 09:00:00" 58326 4 "19:00:00"

# Book 30 days in advance
TARGET_DATE=$(date -v+30d +%Y-%m-%d)
./scripts/schedule-macos.sh "$TARGET_DATE 09:00:00" 79633 2 "18:00:00,19:00:00"
```

### Manage Scheduled Jobs

```bash
# List jobs
launchctl list | grep resy

# View logs
tail -f ~/code/resy-cli/resy-rust/logs/launchd-output.log

# Cancel job
launchctl unload ~/Library/LaunchAgents/com.resy.booking.*.plist
rm ~/Library/LaunchAgents/com.resy.booking.*.plist
```

## 🎯 How It Works

1. **Fetches venue details** to verify restaurant exists
2. **Polls for slots** at configured interval until timeout
3. **Launches multiple threads** when slots are found
4. **Each thread attempts booking** with exponential backoff retries
5. **First successful thread wins** and stops all others
6. **Logs everything** to file and console

### Performance

- **Latency**: ~100-200ms from slot availability to booking
- **Concurrency**: 5 threads booking simultaneously
- **Success Rate**: High due to multi-threaded approach

## 🛠️ Development

```bash
# Build
cargo build --release

# Run tests
cargo test

# Check code
cargo clippy

# Format
cargo fmt
```

## 📦 Project Structure

```
resy-rust/
├── src/
│   ├── main.rs         # CLI entry point
│   ├── api.rs          # Resy API client
│   └── types.rs        # Data structures
├── scripts/
│   ├── schedule-macos.sh    # macOS scheduler
│   ├── test-laptop.sh       # Quick test
│   ├── run.sh              # Run with defaults
│   └── examples.sh         # Usage examples
├── Cargo.toml          # Dependencies
└── .env               # Credentials (gitignored)
```

## 🔐 Credentials

Get your Resy credentials:

1. Log into resy.com in browser
2. Open DevTools (F12) → Network tab
3. Make any request to api.resy.com
4. Find headers:
   - `authorization`: Extract the api_key value
   - `x-resy-auth-token`: Copy full token

Add to `.env`:
```
RESY_API_KEY=your_api_key_here
RESY_AUTH_TOKEN=your_token_here
```

## 📄 License

MIT

## 🤝 Contributing

Contributions welcome! Please open an issue or PR.

## ⚡ Tips

- **Use dry-run** to test before real bookings
- **Keep laptop awake** with `caffeinate` for scheduled bookings
- **Check logs** in `~/.resy-rust/logs/` for debugging
- **Multiple threads** increase success rate for competitive restaurants
- **Adjust poll interval** based on how competitive the restaurant is

## 🐛 Troubleshooting

### "No venues found"
- Check venue ID is correct
- Date might be too far in the future

### "Failed to fetch slots: 500"
- Resy API issue or rate limiting
- Try different time or wait a few minutes

### Scheduled job didn't run
- Check laptop wasn't asleep: `caffeinate -u -t 86400 &`
- Verify job loaded: `launchctl list | grep resy`
- Check logs: `cat logs/launchd-error.log`

### Authentication errors
- Verify credentials in `.env`
- Auth token might have expired (get new one from browser)
- No quotes needed around values in `.env`
