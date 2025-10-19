# Quick Start Guide

## 1. Setup (30 seconds)

```bash
# Navigate to the rust directory
cd resy-rust

# Copy the example env file
cp env.example .env

# Edit .env with your credentials (see below)
nano .env  # or use your preferred editor
```

## 2. Get Your Credentials

### Method 1: Browser DevTools (Easiest)
1. Visit [resy.com](https://resy.com) and log in
2. Press `F12` to open DevTools
3. Go to **Network** tab
4. Search for a restaurant or make any action
5. Click on any `api.resy.com` request
6. Look at **Request Headers**:
   - Find `authorization: ResyAPI api_key="YOUR_KEY"` → Copy YOUR_KEY
   - Find `x-resy-auth-token: YOUR_TOKEN` → Copy YOUR_TOKEN
7. Paste these into your `.env` file

### Method 2: From Original CLI
If you've already set up the Go version:
```bash
# Your config is in ~/.resy-cli/config.yaml
cat ~/.resy-cli/config.yaml
```

## 3. Build & Run

```bash
# Build (first time only, ~30 seconds)
cargo build --release

# Run a dry-run test
cargo run --release -- book \
  --venue-id 123 \
  --party-size 2 \
  --date 2025-10-25 \
  --times "18:00:00,19:00:00" \
  --dry-run
```

## 4. Real Booking Example

```bash
# Book at a specific venue for 2 people
./target/release/resy-rust book \
  --venue-id 5678 \
  --party-size 2 \
  --date 2025-11-15 \
  --times "18:00:00,18:30:00,19:00:00"
```

## Common Use Cases

### Any available time on a date
```bash
cargo run -- book --venue-id 123 --party-size 4 --date 2025-10-30 --times "18:00:00,18:30:00,19:00:00,19:30:00"
```

### Specific table type (Indoor, Outdoor, Bar, etc.)
```bash
cargo run -- book \
  --venue-id 123 \
  --party-size 2 \
  --date 2025-10-30 \
  --times "19:00:00" \
  --types "Indoor,Bar"
```

### Test without booking (dry run)
```bash
cargo run -- book \
  --venue-id 123 \
  --party-size 2 \
  --date 2025-10-30 \
  --times "19:00:00" \
  --dry-run
```

## Tips

- ⚡ **Time format**: Use `HH:MM:SS` (e.g., `18:00:00`, not `6pm`)
- 📅 **Date format**: Use `YYYY-MM-DD` (e.g., `2025-10-30`)
- 🎯 **Multiple options**: Comma-separate times and types for better chances
- 🏃 **Dry run**: Always test with `--dry-run` first to see available slots
- 🔧 **Installation**: After building, copy `./target/release/resy-rust` anywhere in your PATH

## Troubleshooting

**"RESY_API_KEY not found"**
→ Make sure `.env` file exists in the `resy-rust` directory

**"Failed to fetch slots: 401"**
→ Your credentials are incorrect or expired. Get fresh ones from resy.com

**"No matching slots found"**
→ Try different times, or run with `--dry-run` to see what's available

**Build errors**
→ Make sure you have Rust installed: `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`

