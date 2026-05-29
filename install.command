#!/bin/bash
# Double-click this file to install everything.
# If macOS blocks it: right-click -> Open -> Open.

set -u

LOG="$HOME/Desktop/claude-install-log.txt"
exec > >(tee -a "$LOG") 2>&1

banner() {
  echo ""
  echo "============================================================"
  echo "  $1"
  echo "============================================================"
}

say() { echo ">>> $1"; }
ok()  { echo "    [OK] $1"; }
warn(){ echo "    [!!] $1"; }

pause_on_exit() {
  echo ""
  echo "Log saved to: $LOG"
  echo ""
  read -n 1 -s -r -p "Press any key to close this window..."
  echo ""
}
trap pause_on_exit EXIT

clear
cat <<'EOF'
   ______ _                  _         _____           _        _ _
  / _____| |                | |       (_____)         | |      | | |
 | /     | | _____  _   _ __| |_____     _   ____  ___| |_ ____| | |
 | |     | |(____ || | | / _  | ___ |   | | |  _ \/___)  _) _  | | |
 | \_____| |/ ___ || |_| ( (_| | ____|  _| |_| | | |___ | |_( (_| | | |
  \______)_|\_____|\____/\____|_____) (_____)_| |_(___/ \___)_||_|_|_|

  C3 Mac Setup - one-click installer
EOF

echo ""
echo "This will install:"
echo "  - Xcode Command Line Tools (compilers)"
echo "  - Homebrew (Mac package manager)"
echo "  - Git + GitHub CLI (gh)"
echo "  - Node.js"
echo "  - jq, ripgrep, wget (small command-line helpers)"
echo "  - Warp (terminal)"
echo "  - VS Code (code editor)"
echo "  - Claude Desktop + Claude Code CLI"
echo "  - Microsoft 365 + Chrome DevTools MCP servers"
echo "  - skill-creator skill + understand-anything plugin"
echo "  - ~/Dev folder for your projects"
echo ""
echo "You may be asked for your Mac login password (you won't see it as you type)."
echo "This can take 15-30 minutes depending on your internet speed."
echo ""
read -n 1 -s -r -p "Press any key to begin..."
echo ""

# Create ~/Dev up-front so it lands even if a later step bails out.
if [ ! -d "$HOME/Dev" ]; then
  mkdir -p "$HOME/Dev"
  ok "Created ~/Dev - put all your coding projects in here."
else
  ok "~/Dev already exists."
fi

# ---------- 1. Xcode Command Line Tools ----------
banner "1/9  Xcode Command Line Tools"
if xcode-select -p >/dev/null 2>&1; then
  ok "Already installed."
else
  say "Installing Xcode Command Line Tools (a popup will appear - click Install)."
  xcode-select --install || true
  echo ""
  echo "    Waiting for you to finish the Xcode CLT install in the popup..."
  until xcode-select -p >/dev/null 2>&1; do
    sleep 10
    echo "    ...still waiting (click Install in the popup if you haven't)"
  done
  ok "Xcode CLT installed."
fi

# ---------- 2. Homebrew ----------
banner "2/9  Homebrew"
if command -v brew >/dev/null 2>&1; then
  ok "Already installed."
else
  say "Installing Homebrew (will ask for your Mac password)."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Add brew to PATH for this session and for future shells
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
  BREW_PREFIX="/opt/homebrew"
else
  BREW_PREFIX="/usr/local"
fi
eval "$($BREW_PREFIX/bin/brew shellenv)"

# Persist to zshrc if not already there
ZSHRC="$HOME/.zshrc"
touch "$ZSHRC"
if ! grep -q "brew shellenv" "$ZSHRC"; then
  echo "" >> "$ZSHRC"
  echo "# Homebrew" >> "$ZSHRC"
  echo "eval \"\$($BREW_PREFIX/bin/brew shellenv)\"" >> "$ZSHRC"
  ok "Added Homebrew to your shell PATH."
fi

# ---------- 3. Git, GitHub CLI, Node, CLI utils ----------
banner "3/9  Git, GitHub CLI, Node.js, CLI utilities"
brew install git gh node jq ripgrep wget
ok "git:  $(git --version)"
ok "gh:   $(gh --version | head -1)"
ok "node: $(node --version)"
ok "npm:  $(npm --version)"
ok "jq, ripgrep, wget installed."

# Fix root-owned ~/.npm if a prior 'sudo npm' poisoned it. Harmless if already healthy.
if [ -d "$HOME/.npm" ] && find "$HOME/.npm" -user root -print -quit 2>/dev/null | grep -q .; then
  say "Found root-owned files in ~/.npm (from a previous 'sudo npm' run). Fixing..."
  sudo chown -R "$(id -u):$(id -g)" "$HOME/.npm"
  ok "~/.npm ownership repaired."
fi

# Git identity (only set if missing - never clobber existing)
if [ -z "$(git config --global user.email || true)" ]; then
  echo ""
  say "Setting up your git identity (used to label your code commits)."
  read -r -p "    Your full name (e.g. Jane Doe): " GIT_NAME
  read -r -p "    Your work email: " GIT_EMAIL
  git config --global user.name  "$GIT_NAME"
  git config --global user.email "$GIT_EMAIL"
  git config --global init.defaultBranch main
  git config --global pull.rebase false
  ok "Git identity set: $GIT_NAME <$GIT_EMAIL>"
else
  ok "Git identity already set ($(git config --global user.email))."
fi

# ---------- 4. Warp terminal ----------
banner "4/9  Warp"
if [ -d "/Applications/Warp.app" ]; then
  ok "Already installed."
else
  # The --cask invocation has been flaky on some machines; fall back to bare
  # 'brew install warp' which lets Homebrew auto-resolve to the cask.
  brew install --cask warp || brew install warp || true
  if [ -d "/Applications/Warp.app" ]; then
    ok "Warp installed."
  else
    warn "Warp install did not complete. Manually run:  brew install warp"
  fi
fi

# Set Warp as the default handler for terminal-y file types.
say "Setting Warp as your default terminal..."
brew install duti >/dev/null 2>&1 || true
WARP_BUNDLE_ID="dev.warp.Warp-Stable"
duti -s "$WARP_BUNDLE_ID" com.apple.terminal.shell-script all 2>/dev/null || true
duti -s "$WARP_BUNDLE_ID" public.shell-script all 2>/dev/null || true
duti -s "$WARP_BUNDLE_ID" public.unix-executable all 2>/dev/null || true
duti -s "$WARP_BUNDLE_ID" .command all 2>/dev/null || true
duti -s "$WARP_BUNDLE_ID" .sh all 2>/dev/null || true
ok "Warp set as default terminal."

# ---------- 5. VS Code + Chrome ----------
banner "5/9  VS Code + Google Chrome"
if [ -d "/Applications/Visual Studio Code.app" ]; then
  ok "VS Code already installed."
else
  brew install --cask visual-studio-code
fi
if [ -d "/Applications/Google Chrome.app" ]; then
  ok "Chrome already installed."
else
  brew install --cask google-chrome
fi

# ---------- 6. Claude Desktop ----------
banner "6/9  Claude Desktop"
if [ -d "/Applications/Claude.app" ]; then
  ok "Already installed."
else
  brew install --cask claude
fi

# ---------- 7. Claude Code CLI ----------
banner "7/9  Claude Code CLI"

# If a previous Homebrew-managed claude-code is installed, remove it first
# so the official native installer below owns the binary.
if brew list --cask claude-code >/dev/null 2>&1; then
  say "Found a Homebrew-managed claude-code. Uninstalling so the official installer can take over..."
  brew uninstall --cask claude-code || true
  ok "Removed brew cask claude-code."
fi

say "Installing Claude Code via the official installer (claude.ai/install.sh)..."
curl -fsSL https://claude.ai/install.sh | bash

# The installer drops the binary in ~/.local/bin. Make sure it's on PATH for
# both this session and future shells.
export PATH="$HOME/.local/bin:$PATH"
if ! grep -q '.local/bin' "$ZSHRC"; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$ZSHRC"
  ok "Added ~/.local/bin to your shell PATH."
fi

ok "claude: $(claude --version 2>/dev/null || echo 'installed')"

# ---------- 8. MS365 MCP ----------
banner "8/9  Microsoft 365 MCP server (C3 build)"
say "Registering the C3-flavored MS365 MCP server with Claude Code..."
# Remove any prior registration so this is idempotent
claude mcp remove microsoft-365 --scope user 2>/dev/null || true
claude mcp remove microsoft-365 2>/dev/null || true

# Uses currenthandle/ms365-mcp with the C3 Azure app registration.
# --scope user => available in every project this user opens with Claude.
# The shell command auto-installs the ms365-mcp binary to ~/.local/bin on first run.
claude mcp add-json --scope user microsoft-365 '{
  "type": "stdio",
  "command": "sh",
  "args": [
    "-c",
    "test -x $HOME/.local/bin/ms365-mcp || (curl -fsSL https://raw.githubusercontent.com/currenthandle/ms365-mcp/main/install.sh | sh) && exec $HOME/.local/bin/ms365-mcp"
  ],
  "env": {
    "MS365_CLIENT_ID": "4528f54a-3d79-4674-88dd-9a0f0c48a6ad",
    "MS365_TENANT_ID": "53ad779a-93e7-485c-ba20-ac8290d7252b"
  }
}'
ok "MS365 MCP registered. First time you use it in Claude, a browser pops up to log in to your C3 Microsoft account."

# Chrome DevTools MCP (lets Claude drive Chrome - inspect pages, run JS, debug)
say "Registering Chrome DevTools MCP at user scope..."
claude mcp remove chrome-devtools --scope user 2>/dev/null || true
claude mcp remove chrome-devtools --scope local 2>/dev/null || true
claude mcp remove chrome-devtools 2>/dev/null || true
claude mcp add chrome-devtools --scope user npx chrome-devtools-mcp@latest
ok "Chrome DevTools MCP registered."

# ---------- 9. Skills & Plugins ----------
banner "9/9  Skills and plugins"

# Resolve the claude binary explicitly - in this same shell session, ~/.local/bin
# was added to PATH above, but on some setups (esp. when `claude` was also
# brew-installed previously and brew shellenv ran after) the cache can be stale.
CLAUDE_BIN="$(command -v claude || true)"
if [ -z "$CLAUDE_BIN" ] && [ -x "$HOME/.local/bin/claude" ]; then
  CLAUDE_BIN="$HOME/.local/bin/claude"
fi
if [ -z "$CLAUDE_BIN" ]; then
  warn "Could not find the 'claude' binary on PATH. Skipping plugin install."
  warn "After this finishes, open a new terminal and run:"
  warn "  claude plugin marketplace add Lum1104/Understand-Anything"
  warn "  claude plugin install understand-anything"
else
  ok "Using claude binary at: $CLAUDE_BIN"
fi

# --- 9a. Anthropic skill-creator (a skill that helps you write skills) ---
say "Installing Anthropic 'skill-creator' skill..."
SKILLS_DIR="$HOME/.claude/skills"
mkdir -p "$SKILLS_DIR"
TMP_SKILLS=$(mktemp -d)
if git clone --depth 1 https://github.com/anthropics/skills "$TMP_SKILLS/anthropic-skills"; then
  rm -rf "$SKILLS_DIR/skill-creator"
  cp -R "$TMP_SKILLS/anthropic-skills/skills/skill-creator" "$SKILLS_DIR/skill-creator"
  rm -rf "$TMP_SKILLS"
  if [ -f "$SKILLS_DIR/skill-creator/SKILL.md" ]; then
    ok "skill-creator installed at ~/.claude/skills/skill-creator"
  else
    warn "skill-creator copy looks incomplete - check ~/.claude/skills/skill-creator"
  fi
else
  warn "git clone of anthropics/skills failed - skipping skill-creator."
  warn "Re-run installer or manually:  git clone https://github.com/anthropics/skills && cp -R skills/skills/skill-creator ~/.claude/skills/"
fi

# --- 9b. Understand-Anything plugin (Lum1104) via Claude Code plugin marketplace ---
if [ -n "$CLAUDE_BIN" ]; then
  say "Adding 'understand-anything' marketplace..."
  if "$CLAUDE_BIN" plugin marketplace add Lum1104/Understand-Anything --scope user; then
    ok "Marketplace added."
  else
    warn "Failed to add marketplace - skipping understand-anything plugin."
    warn "Run manually:  claude plugin marketplace add Lum1104/Understand-Anything"
  fi

  say "Installing 'understand-anything' plugin..."
  if "$CLAUDE_BIN" plugin install understand-anything --scope user; then
    # Verify it actually shows up
    if "$CLAUDE_BIN" plugin list 2>/dev/null | grep -q "understand-anything"; then
      ok "understand-anything plugin installed and verified."
    else
      warn "Plugin install command succeeded but plugin not visible in 'claude plugin list'. Restart Claude Code to refresh."
    fi
  else
    warn "Failed to install understand-anything plugin."
    warn "Run manually:  claude plugin install understand-anything"
  fi
fi

# ---------- Done ----------
banner "All done!"
cat <<'EOF'

What to do next:
  1. Open Warp (in your Applications folder).
  2. In Warp, type:  cd ~/Dev    (this is where your projects live)
  3. Type:  claude
       - It will walk you through signing in to Anthropic.
  4. Open Claude Desktop (Applications folder) and sign in too.
  5. Sign in to GitHub from the terminal:  gh auth login
       - Pick: GitHub.com -> HTTPS -> Yes -> Login with a web browser
       - This handles ALL git authentication. You do NOT need to set up
         SSH keys - that's the old way and is not needed.
  6. The first time you ask Claude to use Microsoft 365, it will pop open
     a browser to sign in to your work account.

If anything looks broken, send the log file on your Desktop:
  ~/Desktop/claude-install-log.txt

EOF
