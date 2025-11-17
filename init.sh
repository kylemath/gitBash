#!/bin/bash
# This file should be sourced in your .zshrc or .bashrc

# Add gitBash scripts to PATH
export PATH="$HOME/gitBash:$PATH"

# Function to run git-init-repo script
git-init-repo() {
    bash "$HOME/gitBash/git-init-repo.sh" "$@"
}

# Short alias function
gir() {
    bash "$HOME/gitBash/git-init-repo.sh" "$@"
}

