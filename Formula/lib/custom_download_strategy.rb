# frozen_string_literal: true

require "download_strategy"

# GitHubPrivateRepositoryDownloadStrategy downloads content from a private
# GitHub repository by injecting HOMEBREW_GITHUB_API_TOKEN into the URL.
class GitHubPrivateRepositoryDownloadStrategy < CurlDownloadStrategy
  require "utils/formatter"
  require "utils/github"

  def initialize(url, name, version, **meta)
    super
    parse_url_pattern
    set_github_token
  end

  def parse_url_pattern
    match = @url.match(%r{https://github\.com/([^/]+)/([^/]+)/(\S+)})
    raise CurlDownloadStrategyError, "Invalid GitHub URL: #{@url}" unless match

    @owner    = match[1]
    @repo     = match[2]
    @filepath = match[3]
  end

  def download_url
    "https://#{@github_token}@github.com/#{@owner}/#{@repo}/#{@filepath}"
  end

  private

  def _fetch(url:, resolved_url:, timeout:)
    curl_download download_url, to: temporary_path
  end

  def set_github_token
    @github_token = ENV.fetch("HOMEBREW_GITHUB_API_TOKEN", nil)
    unless @github_token
      raise CurlDownloadStrategyError,
            "HOMEBREW_GITHUB_API_TOKEN is required to install from a private repository.\n" \
            "Set it with: export HOMEBREW_GITHUB_API_TOKEN=<your_github_pat>"
    end

    validate_github_repository_access!
  end

  def validate_github_repository_access!
    GitHub.repository(@owner, @repo)
  rescue GitHub::HTTPNotFoundError
    raise CurlDownloadStrategyError, <<~EOS
      HOMEBREW_GITHUB_API_TOKEN cannot access #{@owner}/#{@repo}.
      Ensure the token has at least read:repo scope for this repository.
    EOS
  end
end

# GitHubPrivateRepositoryReleaseDownloadStrategy downloads release assets from
# a private GitHub repository via the GitHub API.
#
# It resolves the asset ID from the release metadata first, then fetches the
# binary using Accept: application/octet-stream to get the raw file.
#
# Required env: HOMEBREW_GITHUB_API_TOKEN (GitHub PAT with repo read access)
class GitHubPrivateRepositoryReleaseDownloadStrategy < GitHubPrivateRepositoryDownloadStrategy
  def parse_url_pattern
    url_pattern = %r{https://github\.com/([^/]+)/([^/]+)/releases/download/([^/]+)/(\S+)}
    match = @url.match(url_pattern)
    raise CurlDownloadStrategyError, "Invalid GitHub release URL: #{@url}" unless match

    @owner    = match[1]
    @repo     = match[2]
    @tag      = match[3]  # may be URL-encoded, e.g. "proj%2Fv1.0.0"
    @filename = match[4]
  end

  def download_url
    "https://api.github.com/repos/#{@owner}/#{@repo}/releases/assets/#{asset_id}"
  end

  private

  def _fetch(url:, resolved_url:, timeout:)
    curl_download download_url,
                  "--header", "Accept: application/octet-stream",
                  "--header", "Authorization: token #{@github_token}",
                  to: temporary_path
  end

  def asset_id
    @asset_id ||= resolve_asset_id
  end

  def resolve_asset_id
    release = fetch_release_metadata
    assets  = release["assets"].select { |a| a["name"] == @filename }
    raise CurlDownloadStrategyError, "Asset '#{@filename}' not found in release '#{@tag}'." if assets.empty?

    assets.first["id"]
  end

  def fetch_release_metadata
    # @tag may contain a URL-encoded slash (e.g. "git-patrol%2Fv0.2.0").
    # GitHub's API decodes %2F correctly when resolving the tag name.
    GitHub::API.open_rest(
      "https://api.github.com/repos/#{@owner}/#{@repo}/releases/tags/#{@tag}",
    )
  end
end
