#!/usr/bin/env bash
set -euo pipefail

# ==========================================================
# Gitleaks Global Pre-Commit Hook Installer (Simplified)
# ==========================================================
# Responsibilities:
# 1. Install gitleaks if missing
# 2. Create global config + custom rules template
# 3. Configure a global hooksPath (Windows compatible)
# 4. Write cross-platform hook (bash + optional .bat)
# ==========================================================

# -------- Utility / Environment Detection --------
log(){ printf "[gitleaks-install] %s\n" "$*"; }
warn(){ printf "[gitleaks-install][WARN] %s\n" "$*"; }
die(){ printf "[gitleaks-install][ERROR] %s\n" "$*"; exit 1; }

OSTYPE_LOWER="${OSTYPE,,}" 2>/dev/null || OSTYPE_LOWER="$OSTYPE"
IS_WSL=false
grep -qi microsoft /proc/version 2>/dev/null && IS_WSL=true
IS_MSYS=false
[[ "$OSTYPE_LOWER" == msys* || "$OSTYPE_LOWER" == cygwin* ]] && IS_MSYS=true
IS_MAC=false
[[ "$OSTYPE_LOWER" == darwin* ]] && IS_MAC=true
IS_LINUX=false
[[ "$OSTYPE_LOWER" == linux* ]] && IS_LINUX=true
IS_WINDOWS_NATIVE=false
[[ -n "${WINDIR:-}" ]] && IS_WINDOWS_NATIVE=true

detect_powershell(){
  local ps=""
  for c in powershell.exe pwsh.exe "/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe" "/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"; do
    command -v "$c" &>/dev/null && { ps="$c"; break; }
  done
  echo "$ps"
}
POWERSHELL_CMD=$(detect_powershell)

windows_path(){
  # Convert a POSIX path to Windows style if possible
  local p="$1"
  if command -v cygpath &>/dev/null; then
    cygpath -w "$p"
  else
    # crude fallback: /c/Users/name -> C:\Users\name
    if [[ "$p" =~ ^/([a-zA-Z])/(.*)$ ]]; then
      local drive="${BASH_REMATCH[1]^^}" rest="${BASH_REMATCH[2]}"
      echo "${drive}:\\${rest//\//\\}"
    else
      echo "$p"
    fi
  fi
}

# -------- Download Helper --------
download_file(){
  local url="$1" out="$2"
  if command -v curl &>/dev/null; then
    curl -sSfL "$url" -o "$out" || return 1
  elif command -v wget &>/dev/null; then
    wget -q "$url" -O "$out" || return 1
  elif [[ -n "$POWERSHELL_CMD" ]]; then
    local win_out=$(windows_path "$out")
    "$POWERSHELL_CMD" -Command "\$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -Uri '$url' -OutFile '$win_out'" || return 1
  else
    return 1
  fi
}

