# Managed by .github/workflows/eddie-ai-update.yml — version, the per-arch
# sha256, and the source-etag below are updated automatically; do not edit by hand.
# source-etag: d8a430e3962af931ee7cbd52a5805184
cask "eddie-ai" do
  version "3.3.4"

  on_arm do
    sha256 "d2f5ef019c6cf8db5acfc9bdd88a7dc138fb494a94d9523aa67d5f3e6cf4b97e"

    url "https://eddie-desktop-app.s3.us-east-2.amazonaws.com/distributions/darwin/arm64/Eddie+AI.dmg?v=#{version}",
        verified: "eddie-desktop-app.s3.us-east-2.amazonaws.com/"
  end
  on_intel do
    sha256 "5ad920716425466fdd641b54afdc589f76e85d0c516a5d69095a318d9bc9c806"

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
