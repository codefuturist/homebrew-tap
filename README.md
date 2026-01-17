# Homebrew Tap for Private Repositories

This tap provides Homebrew formulas that support authentication for private GitHub repositories.

## Installation

### Quick Install (Public Repositories)

```bash
brew tap codefuturist/tap
brew install packr
```

### Private Repository Installation

For private repositories, you need to set up authentication first.

## Authentication Methods

### Method 1: GitHub CLI (Recommended)

```bash
# Install GitHub CLI
brew install gh

# Authenticate
gh auth login

# Install formula (token is detected automatically)
brew install codefuturist/tap/packr-auth
```

### Method 2: Environment Variable

```bash
# Create a GitHub Personal Access Token with 'repo' scope
# https://github.com/settings/tokens

# Set the token
export HOMEBREW_GITHUB_API_TOKEN=ghp_your_token_here

# Install formula
brew install codefuturist/tap/packr-auth
```

### Method 3: Use GitHub CLI Token

```bash
# Export GitHub CLI token
export HOMEBREW_GITHUB_API_TOKEN=$(gh auth token)

# Install formula
brew install codefuturist/tap/packr-auth
```

### Method 4: Persistent Configuration

Add to your shell profile (`~/.zshrc` or `~/.bashrc`):

```bash
# Automatic GitHub token for Homebrew
if command -v gh &> /dev/null && gh auth status &> /dev/null 2>&1; then
    export HOMEBREW_GITHUB_API_TOKEN=$(gh auth token)
fi
```

## Available Formulas

### packr

Standard formula for public repositories.

```bash
brew install codefuturist/tap/packr
```

### packr-auth

Enhanced formula with automatic authentication detection for private repositories.

```bash
brew install codefuturist/tap/packr-auth
```

Features:

- Automatic token detection from multiple sources
- GitHub CLI integration
- Support for HOMEBREW_GITHUB_API_TOKEN, GITHUB_TOKEN, GH_TOKEN
- Clear error messages with setup instructions

### packr-private

Basic formula requiring HOMEBREW_GITHUB_API_TOKEN for private repositories.

```bash
export HOMEBREW_GITHUB_API_TOKEN=$(gh auth token)
brew install codefuturist/tap/packr-private
```

## Installation Script

For maximum compatibility, use the installation script:

```bash
# Download and run
curl -sL https://raw.githubusercontent.com/codefuturist/homebrew-tap/main/install-packr.sh | bash

# Or download first
wget https://raw.githubusercontent.com/codefuturist/homebrew-tap/main/install-packr.sh
chmod +x install-packr.sh
./install-packr.sh 3.0.0
```

## Token Scopes

Your GitHub token needs the following scopes:

- `repo` - Full control of private repositories
- `read:packages` - Read packages (optional)
- `workflow` - Update GitHub Actions workflows (optional)

Create a token at: https://github.com/settings/tokens

## Troubleshooting

### Error: 404 Not Found

The repository is private. Set up authentication:

```bash
export HOMEBREW_GITHUB_API_TOKEN=$(gh auth token)
brew install codefuturist/tap/packr-auth
```

### Error: Authentication required

Install GitHub CLI and authenticate:

```bash
brew install gh
gh auth login
brew install codefuturist/tap/packr-auth
```

### Verify Token

```bash
# Check if token is set
echo $HOMEBREW_GITHUB_API_TOKEN | head -c 10

# Test GitHub API access
curl -H "Authorization: Bearer $(gh auth token)" \
     https://api.github.com/user
```

### Clear Homebrew Cache

If you're having issues with cached downloads:

```bash
brew cleanup --prune=all
rm -rf $(brew --cache)
```

## Security Best Practices

1. **Never commit tokens** to version control
2. **Use environment variables** for tokens
3. **Rotate tokens regularly**
4. **Use minimal scopes** (only `repo` for private repositories)
5. **Use GitHub CLI** for automatic token management

## Advanced Usage

### Custom Download Strategy

The formulas use a custom `GitHubAuthenticatedDownloadStrategy` that:

1. Checks multiple token sources
2. Uses GitHub API to resolve asset URLs
3. Downloads with proper authentication headers
4. Provides helpful error messages

### Token Priority

Tokens are checked in this order:

1. `HOMEBREW_GITHUB_API_TOKEN`
2. `GITHUB_TOKEN`
3. `GH_TOKEN`
4. GitHub CLI token (`gh auth token`)
5. Homebrew's credential store

## Contributing

Pull requests are welcome! Please ensure:

- Formulas pass `brew audit --strict`
- Download strategies handle authentication properly
- Error messages are helpful
- Documentation is updated

## License

MIT

## Support

For issues with formulas, please open an issue at:
https://github.com/codefuturist/homebrew-tap/issues
