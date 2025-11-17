# Example .zshrc configuration for gitBash
# Copy the lines below to your actual ~/.zshrc file

# ========================================
# gitBash - Git Repository Initializer
# ========================================
# Source the gitBash initialization script
# This adds the 'git-init-repo' and 'gir' commands

if [ -f "$HOME/gitBash/init.sh" ]; then
    source "$HOME/gitBash/init.sh"
fi

# Optional: Set OpenAI API key for AI-assisted catalogue metadata
# export OPENAI_API_KEY="your-api-key-here"
# export OPENAI_MODEL="gpt-4o-mini"  # Optional, defaults to gpt-4o-mini

# ========================================
# After adding these lines to your .zshrc:
# 1. Save the file
# 2. Run: source ~/.zshrc
# 3. Use the commands: git-init-repo or gir
# ========================================

