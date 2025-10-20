#!/bin/bash

# Setup script for cloud VM
# Run this once when you first deploy to the VM

set -e

echo "════════════════════════════════════════════════════════"
echo "Resy CLI - Cloud VM Setup"
echo "════════════════════════════════════════════════════════"
echo ""

# Check if running on Linux
if [[ ! "$OSTYPE" == "linux-gnu"* ]]; then
    echo "⚠️  Warning: This script is designed for Linux VMs"
fi

# Install dependencies
echo "📦 Installing dependencies..."

# Detect package manager
if command -v apt-get &> /dev/null; then
    PKG_MANAGER="apt-get"
    sudo apt-get update
    sudo apt-get install -y at cron curl build-essential
elif command -v yum &> /dev/null; then
    PKG_MANAGER="yum"
    sudo yum install -y at cronie curl gcc gcc-c++ make
elif command -v dnf &> /dev/null; then
    PKG_MANAGER="dnf"
    sudo dnf install -y at cronie curl gcc gcc-c++ make
else
    echo "❌ Unknown package manager. Please install 'at' and 'cron' manually."
    exit 1
fi

echo "✅ Dependencies installed"
echo ""

# Install Rust if not present
if ! command -v cargo &> /dev/null; then
    echo "🦀 Installing Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
    echo "✅ Rust installed"
else
    echo "✅ Rust already installed"
fi
echo ""

# Enable and start at daemon
echo "⏰ Setting up scheduling services..."
if command -v systemctl &> /dev/null; then
    sudo systemctl enable atd 2>/dev/null || true
    sudo systemctl start atd 2>/dev/null || true
    sudo systemctl enable cron 2>/dev/null || sudo systemctl enable crond 2>/dev/null || true
    sudo systemctl start cron 2>/dev/null || sudo systemctl start crond 2>/dev/null || true
else
    sudo service atd start 2>/dev/null || true
    sudo service cron start 2>/dev/null || sudo service crond start 2>/dev/null || true
fi
echo "✅ Scheduling services configured"
echo ""

# Set timezone (optional but recommended)
echo "🌍 Current timezone: $(timedatectl 2>/dev/null | grep "Time zone" || date +%Z)"
read -p "Do you want to set timezone? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Common timezones:"
    echo "  America/New_York (EST/EDT)"
    echo "  America/Chicago (CST/CDT)"
    echo "  America/Los_Angeles (PST/PDT)"
    echo "  America/Denver (MST/MDT)"
    echo ""
    read -p "Enter timezone (or press Enter to skip): " TIMEZONE
    if [ -n "$TIMEZONE" ]; then
        sudo timedatectl set-timezone "$TIMEZONE" 2>/dev/null || sudo ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
        echo "✅ Timezone set to $TIMEZONE"
    fi
fi
echo ""

# Build the project
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ -f "$PROJECT_ROOT/Cargo.toml" ]; then
    echo "🔨 Building Resy CLI..."
    cd "$PROJECT_ROOT"
    cargo build --release
    echo "✅ Build complete"
    echo ""
else
    echo "⚠️  Cargo.toml not found. Make sure you're in the resy-rust directory."
fi

# Create .env file if it doesn't exist
if [ ! -f "$PROJECT_ROOT/.env" ]; then
    echo "🔐 Setting up credentials..."
    if [ -f "$PROJECT_ROOT/env.example" ]; then
        cp "$PROJECT_ROOT/env.example" "$PROJECT_ROOT/.env"
        echo "Created .env file from env.example"
        echo ""
        echo "⚠️  IMPORTANT: Edit .env file with your credentials:"
        echo "   nano $PROJECT_ROOT/.env"
        echo ""
    else
        echo "Creating new .env file..."
        cat > "$PROJECT_ROOT/.env" << EOF
RESY_API_KEY=your_api_key_here
RESY_AUTH_TOKEN=your_auth_token_here
EOF
        echo "✅ Created .env file"
        echo ""
        echo "⚠️  IMPORTANT: Edit .env file with your credentials:"
        echo "   nano $PROJECT_ROOT/.env"
        echo ""
    fi
else
    echo "✅ .env file already exists"
fi

# Create logs directory
mkdir -p "$PROJECT_ROOT/logs"
echo "✅ Created logs directory"
echo ""

# Make scripts executable
chmod +x "$SCRIPT_DIR"/*.sh
echo "✅ Made scripts executable"
echo ""

echo "════════════════════════════════════════════════════════"
echo "🎉 Setup complete!"
echo "════════════════════════════════════════════════════════"
echo ""
echo "Next steps:"
echo "1. Edit .env with your Resy credentials:"
echo "   nano $PROJECT_ROOT/.env"
echo ""
echo "2. Test the CLI:"
echo "   $SCRIPT_DIR/run.sh"
echo ""
echo "3. Schedule a booking:"
echo "   $SCRIPT_DIR/schedule.sh --time '09:00' --venue-id 58326 --times '19:00:00' --no-dry-run"
echo ""
echo "4. View logs:"
echo "   tail -f $PROJECT_ROOT/logs/*.log"
echo ""
echo "For more help:"
echo "   $SCRIPT_DIR/schedule.sh --help"
echo ""

