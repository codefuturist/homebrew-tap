class Packr < Formula
  desc "Modern, multi-platform package manager automation tool for macOS"
  homepage "https://github.com/codefuturist/monorepository"
  version "3.0.0"
  license "MIT"
  
  # Download URL - for private repos, requires HOMEBREW_GITHUB_API_TOKEN
  if Hardware::CPU.arm?
    # Standard GitHub release URL
    url "https://github.com/codefuturist/monorepository/releases/download/packr-v3.0.0/packr-3.0.0-darwin-arm64.tar.gz"
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
      Packr has been installed successfully!
      
      To get started:
        1. Create your configuration file:
           mkdir -p ~/.config/packr
           cat > ~/.config/packr/packages.yaml << 'EOF'
           packages:
             - name: Example Package
               package_manager: brew
               package_name: example
               enabled: true
           settings:
             run_final_brew_upgrade: true
           EOF
        
        2. Run packr to update your packages:
           packr
        
        3. For more information:
           packr --help
    EOS
  end
  
  test do
    # Test that the binary runs and returns version
    assert_match "Packr", shell_output("#{bin}/packr --version")
  end
end
