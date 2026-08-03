# typed: false
# frozen_string_literal: true

# Official prebuilt Bitwarden CLI binaries (signed + notarized by Bitwarden).
# Version is intentionally scanned from the URLs (an explicit `version` would
# fail `brew audit`: "version is redundant with version scanned from URL").
# Updated automatically by scripts/update-bitwarden-cli.sh via
# .github/workflows/update-bitwarden-cli.yml.
class BitwardenCli < Formula
  desc "Secure and free password manager for all of your devices"
  homepage "https://bitwarden.com/"
  license "GPL-3.0-only"

  # The bitwarden/clients repo interleaves desktop/browser/web/cli releases,
  # so "latest release" is usually not a CLI release — list releases and
  # filter by tag instead of using the github_latest strategy.
  livecheck do
    url :stable
    regex(/^cli[._-]v?(\d+(?:\.\d+)+)$/i)
    strategy :github_releases
  end

  on_macos do
    on_arm do
      url "https://github.com/bitwarden/clients/releases/download/cli-v2026.7.0/bw-macos-arm64-2026.7.0.zip"
      sha256 "61d5de8a279a9faf3637216f4fb02b506a1e4bb2817d1c64be0bd474466dd85a"
    end
    on_intel do
      url "https://github.com/bitwarden/clients/releases/download/cli-v2026.7.0/bw-macos-2026.7.0.zip"
      sha256 "b37836d539798f5adeb8a907619ee8a55b6322549bb68669aa4b3a03d5bc0452"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/bitwarden/clients/releases/download/cli-v2026.7.0/bw-linux-arm64-2026.7.0.zip"
      sha256 "e33ed05ca0fada9bd51b8bce76a230369bf0eefd5796a0a8e60699c977327fb5"
    end
    on_intel do
      url "https://github.com/bitwarden/clients/releases/download/cli-v2026.7.0/bw-linux-2026.7.0.zip"
      sha256 "7a35145e205952f7434d2370da359543145ae0c45ba1af0fe9bdd99d40a00180"
    end
  end

  def install
    bin.install "bw"
    generate_completions_from_executable(bin/"bw", "completion", "--shell", shells: [:zsh])
  end

  def caveats
    <<~EOS
      This formula installs Bitwarden's official prebuilt `bw` binary.
      It has the same formula name and command as homebrew/core's
      bitwarden-cli (which builds from source with Node), so only one of
      the two can be installed at a time. Install and upgrade this one
      with the fully-qualified name:
        brew install codefuturist/tap/bitwarden-cli
    EOS
  end

  test do
    assert_equal 10, shell_output("#{bin}/bw generate --length 10").length

    output = pipe_output("#{bin}/bw encode", "Testing", 0)
    assert_equal "VGVzdGluZw==", output
  end
end
