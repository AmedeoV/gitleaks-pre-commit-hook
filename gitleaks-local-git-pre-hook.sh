#!/bin/bash

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
      
      # Get latest release version
      LATEST_VERSION=$(curl -s https://api.github.com/repos/gitleaks/gitleaks/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
      
      if [ -z "$LATEST_VERSION" ]; then
        echo "Failed to get latest Gitleaks version"
        exit 1
      fi
      
      echo "Downloading Gitleaks $LATEST_VERSION..."
      
      # Download and install
      mkdir -p "$INSTALL_DIR"
      if [[ "$OS" == "windows" ]]; then
        curl -sSfL "https://github.com/gitleaks/gitleaks/releases/download/${LATEST_VERSION}/gitleaks_${LATEST_VERSION#v}_${OS}_${ARCH}.zip" -o /tmp/gitleaks.zip
        unzip -q /tmp/gitleaks.zip -d /tmp/
        mv /tmp/gitleaks.exe "$INSTALL_DIR/"
        rm /tmp/gitleaks.zip
      else
        curl -sSfL "https://github.com/gitleaks/gitleaks/releases/download/${LATEST_VERSION}/gitleaks_${LATEST_VERSION#v}_${OS}_${ARCH}.tar.gz" -o /tmp/gitleaks.tar.gz
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
git config --global core.hooksPath ~/.git-hooks
echo "Git hooks path configured."

echo "Writing pre-commit hook file..."
cat << 'EOF' > ~/.git-hooks/pre-commit
#!/bin/sh

# Try to run gitleaks from PATH first (works in both WSL and Windows)
if command -v gitleaks > /dev/null 2>&1; then
    gitleaks protect -v --staged
elif command -v gitleaks.exe > /dev/null 2>&1; then
    gitleaks.exe protect -v --staged
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
if [[ "$IS_WINDOWS" == "true" ]] || command -v powershell.exe &> /dev/null || command -v cmd.exe &> /dev/null; then
  echo ""
  echo "Detected Windows environment. Setting up for Windows Git..."
  
  # Check if gitleaks.exe is available in Windows
  if command -v gitleaks.exe &> /dev/null; then
    echo "Gitleaks is already installed in Windows."
  else
    echo "Installing Gitleaks for Windows..."
    
    # Get latest release version
    LATEST_VERSION=$(curl -s https://api.github.com/repos/gitleaks/gitleaks/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
    
    if [ -z "$LATEST_VERSION" ]; then
      echo "Warning: Failed to get latest Gitleaks version for Windows"
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
      
      echo "Downloading Gitleaks $LATEST_VERSION for Windows..."
      curl -sSfL "https://github.com/gitleaks/gitleaks/releases/download/${LATEST_VERSION}/gitleaks_${LATEST_VERSION#v}_windows_x64.zip" -o /tmp/gitleaks-win.zip
      unzip -q /tmp/gitleaks-win.zip -d /tmp/gitleaks-win/
      mv /tmp/gitleaks-win/gitleaks.exe "$WIN_INSTALL_DIR/" 2>/dev/null || cp /tmp/gitleaks-win/gitleaks.exe "$WIN_INSTALL_DIR/"
      rm -rf /tmp/gitleaks-win.zip /tmp/gitleaks-win/
      
      echo "Gitleaks installed to Windows at: $WIN_INSTALL_DIR/gitleaks.exe"
      echo "Note: You may need to add %USERPROFILE%\\bin to your Windows PATH"
    fi
  fi
  
  # Convert Unix path to Windows path for the hooks directory
  if command -v wslpath &> /dev/null; then
    # We're in WSL
    WINDOWS_HOOKS_PATH=$(wslpath -w ~/.git-hooks)
  else
    # We're in Git Bash or similar
    WINDOWS_HOOKS_PATH=$(cygpath -w ~/.git-hooks 2>/dev/null || echo "$HOME/.git-hooks" | sed 's|^/c/|C:/|' | sed 's|/|\\|g')
  fi
  
  # Try to configure Windows Git
  if command -v git.exe &> /dev/null; then
    git.exe config --global core.hooksPath "$WINDOWS_HOOKS_PATH"
    echo "Windows Git hooks path configured at: $WINDOWS_HOOKS_PATH"
  elif command -v powershell.exe &> /dev/null; then
    powershell.exe -Command "git config --global core.hooksPath '$WINDOWS_HOOKS_PATH'"
    echo "Windows Git hooks path configured at: $WINDOWS_HOOKS_PATH"
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
