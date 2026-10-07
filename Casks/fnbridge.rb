cask "fnbridge" do
  version "1.0"
  sha256 "6b7e686efa89145dd61c61a30f06057c748ef3582c279449e033bd30c0d731f2"

  url "https://github.com/BleakFall/FnBridge/releases/download/v#{version}/FnBridge-#{version}.zip"
  name "FnBridge"
  desc "Remap external keyboard F-keys to macOS media and function keys"
  homepage "https://github.com/BleakFall/FnBridge"

  depends_on macos: ">= :ventura"

  app "FnBridge.app"

  zap trash: "~/Library/Preferences/com.daixingwen.fnbridge.plist"

  caveats <<~EOS
    This app is not notarized. To avoid Gatekeeper warnings and
    Input Monitoring / Accessibility permission issues, install with:

      brew install --cask --no-quarantine fnbridge

    Then grant both permissions under System Settings > Privacy & Security.
  EOS
end
