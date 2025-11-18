#!/bin/bash

# Check if gitleaks is already installed, else use the gitleaks convenience scripts.
if command -v gitleaks &> /dev/null; then
    echo "Gitleaks is already installed."
else
  if [[ "$OSTYPE" == "msys" ]]; then
      curl -sSfL https://raw.githubusercontent.com/gitleaks/gitleaks/master/scripts/install.sh | sh -s -- -b ~/bin
  elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
      curl -sSfL https://raw.githubusercontent.com/gitleaks/gitleaks/master/scripts/install.sh | sh -s -- -b ~/.local/bin
      source ~/.profile
  elif [[ "$OSTYPE" == "darwin"* ]]; then
      brew install gitleaks
  else
      echo "Unsupported OS type: $OSTYPE"
      exit 1
  fi
  
  if ! command -v gitleaks &> /dev/null; then
      echo "Gitleaks installation failed, sorry! Please check your internet connection or the installation script."
      exit 1
  fi
fi

GITLEAKS_CMD=$(which gitleaks)
echo "Gitleaks installed at $GITLEAKS_CMD"

echo "Creating .git-hooks directory..."
mkdir -p ~/.git-hooks
echo ".git-hooks directory created."

echo "Configuring git to use custom hooks path..."
git config --global core.hooksPath ~/.git-hooks
echo "Git hooks path configured."

echo "Writing pre-commit hook file..."
cat << EOF > ~/.git-hooks/pre-commit
#!/bin/sh

$GITLEAKS_CMD protect --staged -v
EOF
echo "pre-commit file created."

echo "Setting pre-commit file as executable..."
chmod +x ~/.git-hooks/pre-commit
echo "pre-commit file is now executable."
echo "Script ran successfully."
