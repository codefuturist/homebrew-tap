require "download_strategy"

# Enhanced download strategy with multiple authentication methods
class GitHubAuthenticatedDownloadStrategy < CurlDownloadStrategy
  require "utils/github"
  
  def initialize(url, name, version, **meta)
    super
    parse_url_pattern
  end

  def parse_url_pattern
    url_pattern = %r{https://github\.com/([^/]+)/([^/]+)/releases/download/([^/]+)/(.+)}
    unless @url =~ url_pattern
      raise CurlDownloadStrategyError, "Invalid URL for GitHub release: #{@url}"
    end
    _, @owner, @repo, @tag, @filename = *@url.match(url_pattern)
  end

  def _fetch(url:, resolved_url:, timeout:)
    token = github_token
    
    if token
      fetch_with_token(token)
    else
      odie <<~EOS
        Authentication required for private repository.
        
        Please use one of these methods:
        
        1. GitHub CLI (recommended):
           brew install gh
           gh auth login
           export HOMEBREW_GITHUB_API_TOKEN=$(gh auth token)
           
        2. Personal Access Token:
           Create at: https://github.com/settings/tokens
           export HOMEBREW_GITHUB_API_TOKEN=your_token_here
           
        3. Homebrew GitHub API Token:
           brew tap-github-token codefuturist/tap
           
        Then retry: brew install codefuturist/tap/packr-auth
      EOS
    end
  end

  private

  def github_token
    # Try multiple token sources in order of preference
    token = ENV["HOMEBREW_GITHUB_API_TOKEN"] || 
            ENV["GITHUB_TOKEN"] ||
            ENV["GH_TOKEN"] ||
            github_cli_token ||
            homebrew_github_token
    
    if token.nil? || token.empty?
      nil
    else
      token
    end
  end

  def github_cli_token
    # Try to get token from GitHub CLI if available
    return nil unless which("gh")
    
    token = Utils.safe_popen_read("gh", "auth", "token").strip
    token.empty? ? nil : token
  rescue
    nil
  end

  def homebrew_github_token
    # Try to get token from Homebrew's credential store
    credentials = GitHub::API.credentials
    credentials.password if credentials
  rescue
    nil
  end

  def fetch_with_token(token)
    # Get release info from GitHub API
    api_url = "https://api.github.com/repos/#{@owner}/#{@repo}/releases/tags/#{@tag}"
    
    api_output = Utils.safe_popen_read(
      "curl",
      "--location", "--silent", "--fail",
      "--header", "Authorization: Bearer #{token}",
      "--header", "Accept: application/vnd.github.v3+json",
      api_url
    )
    
    begin
      release_data = JSON.parse(api_output)
    rescue JSON::ParserError
      raise CurlDownloadStrategyError, "Failed to parse GitHub API response. The repository might not exist or token lacks permissions."
    end
    
    # Find the asset
    asset = release_data["assets"]&.find { |a| a["name"] == @filename }
    unless asset
      raise CurlDownloadStrategyError, "Asset #{@filename} not found in release #{@tag}"
    end
    
    # Download the asset
    download_url = asset["url"]
    
    ohai "Downloading from private repository using GitHub token..."
    
    system_command!(
      "curl",
      args: [
        "--location",
        "--silent",
        "--fail",
        "--retry", "3",
        "--output", temporary_path.to_s,
        "--header", "Authorization: Bearer #{token}",
        "--header", "Accept: application/octet-stream",
        download_url
      ],
      print_stdout: false
    )
  end
end

class PackrAuth < Formula
  desc "Modern package manager automation tool (with authentication support)"
  homepage "https://github.com/codefuturist/monorepository"
  version "3.0.0"
  license "MIT"
  
  if Hardware::CPU.arm?
    url "https://github.com/codefuturist/monorepository/releases/download/packr-v3.0.0/packr-3.0.0-darwin-arm64.tar.gz",
        using: GitHubAuthenticatedDownloadStrategy
    sha256 "45516ad3d7e4329cd4f60aed1f8f3e21d29fa819d95d5f295768d64d76ef56a2"
  else
    odie "Packr is currently only available for Apple Silicon Macs"
  end
  
  depends_on :macos => :sonoma
  
  def install
    bin.install "packr"
    (etc/"packr").mkpath
    doc.install "README.md" if File.exist?("README.md")
  end
  
  def post_install
    (var/"log/packr").mkpath
  end
  
  def caveats
    <<~EOS
      #{Formatter.headline("Quick Start:")}
      
      Create configuration:
        mkdir -p ~/.config/packr
        cat > ~/.config/packr/packages.yaml <<EOF
        packages:
          - name: Example
            package_manager: brew
            package_name: example
            enabled: true
        EOF
      
      Run packr:
        packr --help
        packr --dry-run
        packr
      
      #{Formatter.headline("Authentication:")}
      This formula supports private repositories via:
      • GitHub CLI token (gh auth token)
      • HOMEBREW_GITHUB_API_TOKEN
      • GITHUB_TOKEN / GH_TOKEN
    EOS
  end
  
  test do
    assert_match "Packr", shell_output("#{bin}/packr --version")
  end
end
