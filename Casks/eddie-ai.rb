# Managed by .github/workflows/eddie-ai-update.yml — version, the per-arch
# sha256, and the source-etag below are updated automatically; do not edit by hand.
# source-etag: b2345ad3c814e5f119fedc5ecbb8fafe
cask "eddie-ai" do
  version "3.3.10"

  on_arm do
    sha256 "a619a2b79a4f8fba78c457bc95d507ce437725dc54b9c8e29dc6df281b17cc9a"

    url "https://eddie-desktop-app.s3.us-east-2.amazonaws.com/distributions/darwin/arm64/Eddie+AI.dmg?v=#{version}",
        verified: "eddie-desktop-app.s3.us-east-2.amazonaws.com/"
  end
  on_intel do
    sha256 "ee4d917e1975222efdf4824f58ecc0fe18417a862e4cce5c1c299f6ac4289cae"

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
