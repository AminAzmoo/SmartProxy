#!/bin/bash

# SmartProxy - Quick Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/AminAzmoo/SmartProxy/main/install.sh | bash

set -e

echo "📦 Installing SmartProxy..."

# Clone or update repository
if [ -d "$HOME/.smartproxy-repo" ]; then
    cd "$HOME/.smartproxy-repo"
    git pull origin main > /dev/null 2>&1
else
    git clone --depth 1 https://github.com/AminAzmoo/SmartProxy.git "$HOME/.smartproxy-repo" > /dev/null 2>&1
    cd "$HOME/.smartproxy-repo"
fi

# Make scripts executable
chmod +x smartproxy.sh proxy_finder.py

# Create symlink in /usr/local/bin (requires sudo)
echo "🔗 Creating symlink..."
sudo ln -sf "$(pwd)/smartproxy.sh" /usr/local/bin/smartproxy 2>/dev/null || {
    echo "⚠️  Adding alias to ~/.bashrc instead..."
    echo "alias smartproxy='$HOME/.smartproxy-repo/smartproxy.sh'" >> ~/.bashrc
    source ~/.bashrc
}

echo "✅ SmartProxy installed successfully!"
echo ""
echo "🚀 Quick start:"
echo "   smartproxy          # Interactive menu"
echo "   smartproxy --find   # Find best proxy"
echo "   smartproxy --list   # Show history"
echo ""