# -------- Install Gitleaks (if missing) --------
install_gitleaks(){
  if command -v gitleaks &>/dev/null; then
    log "Gitleaks already present: $(command -v gitleaks)"
    return 0
  fi
  log "Installing gitleaks..."
  local arch="$(uname -m)"; case "$arch" in x86_64) arch="x64";; aarch64|arm64) arch="arm64";; *) die "Unsupported arch: $arch";; esac
  local latest=""
  if [[ -n "$POWERSHELL_CMD" && ( $IS_MSYS == true || $IS_WINDOWS_NATIVE == true ) ]]; then
    latest=$($POWERSHELL_CMD -Command "(Invoke-RestMethod -Uri 'https://api.github.com/repos/gitleaks/gitleaks/releases/latest').tag_name" 2>/dev/null | tr -d '\r')
  elif command -v curl &>/dev/null; then
    latest=$(curl -s https://api.github.com/repos/gitleaks/gitleaks/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^\"]+)".*/\1/')
  elif command -v wget &>/dev/null; then
    latest=$(wget -qO- https://api.github.com/repos/gitleaks/gitleaks/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^\"]+)".*/\1/')
  fi
  [[ -z "$latest" ]] && die "Unable to fetch latest gitleaks release tag"
  local os_pkg="" install_dir="" bin_name="gitleaks"
  if $IS_MAC; then os_pkg="darwin"; install_dir="$HOME/.local/bin";
  elif $IS_LINUX && ! $IS_MSYS; then os_pkg="linux"; install_dir="$HOME/.local/bin";
  else os_pkg="windows"; install_dir="$HOME/bin"; bin_name="gitleaks.exe"; fi
  mkdir -p "$install_dir"
  if [[ "$os_pkg" == windows ]]; then
    download_file "https://github.com/gitleaks/gitleaks/releases/download/${latest}/gitleaks_${latest#v}_${os_pkg}_${arch}.zip" /tmp/gitleaks.zip || die "Download failed"
    unzip -qo /tmp/gitleaks.zip gitleaks.exe -d /tmp || die "Unzip failed"
    mv /tmp/gitleaks.exe "$install_dir/" || die "Move failed"
    rm -f /tmp/gitleaks.zip
  else
    download_file "https://github.com/gitleaks/gitleaks/releases/download/${latest}/gitleaks_${latest#v}_${os_pkg}_${arch}.tar.gz" /tmp/gitleaks.tgz || die "Download failed"
    tar -xzf /tmp/gitleaks.tgz -C /tmp || die "Extract failed"
    mv /tmp/gitleaks "$install_dir/" || die "Move failed"
    chmod +x "$install_dir/gitleaks"
    rm -f /tmp/gitleaks.tgz
  fi
  [[ ":$PATH:" != *":$install_dir:"* ]] && export PATH="$PATH:$install_dir"
  command -v gitleaks &>/dev/null || die "gitleaks not found after install"
  log "Installed gitleaks ${latest} to $install_dir/$bin_name"
}

# -------- Configure hooks path --------
configure_hooks_path(){
  local hooks_dir="$HOME/.git-hooks"
  mkdir -p "$hooks_dir"
  local win_path="$(windows_path "$hooks_dir")"
  local target="$hooks_dir"
  # Prefer Windows style if running in Git Bash or Windows native so PowerShell/CMD commits trigger hook.
  if $IS_MSYS || $IS_WINDOWS_NATIVE; then target="$win_path"; fi

  # Robust Git detection (Git Bash sometimes exposes only git.exe; some PATH issues can occur).
  local git_cmd=""
  if command -v git &>/dev/null; then
    git_cmd="git"
  elif command -v git.exe &>/dev/null; then
    git_cmd="git.exe"
  else
    # Attempt common fallback locations for Git for Windows
    for g in "/mingw64/bin/git" "/usr/bin/git" "/c/Program Files/Git/cmd/git.exe" "/c/Program Files (x86)/Git/cmd/git.exe"; do
      [[ -x "$g" ]] && { git_cmd="$g"; break; }
    done
  fi

  if [[ -z "$git_cmd" ]]; then
    warn "git not found on PATH; skipping hooksPath configuration"
    return 0
  fi

  if ! "$git_cmd" config --global core.hooksPath "$target" 2>/dev/null; then
    warn "$git_cmd config failed"
  fi
  local confirm="$("$git_cmd" config --global core.hooksPath 2>/dev/null || true)"
  if [[ -z "$confirm" ]]; then warn "hooksPath not readable after set"; else log "hooksPath set to: $confirm"; fi
}

# -------- Write configuration files --------
write_config_files(){
  local rules_url="https://raw.githubusercontent.com/AmedeoV/gitleaks-pre-commit-hook/main/gitleaks-custom-rules.toml"
  if download_file "$rules_url" "$HOME/.gitleaks-custom-rules.toml"; then
    log "Custom rules downloaded to ~/.gitleaks-custom-rules.toml"
  else
    warn "Failed to download custom rules; creating template"
    cat > "$HOME/.gitleaks-custom-rules.toml" <<'TEMPLATE'
# Custom Gitleaks Rules Template
# Add [[rules]] blocks below and re-run installer or append to ~/.gitleaks.toml manually.
TEMPLATE
  fi
  cat > "$HOME/.gitleaks.toml" <<'BASECFG'
# Global Gitleaks Configuration (extends defaults + custom rules)
[extend]
useDefault = true
# Custom rules appended below:
BASECFG
  cat "$HOME/.gitleaks-custom-rules.toml" >> "$HOME/.gitleaks.toml"
  log "Global config written to ~/.gitleaks.toml"
}

# -------- Write hooks --------
write_hooks(){
  local hooks_dir="$HOME/.git-hooks"
  mkdir -p "$hooks_dir"
  # Bash hook (primary for POSIX & also invoked by .bat on Windows)
  cat > "$hooks_dir/pre-commit" <<'BASHHOOK'
#!/bin/sh
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
if [ -n "$GIT_ROOT" ] && [ -f "$GIT_ROOT/.gitleaks.toml" ]; then
  CONFIG_FLAG="--config=$GIT_ROOT/.gitleaks.toml"
elif [ -f "$HOME/.gitleaks.toml" ]; then
  CONFIG_FLAG="--config=$HOME/.gitleaks.toml"
else
  CONFIG_FLAG=""
fi
if command -v gitleaks >/dev/null 2>&1; then
  gitleaks protect -v --staged $CONFIG_FLAG
elif command -v gitleaks.exe >/dev/null 2>&1; then
  gitleaks.exe protect -v --staged $CONFIG_FLAG
else
  echo "gitleaks not found; install it before committing" >&2
  exit 1
fi
BASHHOOK
  chmod +x "$hooks_dir/pre-commit"
  # Windows batch wrapper if on MSYS/Windows native (Git uses .bat when present)
  if $IS_MSYS || $IS_WINDOWS_NATIVE; then
    cat > "$hooks_dir/pre-commit.bat" <<'BATHOOK'
@echo off
REM Windows pre-commit wrapper invoking bash version
for /f "delims=" %%i in ('git rev-parse --show-toplevel') do set GIT_ROOT=%%i
bash "%~dp0pre-commit"
exit /b %ERRORLEVEL%
BATHOOK
  fi
  log "Hooks written to $hooks_dir"
}

# -------- Optional: Configure Windows Git from WSL --------
configure_windows_git_from_wsl(){
  $IS_WSL || return 0
  command -v git.exe &>/dev/null || return 0
  local win_hooks="$(windows_path "$HOME/.git-hooks")"
  git.exe config --global core.hooksPath "$win_hooks" || warn "Failed to set Windows hooksPath from WSL"
  log "Windows Git hooksPath (from WSL) => $(git.exe config --global core.hooksPath 2>/dev/null || echo 'unknown')"
}

# ------------------ Main Flow ------------------
log "Starting gitleaks global hook installation"
install_gitleaks
configure_hooks_path
write_config_files
write_hooks
configure_windows_git_from_wsl
log "Installation complete. Test with: echo 'slack_token=xoxb-123...123' > fake_secret.txt && git add fake_secret.txt && git commit -m 'test'"

exit 0
