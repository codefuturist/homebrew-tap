# Managed by .github/workflows/eddie-ai-update.yml — version, the per-arch
# sha256, and the source-etag below are updated automatically; do not edit by hand.
# source-etag: f9307f440d54c81be5006dd221291b00
cask "eddie-ai" do
  version "3.3.0"

  on_arm do
    sha256 "18bb4509a4ac864a2d756f1ab31fb2ce18d9630552c2574f5810c910bc87a4ea"

    url "https://eddie-desktop-app.s3.us-east-2.amazonaws.com/distributions/darwin/arm64/Eddie+AI.dmg?v=#{version}",
        verified: "eddie-desktop-app.s3.us-east-2.amazonaws.com/"
  end
  on_intel do
    sha256 "ccb29c7edb2673ea42b30a2df51448a365b6a34a78806fd4e701382e28acb58c"

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
