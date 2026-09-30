# Managed by .github/workflows/eddie-ai-update.yml — version, the per-arch
# sha256, and the source-etag below are updated automatically; do not edit by hand.
# source-etag: d0521c7a0bcdd6f99c94e63a971f85cf
cask "eddie-ai" do
  version "3.3.15"

  on_arm do
    sha256 "1a275ac096206a10d276f9fcaff36fb05a3593fdac6fff357d1c71f38cee527f"

    url "https://eddie-desktop-app.s3.us-east-2.amazonaws.com/distributions/darwin/arm64/Eddie+AI.dmg?v=#{version}",
        verified: "eddie-desktop-app.s3.us-east-2.amazonaws.com/"
  end
  on_intel do
    sha256 "316c6d63a1e522f574e023b89e5fefe8e997952f29eb9102d3884fe0c82a5547"

    url "https://eddie-desktop-app.s3.us-east-2.amazonaws.com/distributions/darwin/x64/Eddie+AI.dmg?v=#{version}",
        verified: "eddie-desktop-app.s3.us-east-2.amazonaws.com/"
  end

  name "Eddie AI"
  desc "AI assistant video editor"
  homepage "https://www.heyeddie.ai/"

  livecheck do
    skip "Updated by the eddie-ai-update scheduled workflow."
  end

  depends_on :macos

  app "Eddie AI.app"
end
