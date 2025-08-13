# typed: false
# frozen_string_literal: true

# This formula supports both public and private GitHub repositories
# For private repos, set HOMEBREW_GITHUB_API_TOKEN environment variable
require_relative "../lib/custom_download_strategy"

class Packr < Formula
  desc "Modern, multi-platform package manager automation tool for macOS"
  homepage "https://github.com/codefuturist/monorepository"
  version "3.0.1"
  license "MIT"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/codefuturist/monorepository/releases/download/packr-v3.0.1/packr-3.0.1-darwin-arm64.tar.gz",
          using: GitHubPrivateRepositoryReleaseDownloadStrategy
      sha256 "1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
    end

    if Hardware::CPU.intel?
      odie "Intel support not yet available. Packr is currently only available for Apple Silicon Macs."
    end
  end

  on_linux do
    # Linux support placeholder - remove odie from here
  end

  def install
    bin.install "packr"
    doc.install "README.md" if File.exist?("README.md")
    (etc/"packr").mkpath
    (var/"log/packr").mkpath
    (etc/"packr").install "Config/packages.yaml" => "packages.yaml.sample" if File.exist?("Config/packages.yaml")
  end

  def post_install
    config_dir = File.expand_path("~/.config/packr")
    unless File.exist?(config_dir)
      mkdir_p config_dir
      ohai "Created config directory at #{config_dir}"
    end

    user_config = "#{config_dir}/packages.yaml"
    sample_config = etc/"packr/packages.yaml.sample"

    if !File.exist?(user_config) && File.exist?(sample_config)
      cp sample_config, user_config
      ohai "Copied sample configuration to #{user_config}"
    end
  end

  def caveats
    token_set = ENV["HOMEBREW_GITHUB_API_TOKEN"] || ENV["GITHUB_TOKEN"]

    if token_set
      <<~EOS
        Packr installed successfully!

        Configuration file: ~/.config/packr/packages.yaml

        Quick start:
          packr --help              # Show help
          packr --dry-run          # Preview changes
          packr                    # Run updates

        Edit configuration:
          vim ~/.config/packr/packages.yaml
      EOS
    else
      <<~EOS
        Packr installed!

        Note: This formula works with private repositories when authenticated.

        For private repository support:
          export HOMEBREW_GITHUB_API_TOKEN=$(gh auth token)

        Or add to ~/.zshrc:
          if command -v gh &> /dev/null && gh auth status &> /dev/null 2>&1; then
              export HOMEBREW_GITHUB_API_TOKEN=$(gh auth token)
          fi

        Configuration: ~/.config/packr/packages.yaml

        Commands:
          packr --help
          packr --dry-run
          packr
      EOS
    end
  end

  test do
    system "#{bin}/packr", "--version"

    require "tmpdir"
    Dir.mktmpdir do |dir|
      ENV["HOME"] = dir
      system "#{bin}/packr", "--help"
    end
  end

  service do
    run [opt_bin/"packr", "--quiet"]
    run_type :cron
    cron "@daily"
    log_path var/"log/packr/service.log"
    error_log_path var/"log/packr/service-error.log"
  end
end
