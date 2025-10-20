# Still Getting 500 Error After test-connection.sh Passes?

## The Issue

Your `test-connection.sh` works (curl gets 200 OK), but the Rust binary still gets 500 errors.

This means **the credentials work, but something is different between how curl and the Rust app are using them**.

## Quick Fixes to Try

### Fix 1: Hidden Characters in .env

Run the automated fixer:

```bash
cd ~/resy-cli/resy-rust
./scripts/fix-env.sh
```

This removes:
- Windows line endings (`\r\n`)
- UTF-8 BOM
- Quotes around values
- Spaces around `=` signs
- Trailing whitespace

Then test:
```bash
./scripts/test-connection.sh 79633
./scripts/run.sh --venue-id 79633 --times "17:00:00" --dry-run
```

### Fix 2: Recreate .env from Scratch

Sometimes the file is corrupted. Start fresh:

```bash
cd ~/resy-cli/resy-rust

# Back up old file
mv .env .env.old

# Create new file manually
cat > .env << 'EOF'
RESY_API_KEY=paste_your_api_key_here
RESY_AUTH_TOKEN=paste_your_auth_token_here
EOF

# Now edit and paste your ACTUAL credentials
nano .env
# Paste your credentials (no quotes, no spaces)
# Save: Ctrl+O, Enter, Ctrl+X
```

### Fix 3: Use Environment Variables Directly

Bypass the .env file entirely:

```bash
cd ~/resy-cli/resy-rust

# Get your credentials
source .env

# Run with explicit environment variables
RESY_API_KEY="$RESY_API_KEY" RESY_AUTH_TOKEN="$RESY_AUTH_TOKEN" \
  ./target/release/resy-rust book \
  --venue-id 79633 \
  --party-size 2 \
  --date 2025-10-25 \
  --times "17:00:00" \
  --dry-run
```

If this works, your .env file has a formatting issue.

### Fix 4: Check What Rust Actually Sees

Run the detailed diagnostic:

```bash
./scripts/debug-env.sh
```

This will show you:
- Exact file contents with special characters visible
- What bash reads vs what Rust reads
- Any hidden formatting issues
- What the binary actually sees

Look for warnings like:
- `⚠️ WARNING: File has Windows line endings`
- `⚠️ WARNING: API Key has trailing whitespace`
- `⚠️ WARNING: .env file contains quotes`

## Deep Dive: Why This Happens

The Rust `dotenv` crate and bash `source` command parse files slightly differently:

1. **Whitespace handling**: Bash is more forgiving
2. **Quote handling**: Bash strips quotes, dotenv might not
3. **Line endings**: Rust might include `\r` in the value on Windows files
4. **BOM**: Rust might include UTF-8 BOM in first value

## Manual Check

Look at the actual bytes in your .env file:

```bash
# Show all characters including hidden ones
cat -A .env

# Should look like:
# RESY_API_KEY=abc123$
# RESY_AUTH_TOKEN=xyz789$

# BAD signs:
# RESY_API_KEY=abc123^M$           # Has ^M (Windows)
# RESY_API_KEY="abc123"$           # Has quotes
# RESY_API_KEY = abc123$           # Has spaces
# ^M at end of lines               # Windows line endings
```

Check the actual hex:

```bash
hexdump -C .env | head -20

# Look for:
# 0d 0a = Windows line ending (bad)
# ef bb bf = UTF-8 BOM at start (bad)
# 22 = double quote (bad if around values)
```

## The Nuclear Option

If nothing works, rebuild everything:

```bash
cd ~/resy-cli/resy-rust

# 1. Clean build
cargo clean
cargo build --release

# 2. Delete and recreate .env
rm .env

# 3. Create fresh .env using echo (avoids editors)
echo "RESY_API_KEY=YOUR_ACTUAL_KEY" > .env
echo "RESY_AUTH_TOKEN=YOUR_ACTUAL_TOKEN" >> .env

# Replace YOUR_ACTUAL_KEY and YOUR_ACTUAL_TOKEN above with your real credentials

# 4. Verify format
cat -A .env
# Should show:
# RESY_API_KEY=your_key_here$
# RESY_AUTH_TOKEN=your_token_here$

# 5. Test
./scripts/test-connection.sh 79633
./scripts/run.sh --venue-id 79633 --times "17:00:00" --dry-run
```

## Still Failing?

At this point, let's get more information:

```bash
# 1. Run with debug output
cd ~/resy-cli/resy-rust
RUST_LOG=debug ./target/release/resy-rust book \
  --venue-id 79633 \
  --party-size 2 \
  --date 2025-10-25 \
  --times "17:00:00" \
  --dry-run 2>&1 | tee debug.log

# 2. Check the debug.log for clues about what's happening

# 3. Compare working curl vs failing Rust:

# What curl sends (working):
source .env
curl -v "https://api.resy.com/2/config?venue_id=79633" \
  -H "authorization: ResyAPI api_key=\"${RESY_API_KEY}\"" \
  -H "x-resy-auth-token: ${RESY_AUTH_TOKEN}" \
  2>&1 | grep -A 20 "^>"

# The headers should look like:
# > authorization: ResyAPI api_key="VbCklWA54m1ktUbf"
# > x-resy-auth-token: eyJ0eXAiOiJKV1Q...
```

## AWS-Specific Issues

### Check Security Group

Your EC2 instance needs outbound HTTPS:

```bash
# Test HTTPS connectivity
curl -v https://api.resy.com 2>&1 | grep "Connected to"

# Should see:
# * Connected to api.resy.com (IP) port 443
```

If this fails, check AWS Security Group allows outbound on port 443.

### Check Region/Network

```bash
# Check your EC2 region
ec2-metadata --availability-zone

# Some regions might have different Resy API behavior
# Try setting a different User-Agent:
export USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"
```

### Check Time Sync

```bash
# Resy might check request timestamps
date
# Should match real time

# If wrong:
sudo timedatectl set-ntp true
```

## Next Steps

1. **Run debug-env.sh**: `./scripts/debug-env.sh`
2. **Try fix-env.sh**: `./scripts/fix-env.sh`
3. **Recreate .env**: Use echo or cat, not nano/vim
4. **Test with env vars**: Bypass .env file
5. **Check AWS settings**: Security group, time sync

If you've done all this and still failing, send the output of:

```bash
./scripts/debug-env.sh > full-debug.log 2>&1
cat full-debug.log
```

