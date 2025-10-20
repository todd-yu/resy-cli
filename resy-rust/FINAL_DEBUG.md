# Final Debug - Show Raw Credential Bytes

The quotes you see in debug output like `"eyJ0..."` might just be Rust's debug formatter adding them for display. But let's verify what's **actually** being sent.

## Deploy Latest Binary

```bash
# On local machine
cd ~/code/resy-cli/resy-rust
cargo build --release
scp target/release/resy-rust ec2-user@your-ec2-ip:~/resy-cli/resy-rust/target/release/
```

## Run on EC2

```bash
ssh ec2-user@your-ec2-ip
cd ~/resy-cli/resy-rust
./scripts/run.sh --venue-id 79633 --times "17:00:00" --dry-run 2>&1 | tee final-debug.log
```

## What to Look For

The new debug output will show:

### 1. Raw credential values exactly as read from .env
```
DEBUG: Raw credential values:
  API Key raw: 'VbWk7s3L4KiK5fzlO7JDyVmt3Ah1cRkj'
  API Key len: 32
  Auth Token raw (first 50): 'eyJ0eXAiOiJKV1QiLCJhbGciOiJFUzI1NiJ9.eyJleHAiOjE3N...'
  Auth Token len: 352
```

**If you see quotes in the 'raw' output**, they're actually in the value!

### 2. The actual bytes
```
Auth Token bytes (first 20): [101, 121, 74, 48, 101, 88, 65, 105...]
```

- If first byte is `34`, that's a quote character `"`
- If first byte is `101`, that's the letter `e` (correct start of JWT)

### 3. After trimming
```
DEBUG: After trimming:
  API Key trimmed: 'VbWk7s3L4KiK5fzlO7JDyVmt3Ah1cRkj'
  Auth Token trimmed (first 50): 'eyJ0eXAiOiJKV1QiLCJhbGc...'
```

These should be IDENTICAL to the raw values if there are no quotes/whitespace.

## Analysis

Compare these values:

1. **If raw values have quotes** → Your .env file loading is wrong
2. **If raw values are clean but error persists** → Something else is wrong with the request
3. **If trimmed values differ from raw** → The trim code is working and found quotes

## Alternative: Check How .env is Being Loaded

On your EC2, check if the dotenv crate is reading the file correctly:

```bash
cd ~/resy-cli/resy-rust

# Show exact file contents
echo "=== .env file ==="
cat .env

# Show with all characters visible
echo "=== With special chars ==="
cat -A .env

# Show raw bytes of first line
echo "=== First line bytes ==="
head -1 .env | od -An -tx1

# Test manual sourcing
echo "=== Manual source test ==="
source .env
echo "API Key: '$RESY_API_KEY'"
echo "API Key length: ${#RESY_API_KEY}"
echo "First char of API key: ${RESY_API_KEY:0:1}"
```

If the manual source test shows clean values but the Rust app shows quotes, there's an issue with how the dotenv crate is parsing the file.

## Potential Fix: Explicit .env Format

Try recreating your .env with explicit format:

```bash
cd ~/resy-cli/resy-rust

# Backup
cp .env .env.backup-$(date +%s)

# Create with echo (no editor, no ambiguity)
rm .env
echo "RESY_API_KEY=VbWk7s3L4KiK5fzlO7JDyVmt3Ah1cRkj" > .env
echo "RESY_AUTH_TOKEN=eyJ0eXAiOiJKV1Qi..." >> .env

# Replace with your actual values above ^^^

# Verify - should show NO quotes
cat .env

# Verify bytes of first line
head -1 .env | od -An -tx1
# Should start with: 52 45 53 59 5f 41 50 49 (which is "RESY_API")
# NOT with: 22 (which is ")
```

## Check Rust Version Difference

```bash
# On EC2
rustc --version

# On laptop
rustc --version
```

Different Rust/dotenv versions might parse .env differently.

## The Nuclear Option

If nothing works, bypass .env entirely:

```bash
cd ~/resy-cli/resy-rust

# Export directly in shell
export RESY_API_KEY='VbWk7s3L4KiK5fzlO7JDyVmt3Ah1cRkj'
export RESY_AUTH_TOKEN='eyJ0eXAiOiJKV1QiLCJhbGc...'

# Run binary directly (skip run.sh which might reload .env)
./target/release/resy-rust book \
  --venue-id 79633 \
  --party-size 2 \
  --date 2025-10-25 \
  --times "17:00:00" \
  --dry-run
```

If this works, the issue is definitely in the .env file or how it's being loaded.

