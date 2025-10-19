# Resy Rust CLI

A clean, fast Rust implementation of the Resy booking CLI.

## Features

- 🚀 Fast and efficient Rust implementation
- 🔒 Secure credential management via `.env` file
- 🎯 Filter by reservation times and table types
- 🏃 Dry run mode for testing
- ✨ Beautiful CLI output with emojis

## Setup

1. **Install Rust** (if not already installed):
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   ```

2. **Create a `.env` file** with your Resy credentials:
   ```bash
   cp env.example .env
   # Edit .env and add your credentials
   ```

3. **Build the project**:
   ```bash
   cargo build --release
   ```

## Usage

### Book a reservation

```bash
# Basic booking - any available time
cargo run -- book \
  --venue-id 12345 \
  --party-size 2 \
  --date 2025-10-25

# With specific times (comma-separated)
cargo run -- book \
  --venue-id 12345 \
  --party-size 2 \
  --date 2025-10-25 \
  --times "18:00:00,18:30:00,19:00:00"

# With specific table types
cargo run -- book \
  --venue-id 12345 \
  --party-size 2 \
  --date 2025-10-25 \
  --times "18:00:00,18:30:00" \
  --types "Indoor,Bar"

# Dry run (don't actually book)
cargo run -- book \
  --venue-id 12345 \
  --party-size 2 \
  --date 2025-10-25 \
  --times "18:00:00" \
  --dry-run
```

### Run the compiled binary

After building with `cargo build --release`, you can run:

```bash
./target/release/resy-rust book --venue-id 12345 --party-size 2 --date 2025-10-25 --times "18:00:00"
```

## Project Structure

```
resy-rust/
├── Cargo.toml          # Dependencies and project metadata
├── .env.example        # Example environment variables
├── README.md           # This file
└── src/
    ├── main.rs         # CLI entry point and command handling
    ├── api.rs          # Resy API client implementation
    └── types.rs        # Data structures and models
```

## Dependencies

- **clap** (4.5) - Modern CLI argument parsing with derive macros
- **reqwest** (0.12) - High-performance async HTTP client
- **tokio** (1.40) - Fast async runtime
- **serde** (1.0) - Zero-copy serialization/deserialization
- **dotenv** (0.15) - Environment variable management
- **anyhow** (1.0) - Ergonomic error handling
- **urlencoding** (2.1) - URL-safe string encoding

## How It Works

1. **Fetch Venue Details** - Gets restaurant information
2. **Fetch Available Slots** - Retrieves all available reservations for the date
3. **Filter Matching Slots** - Finds slots matching your time/type preferences
4. **Get Booking Token** - Obtains a token for the selected slot
5. **Book Reservation** - Completes the booking with payment info

## Finding Your Credentials

1. Go to [resy.com](https://resy.com) and log in
2. Open browser DevTools (F12)
3. Go to the Network tab
4. Make a reservation or search for restaurants
5. Look for API calls to `api.resy.com`
6. In the request headers, find:
   - `authorization` header contains your API key
   - `x-resy-auth-token` header contains your auth token

## License

MIT

