# Managed by .github/workflows/eddie-ai-update.yml — version, the per-arch
# sha256, and the source-etag below are updated automatically; do not edit by hand.
# source-etag: e212f41ed50138b262167c086f9c6351
cask "eddie-ai" do
  version "3.2.16"

  on_arm do
    sha256 "f3581c59332676c4e39e6ef806c089851973d503d7067ccb38b737d0894f2412"

    url "https://eddie-desktop-app.s3.us-east-2.amazonaws.com/distributions/darwin/arm64/Eddie+AI.dmg?v=#{version}",
        verified: "eddie-desktop-app.s3.us-east-2.amazonaws.com/"
  end
  on_intel do
    sha256 "1066ba4308db9c2a9736212f467a87e8f963a78f8bedb41aedfb038d950d0f2f"

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
