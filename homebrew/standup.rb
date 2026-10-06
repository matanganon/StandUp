# Homebrew Cask for StandUp.
#
# This file is the canonical template. Copy it to your tap repository at:
#   homebrew-standup/Casks/standup.rb
#
# The release tooling (scripts/release.sh + scripts/update_cask.sh) keeps the
# `version` and `sha256` fields in sync automatically after each release.
cask "standup" do
  version "1.0.1"
  sha256 "c913029e7df13bdfbd1861732738079b74161b364dfd9ed7e7df8b4a66ee6f06"

  url "https://github.com/matanganon/StandUp/releases/download/v#{version}/StandUp-#{version}.zip"
  name "StandUp"
  desc "Menu bar break reminder that quiets down during calls"
  homepage "https://github.com/matanganon/StandUp"

  # No live version check endpoint; releases are tagged on GitHub.
  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :sequoia

  app "StandUp.app"

  # This development build is not notarized. Remove the quarantine attribute so
  # Gatekeeper allows it to launch. (Not needed once releases are notarized.)
  postflight_steps do
    run "/usr/bin/xattr",
        args: ["-dr", "com.apple.quarantine", "{{appdir}}/StandUp.app"],
        must_succeed: false
  end

  uninstall quit: "com.standup.app"

  zap trash: [
    "~/Library/Preferences/com.standup.app.plist",
  ]
end
