#!/usr/bin/env ruby
# frozen_string_literal: true

require 'net/http'
require 'json'
require 'digest'
require 'optparse'
require 'tempfile'

class FormulaUpdater
  GITHUB_API = 'https://api.github.com'
  
  def initialize(options)
    @owner = options[:owner]
    @repo = options[:repo]
    @formula = options[:formula]
    @tap_repo = options[:tap_repo] || 'homebrew-tap'
    @token = options[:token] || ENV['GITHUB_TOKEN'] || ENV['HOMEBREW_GITHUB_API_TOKEN']
    @dry_run = options[:dry_run]
    @verbose = options[:verbose]
  end

  def run
    latest_release = fetch_latest_release
    return unless latest_release

    version = latest_release['tag_name'].gsub(/^v/, '').gsub(/^#{@formula}-v/, '')
    assets = latest_release['assets']
    
    if assets.empty?
      puts "No assets found in release #{latest_release['tag_name']}"
      return
    end

    # Find the macOS ARM64 asset
    asset = find_asset(assets, 'darwin', 'arm64') || 
            find_asset(assets, 'Darwin', 'arm64') ||
            find_asset(assets, 'darwin', 'aarch64') ||
            find_asset(assets, 'Darwin', 'aarch64')
    
    unless asset
      puts "No macOS ARM64 asset found in release"
      return
    end

    download_url = asset['browser_download_url']
    sha256 = calculate_sha256(download_url)
    
    update_formula(version, download_url, sha256)
  end

  private

  def fetch_latest_release
    uri = URI("#{GITHUB_API}/repos/#{@owner}/#{@repo}/releases/latest")
    request = build_request(uri)
    
    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    if response.code == '200'
      JSON.parse(response.body)
    else
      puts "Failed to fetch latest release: #{response.code} #{response.message}"
      nil
    end
  end

  def find_asset(assets, os_pattern, arch_pattern)
    assets.find do |asset|
      name = asset['name']
      name.include?(os_pattern) && name.include?(arch_pattern) && 
      (name.end_with?('.tar.gz') || name.end_with?('.zip'))
    end
  end

  def calculate_sha256(url)
    puts "Calculating SHA256 for #{url}" if @verbose
    
    uri = URI(url)
    request = build_request(uri)
    
    tempfile = Tempfile.new(['formula', '.tar.gz'])
    begin
      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(request) do |res|
          File.open(tempfile.path, 'wb') do |file|
            res.read_body { |chunk| file.write(chunk) }
          end
        end
      end
      
      Digest::SHA256.file(tempfile.path).hexdigest
    ensure
      tempfile.close
      tempfile.unlink
    end
  end

  def update_formula(version, url, sha256)
    formula_path = "Formula/#{@formula}.rb"
    
    unless File.exist?(formula_path)
      puts "Formula file not found: #{formula_path}"
      return
    end

    content = File.read(formula_path)
    
    # Update version
    content.gsub!(/version\s+"[^"]+"/m, "version \"#{version}\"")
    
    # Update URL
    content.gsub!(/url\s+"[^"]+"/m, "url \"#{url}\"")
    
    # Update SHA256
    content.gsub!(/sha256\s+"[^"]+"/m, "sha256 \"#{sha256}\"")
    
    if @dry_run
      puts "=== DRY RUN ==="
      puts "Would update #{formula_path}:"
      puts "  Version: #{version}"
      puts "  URL: #{url}"
      puts "  SHA256: #{sha256}"
    else
      File.write(formula_path, content)
      puts "Updated #{formula_path}"
      puts "  Version: #{version}"
      puts "  URL: #{url}"
      puts "  SHA256: #{sha256}"
      
      commit_and_push(version)
    end
  end

  def commit_and_push(version)
    system("git add Formula/#{@formula}.rb")
    system("git commit -m 'Update #{@formula} to #{version}'")
    system("git push")
  end

  def build_request(uri)
    request = Net::HTTP::Get.new(uri)
    request['Accept'] = 'application/vnd.github.v3+json'
    request['Authorization'] = "token #{@token}" if @token
    request['User-Agent'] = 'Homebrew-Formula-Updater'
    request
  end
end

# Main execution
if __FILE__ == $0
  options = {
    owner: 'codefuturist',
    repo: 'monorepository',
    formula: 'packr',
    dry_run: false,
    verbose: false
  }

  OptionParser.new do |opts|
    opts.banner = "Usage: update-formula.rb [options]"

    opts.on('-o', '--owner OWNER', 'GitHub repository owner') do |v|
      options[:owner] = v
    end

    opts.on('-r', '--repo REPO', 'GitHub repository name') do |v|
      options[:repo] = v
    end

    opts.on('-f', '--formula FORMULA', 'Formula name') do |v|
      options[:formula] = v
    end

    opts.on('-t', '--tap-repo TAP', 'Tap repository name') do |v|
      options[:tap_repo] = v
    end

    opts.on('--token TOKEN', 'GitHub token') do |v|
      options[:token] = v
    end

    opts.on('-d', '--dry-run', 'Dry run mode') do
      options[:dry_run] = true
    end

    opts.on('-v', '--verbose', 'Verbose output') do
      options[:verbose] = true
    end

    opts.on('-h', '--help', 'Show this help') do
      puts opts
      exit
    end
  end.parse!

  updater = FormulaUpdater.new(options)
  updater.run
end
