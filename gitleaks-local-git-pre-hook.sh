#!/bin/bash

# Check for PowerShell availability on Windows (needed for downloads)
POWERSHELL_CMD=""
if command -v powershell.exe &> /dev/null; then
  POWERSHELL_CMD="powershell.exe"
elif command -v pwsh.exe &> /dev/null; then
  POWERSHELL_CMD="pwsh.exe"
elif [[ -f "/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe" ]]; then
  POWERSHELL_CMD="/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"
elif [[ -f "/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe" ]]; then
  POWERSHELL_CMD="/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"
fi

# Global function to download files
download_file() {
  local url=$1
  local output=$2
  
  if command -v curl &> /dev/null; then
    curl -sSfL "$url" -o "$output"
  elif command -v wget &> /dev/null; then
    wget -q "$url" -O "$output"
  elif [[ -n "$POWERSHELL_CMD" ]]; then
    # Use PowerShell - convert Unix paths to Windows paths for PowerShell
    echo "Downloading using PowerShell..."
    
    # If output path starts with /tmp/, use Windows temp directory
    if [[ "$output" == /tmp/* ]]; then
      # Get Windows temp directory and convert to Unix path
      WIN_TEMP=$($POWERSHELL_CMD -Command "Write-Output \$env:TEMP" 2>/dev/null | tr -d '\r')
      if [[ -n "$WIN_TEMP" ]]; then
        # Convert to Unix path if we have cygpath
        if command -v cygpath &> /dev/null; then
          UNIX_TEMP=$(cygpath -u "$WIN_TEMP")
        else
          # Fallback: manual conversion for common cases
          UNIX_TEMP=$(echo "$WIN_TEMP" | sed 's|\\|/|g' | sed 's|^\([A-Za-z]\):|/\L\1|')
        fi
        
        # Replace /tmp with actual temp directory
        local basename=$(basename "$output")
        output="$UNIX_TEMP/$basename"
        mkdir -p "$(dirname "$output")" 2>/dev/null || true
      fi
    fi
    
    # Ensure parent directory exists
    mkdir -p "$(dirname "$output")" 2>/dev/null || true
    
    # Convert Unix path to Windows path for PowerShell
    local win_output="$output"
    if command -v cygpath &> /dev/null; then
      win_output=$(cygpath -w "$output")
    else
      # Fallback: manual conversion
      win_output=$(echo "$output" | sed 's|^/\([a-z]\)/|\U\1:/|' | sed 's|/|\\|g')
    fi
    
    $POWERSHELL_CMD -Command "\$ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -Uri '$url' -OutFile '$win_output'" 2>/dev/null
    return $?
  else
    echo "Error: No download tool available (curl, wget, or PowerShell)"
    return 1
  fi
}

# Check if gitleaks is already installed
if command -v gitleaks &> /dev/null; then
    echo "Gitleaks is already installed."
else
  echo "Installing Gitleaks..."
  if [[ "$OSTYPE" == "darwin"* ]]; then
      brew install gitleaks
  elif [[ "$OSTYPE" == "linux-gnu"* ]] || [[ "$OSTYPE" == "msys" ]]; then
      # Detect architecture
      ARCH=$(uname -m)
      case "$ARCH" in
        x86_64)
          ARCH="x64"
          ;;
        aarch64|arm64)
          ARCH="arm64"
          ;;
        *)
          echo "Unsupported architecture: $ARCH"
          exit 1
          ;;
      esac
      
      # Detect OS
      if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
        INSTALL_DIR="$HOME/.local/bin"
      else
        OS="windows"
        INSTALL_DIR="$HOME/bin"
      fi
      
      # Get latest release version - prioritize PowerShell on Windows
      if [[ "$OSTYPE" == "msys" ]] && [[ -n "$POWERSHELL_CMD" ]]; then
        # On Git Bash/Windows, use PowerShell first
        echo "Using PowerShell to fetch latest version..."
        LATEST_VERSION=$($POWERSHELL_CMD -Command "(Invoke-RestMethod -Uri 'https://api.github.com/repos/gitleaks/gitleaks/releases/latest').tag_name" 2>/dev/null | tr -d '\r')
      elif command -v curl &> /dev/null; then
        LATEST_VERSION=$(curl -s https://api.github.com/repos/gitleaks/gitleaks/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
      elif command -v wget &> /dev/null; then
        LATEST_VERSION=$(wget -qO- https://api.github.com/repos/gitleaks/gitleaks/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
      elif [[ -n "$POWERSHELL_CMD" ]]; then
        # Use PowerShell on Windows as fallback
        echo "Using PowerShell to fetch latest version..."
        LATEST_VERSION=$($POWERSHELL_CMD -Command "(Invoke-RestMethod -Uri 'https://api.github.com/repos/gitleaks/gitleaks/releases/latest').tag_name" 2>/dev/null | tr -d '\r')
      else
        echo "Error: No tool available to download files (curl, wget, or PowerShell)."
        echo "Please install curl or wget, or install gitleaks manually from: https://github.com/gitleaks/gitleaks/releases"
        exit 1
      fi
      
      if [ -z "$LATEST_VERSION" ]; then
        echo "Failed to get latest Gitleaks version"
        exit 1
      fi
      
      echo "Downloading Gitleaks $LATEST_VERSION..."
      
      # Download and install
      mkdir -p "$INSTALL_DIR"
      
      if [[ "$OS" == "windows" ]]; then
        download_file "https://github.com/gitleaks/gitleaks/releases/download/${LATEST_VERSION}/gitleaks_${LATEST_VERSION#v}_${OS}_${ARCH}.zip" /tmp/gitleaks.zip
        unzip -o -q /tmp/gitleaks.zip -d /tmp/ gitleaks.exe 2>/dev/null || {
          # Try with Windows temp if /tmp fails
          WIN_TEMP=$($POWERSHELL_CMD -Command "Write-Output \$env:TEMP" 2>/dev/null | tr -d '\r' | sed 's|\\|/|g' | sed 's|^\([A-Za-z]\):|/\L\1|')
          if [[ -n "$WIN_TEMP" ]]; then
            unzip -o -q "$WIN_TEMP/gitleaks.zip" -d "$WIN_TEMP/" gitleaks.exe
            mv "$WIN_TEMP/gitleaks.exe" "$INSTALL_DIR/"
            rm "$WIN_TEMP/gitleaks.zip" 2>/dev/null || true
          fi
        }
        # If unzip succeeded in /tmp, move from there
        if [[ -f /tmp/gitleaks.exe ]]; then
          mv /tmp/gitleaks.exe "$INSTALL_DIR/"
          rm /tmp/gitleaks.zip 2>/dev/null || true
        fi
      else
        download_file "https://github.com/gitleaks/gitleaks/releases/download/${LATEST_VERSION}/gitleaks_${LATEST_VERSION#v}_${OS}_${ARCH}.tar.gz" /tmp/gitleaks.tar.gz
        tar -xzf /tmp/gitleaks.tar.gz -C /tmp/
        mv /tmp/gitleaks "$INSTALL_DIR/"
        chmod +x "$INSTALL_DIR/gitleaks"
        rm /tmp/gitleaks.tar.gz
      fi
      
      # Add to PATH if not already there
      if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        echo "export PATH=\"\$PATH:$INSTALL_DIR\"" >> ~/.bashrc
        export PATH="$PATH:$INSTALL_DIR"
      fi
  else
      echo "Unsupported OS type: $OSTYPE"
      exit 1
  fi
  
  if ! command -v gitleaks &> /dev/null; then
      echo "Gitleaks installation failed, sorry! Please check your internet connection or try installing manually from https://github.com/gitleaks/gitleaks/releases"
      exit 1
  fi
  
  echo "Gitleaks installed successfully!"
fi

GITLEAKS_CMD=$(which gitleaks)
echo "Gitleaks installed at $GITLEAKS_CMD"

# Determine if we're running in a Windows environment (Git Bash, WSL, etc.)
IS_WINDOWS=false
if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]] || [[ -n "$WINDIR" ]]; then
  IS_WINDOWS=true
fi

# Setup for bash/WSL environment
echo "Creating .git-hooks directory..."
mkdir -p ~/.git-hooks
echo ".git-hooks directory created."

echo "Configuring git to use custom hooks path..."
# For Git Bash/Windows, use PowerShell to set git config for reliability
# git.exe from bash doesn't always work correctly with global config
if [[ "$OSTYPE" == "msys" ]] && [[ -n "$POWERSHELL_CMD" ]]; then
  # Git Bash - use PowerShell to set the config
  HOOKS_PATH="$HOME/.git-hooks"
  $POWERSHELL_CMD -Command "git config --global core.hooksPath '$HOOKS_PATH'"
  # Verify it was set
  sleep 0.5
  VERIFY=$($POWERSHELL_CMD -Command "git config --global core.hooksPath" 2>/dev/null | tr -d '\r')
  if [[ -z "$VERIFY" ]]; then
    echo "Warning: Failed to set hooks path via PowerShell, trying git.exe..."
    git.exe config --global core.hooksPath "$HOOKS_PATH" 2>/dev/null || git config --global core.hooksPath "$HOOKS_PATH"
  fi
elif command -v git.exe &> /dev/null; then
  git.exe config --global core.hooksPath ~/.git-hooks
elif command -v git &> /dev/null; then
  git config --global core.hooksPath ~/.git-hooks
fi
echo "Git hooks path configured."

echo "Downloading custom rules file from GitHub..."
CUSTOM_RULES_URL="https://raw.githubusercontent.com/AmedeoV/gitleaks-pre-commit-hook/main/gitleaks-custom-rules.toml"

# Try to download the custom rules file
if download_file "$CUSTOM_RULES_URL" ~/.gitleaks-custom-rules.toml; then
  echo "Custom rules file downloaded successfully to ~/.gitleaks-custom-rules.toml"
else
  echo "Warning: Failed to download custom rules file from GitHub"
  echo "Creating basic custom rules template as fallback..."
  cat << 'EOFCUSTOM' > ~/.gitleaks-custom-rules.toml
# Custom Gitleaks Rules
# This file contains additional detection rules beyond the default gitleaks rules
# After editing this file, re-run the installation script to regenerate ~/.gitleaks.toml

# Add your custom rules below this line
# Example template:
# [[rules]]
# id = "my-custom-rule"
# description = "Description of what this rule detects"
# regex = '''your-regex-pattern-here'''
# tags = ["tag1", "tag2"]
EOFCUSTOM
  echo "Basic custom rules template created at ~/.gitleaks-custom-rules.toml"
fi

echo "Creating global gitleaks configuration..."
cat << 'EOFCONFIG' > ~/.gitleaks.toml
# Global Gitleaks Configuration
# This file uses the default gitleaks rules plus custom rules defined below

[extend]
# Use the default gitleaks rules as a base
useDefault = true

# ============================================================================
# CUSTOM RULES SECTION
# ============================================================================
# The rules below are loaded from ~/.gitleaks-custom-rules.toml
# To add or modify custom rules, edit ~/.gitleaks-custom-rules.toml
# Then re-run the installation script or manually append the rules here
# ============================================================================

EOFCONFIG

# Append custom rules to the main config
cat ~/.gitleaks-custom-rules.toml >> ~/.gitleaks.toml

echo "Global gitleaks configuration created at ~/.gitleaks.toml (includes custom rules)"

echo "Writing pre-commit hook file..."
cat << 'EOF' > ~/.git-hooks/pre-commit
#!/bin/sh

# Get the root directory of the git repository
GIT_ROOT=$(git rev-parse --show-toplevel)

# Priority: Repository config > Global config
if [ -f "$GIT_ROOT/.gitleaks.toml" ]; then
    CONFIG_FLAG="--config=$GIT_ROOT/.gitleaks.toml"
elif [ -f "$HOME/.gitleaks.toml" ]; then
    CONFIG_FLAG="--config=$HOME/.gitleaks.toml"
else
    CONFIG_FLAG=""
fi

# Try to run gitleaks from PATH first (works in both WSL and Windows)
if command -v gitleaks > /dev/null 2>&1; then
    gitleaks protect -v --staged $CONFIG_FLAG
elif command -v gitleaks.exe > /dev/null 2>&1; then
    gitleaks.exe protect -v --staged $CONFIG_FLAG
else
    echo "Error: gitleaks not found in PATH"
    echo "Please ensure gitleaks is installed and accessible from your terminal"
    exit 1
fi
EOF
echo "pre-commit file created."

echo "Setting pre-commit file as executable..."
chmod +x ~/.git-hooks/pre-commit
echo "pre-commit file is now executable."

# Additional setup for Windows Git (if applicable)
if [[ "$IS_WINDOWS" == "true" ]] || [[ -n "$POWERSHELL_CMD" ]] || command -v cmd.exe &> /dev/null; then
  echo ""
  echo "Detected Windows environment. Setting up for Windows Git..."
  
  # Ensure POWERSHELL_CMD is set if not already
  if [[ -z "$POWERSHELL_CMD" ]]; then
    if command -v powershell.exe &> /dev/null; then
      POWERSHELL_CMD="powershell.exe"
    elif command -v pwsh.exe &> /dev/null; then
      POWERSHELL_CMD="pwsh.exe"
    elif [[ -f "/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe" ]]; then
      POWERSHELL_CMD="/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"
    elif [[ -f "/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe" ]]; then
      POWERSHELL_CMD="/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"
    fi
  fi
  
  # Check if gitleaks.exe is available in Windows
  if command -v gitleaks.exe &> /dev/null; then
    echo "Gitleaks is already installed in Windows."
  else
    echo "Installing Gitleaks for Windows..."
    
    # Get latest release version
    if [[ "$OSTYPE" == "msys" ]] && [[ -n "$POWERSHELL_CMD" ]]; then
      LATEST_VERSION=$($POWERSHELL_CMD -Command "(Invoke-RestMethod -Uri 'https://api.github.com/repos/gitleaks/gitleaks/releases/latest').tag_name" 2>/dev/null | tr -d '\r')
    elif command -v curl &> /dev/null; then
      LATEST_VERSION=$(curl -s https://api.github.com/repos/gitleaks/gitleaks/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
    elif command -v wget &> /dev/null; then
      LATEST_VERSION=$(wget -qO- https://api.github.com/repos/gitleaks/gitleaks/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
    elif [[ -n "$POWERSHELL_CMD" ]]; then
      LATEST_VERSION=$($POWERSHELL_CMD -Command "(Invoke-RestMethod -Uri 'https://api.github.com/repos/gitleaks/gitleaks/releases/latest').tag_name" 2>/dev/null | tr -d '\r')
    else
      LATEST_VERSION=""
    fi
    
    if [ -z "$LATEST_VERSION" ]; then
      echo "Warning: Failed to get latest Gitleaks version for Windows"
      echo "Please install gitleaks manually from: https://github.com/gitleaks/gitleaks/releases"
    else
      # Determine Windows user directory
      if command -v wslpath &> /dev/null; then
        # We're in WSL - install to Windows user's directory
        WIN_USER_PROFILE=$(cmd.exe /c "echo %USERPROFILE%" 2>/dev/null | tr -d '\r' | sed 's/\\/\//g' | sed 's/C:/\/mnt\/c/')
        WIN_INSTALL_DIR="$WIN_USER_PROFILE/bin"
      else
        # We're in Git Bash
        WIN_INSTALL_DIR="$USERPROFILE/bin"
      fi
      
      mkdir -p "$WIN_INSTALL_DIR"
      mkdir -p /tmp 2>/dev/null || true
      
      echo "Downloading Gitleaks $LATEST_VERSION for Windows..."
      if command -v curl &> /dev/null; then
        curl -sSfL "https://github.com/gitleaks/gitleaks/releases/download/${LATEST_VERSION}/gitleaks_${LATEST_VERSION#v}_windows_x64.zip" -o /tmp/gitleaks-win.zip
      elif command -v wget &> /dev/null; then
        wget -q "https://github.com/gitleaks/gitleaks/releases/download/${LATEST_VERSION}/gitleaks_${LATEST_VERSION#v}_windows_x64.zip" -O /tmp/gitleaks-win.zip
      elif [[ -n "$POWERSHELL_CMD" ]]; then
        $POWERSHELL_CMD -Command "\$ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -Uri 'https://github.com/gitleaks/gitleaks/releases/download/${LATEST_VERSION}/gitleaks_${LATEST_VERSION#v}_windows_x64.zip' -OutFile '/tmp/gitleaks-win.zip'" 2>/dev/null
      fi
      
      if [[ -f /tmp/gitleaks-win.zip ]]; then
        mkdir -p /tmp/gitleaks-win
        unzip -q /tmp/gitleaks-win.zip -d /tmp/gitleaks-win/
        mv /tmp/gitleaks-win/gitleaks.exe "$WIN_INSTALL_DIR/" 2>/dev/null || cp /tmp/gitleaks-win/gitleaks.exe "$WIN_INSTALL_DIR/"
        rm -rf /tmp/gitleaks-win.zip /tmp/gitleaks-win/
      else
        echo "Warning: Failed to download gitleaks for Windows"
      fi
      
      echo "Gitleaks installed to Windows at: $WIN_INSTALL_DIR/gitleaks.exe"
      echo "Note: You may need to add %USERPROFILE%\\bin to your Windows PATH"
    fi
  fi
  
  # Configure git hooks path based on environment
  if command -v wslpath &> /dev/null; then
    # We're in WSL - need to configure Windows Git separately
    WINDOWS_HOOKS_PATH=$(wslpath -w ~/.git-hooks)
    
    if command -v git.exe &> /dev/null; then
      git.exe config --global core.hooksPath "$WINDOWS_HOOKS_PATH"
      echo "Windows Git hooks path configured at: $WINDOWS_HOOKS_PATH"
    elif command -v powershell.exe &> /dev/null; then
      powershell.exe -Command "git config --global core.hooksPath '$WINDOWS_HOOKS_PATH'"
      echo "Windows Git hooks path configured at: $WINDOWS_HOOKS_PATH"
    fi
  else
    # We're in Git Bash or MSYS - use PowerShell for reliability
    HOOKS_PATH="$HOME/.git-hooks"
    if [[ -n "$POWERSHELL_CMD" ]]; then
      $POWERSHELL_CMD -Command "git config --global core.hooksPath '$HOOKS_PATH'"
      sleep 0.5
      VERIFY_PATH=$($POWERSHELL_CMD -Command "git config --global core.hooksPath" 2>/dev/null | tr -d '\r')
      if [[ -z "$VERIFY_PATH" ]]; then
        echo "Warning: PowerShell method failed, trying git.exe..."
        git.exe config --global core.hooksPath "$HOOKS_PATH" 2>/dev/null || git config --global core.hooksPath "$HOOKS_PATH"
        VERIFY_PATH=$(git.exe config --global core.hooksPath 2>/dev/null || git config --global core.hooksPath || echo "$HOOKS_PATH")
      fi
    elif command -v git.exe &> /dev/null; then
      git.exe config --global core.hooksPath "$HOOKS_PATH"
      VERIFY_PATH=$(git.exe config --global core.hooksPath 2>/dev/null || echo "")
    elif command -v git &> /dev/null; then
      git config --global core.hooksPath "$HOOKS_PATH"
      VERIFY_PATH=$(git config --global core.hooksPath || echo "")
    fi
    echo "Git Bash/MSYS environment - hooks path verified and set to: ${VERIFY_PATH:-$HOOKS_PATH}"
  fi
  
  # Ensure Windows can execute the hook by also creating a .bat wrapper if needed
  cat << 'EOFBAT' > ~/.git-hooks/pre-commit.bat
@echo off
bash "%~dp0pre-commit"
EOFBAT
  echo "Created Windows batch wrapper for compatibility."
fi

echo ""
echo "Script ran successfully!"
echo ""
echo "Note: If you use Git from both WSL and Windows, the hook should now work in both environments."
