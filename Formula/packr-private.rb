require "download_strategy"

# Custom download strategy for GitHub private releases
class GitHubPrivateReleaseDownloadStrategy < CurlDownloadStrategy
  require "utils/formatter"
  require "utils/github"

  def initialize(url, name, version, **meta)
    super
    parse_url_pattern
    set_github_token
  end

  def parse_url_pattern
    url_pattern = %r{https://github\.com/([^/]+)/([^/]+)/releases/download/([^/]+)/(.+)}
    unless @url =~ url_pattern
      raise CurlDownloadStrategyError, "Invalid URL for GitHub private release: #{@url}"
    end

    _, @owner, @repo, @tag, @filename = *@url.match(url_pattern)
  end

  def set_github_token
    @github_token = ENV["HOMEBREW_GITHUB_API_TOKEN"]
    unless @github_token
      raise CurlDownloadStrategyError, <<~EOS
        HOMEBREW_GITHUB_API_TOKEN is required for private repository access.
        
        Create a token at https://github.com/settings/tokens with 'repo' scope.
        Then set it with: export HOMEBREW_GITHUB_API_TOKEN=your_token_here
        
        Or use GitHub CLI: export HOMEBREW_GITHUB_API_TOKEN=$(gh auth token)
      EOS
    end
  end

  def _fetch(url:, resolved_url:, timeout:)
    # Get the asset ID from GitHub API
    api_url = "https://api.github.com/repos/#{@owner}/#{@repo}/releases/tags/#{@tag}"
    
    curl_args = [
      "--location",
      "--silent",
      "--header", "Authorization: Bearer #{@github_token}",
      "--header", "Accept: application/vnd.github.v3+json",
      api_url
    ]
    
    output = Utils.safe_popen_read("curl", *curl_args)
    release_data = JSON.parse(output)
    
    # Find the asset
    asset = release_data["assets"].find { |a| a["name"] == @filename }
    unless asset
      raise CurlDownloadStrategyError, "Asset #{@filename} not found in release #{@tag}"
    end
    
    # Download the asset using the API
    download_url = asset["url"]
    
    # Use curl directly with authorization headers
    curl_args = [
      "--location",
      "--silent",
      "--fail",
      "--retry", "3",
      "--output", temporary_path.to_s,
      "--header", "Authorization: Bearer #{@github_token}",
      "--header", "Accept: application/octet-stream",
      download_url
    ]
    
    system_command!("curl", args: curl_args, print_stdout: false)
  end
end

class PackrPrivate < Formula
  desc "Modern, multi-platform package manager automation tool for macOS (Private)"
  homepage "https://github.com/codefuturist/monorepository"
  version "3.0.0"
  license "MIT"
  
  # Use custom download strategy for private repository
  if Hardware::CPU.arm?
    url "https://github.com/codefuturist/monorepository/releases/download/packr-v3.0.0/packr-3.0.0-darwin-arm64.tar.gz",
        using: GitHubPrivateReleaseDownloadStrategy
    sha256 "45516ad3d7e4329cd4f60aed1f8f3e21d29fa819d95d5f295768d64d76ef56a2"
  else
    odie "Packr is currently only available for Apple Silicon Macs"
  end
  
  # Minimum macOS version
  depends_on :macos => :sonoma
  
  def install
    # Install the binary
    bin.install "packr"
    
    # Create config directory structure
    (etc/"packr").mkpath
    
    # Install sample configuration if README exists
    if File.exist?("README.md")
      doc.install "README.md"
    end
  end
  
  def post_install
    # Create log directory
    (var/"log/packr").mkpath
    
    # Create config directory in user home if it doesn't exist
    config_dir = File.expand_path("~/.config/packr")
    unless File.exist?(config_dir)
      mkdir_p config_dir
    end
  end
  
  def caveats
    <<~EOS
      Packr has been installed from a private repository!
      
      To get started:
        1. Create your configuration file:
           mkdir -p ~/.config/packr
           vim ~/.config/packr/packages.yaml
        
        2. Run packr to update your packages:
           packr
        
        3. For more information:
           packr --help
      
      Note: This formula requires HOMEBREW_GITHUB_API_TOKEN to be set.
    EOS
  end
  
  test do
    # Test that the binary runs and returns version
    assert_match "Packr", shell_output("#{bin}/packr --version")
  end
end
