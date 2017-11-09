# eduVPN for macOS

### Notes

The helper will only run binaries that are signed by me.

    $ codesign -f -s "Mac Developer: Johan Kool (2W662WXNRW)" /Users/jkool/Developer/Egeniq/eduvpn-macos/openvpn-2.4.4-openssl-1.0.2k/openvpn

To verify code signing and priviliged helper settings use the SMJobBlessUtil.py tool.

    $ Tools/SMJobBlessUtil.py check eduVPN.app

Another tool that can be used to verify settings is [RB App Checker Lite](https://itunes.apple.com/nl/app/rb-app-checker-lite/id519421117?l=en&mt=12). (It currently crashes when you launch the app directly on macOS 10.13. Workaround: drag the eduVPN.app onto the RB App Checker Lite.app icon.)

The bundle identifier (`CFBundleIdentifier`) in the helper's Info.plist should be spelled out. Correct: `org.eduvpn.app.openvpnhelper`, wrong: `$(PRODUCT_BUNDLE_IDENTIFIER)`.

### Uninstalling

Besides deleting the app, files are installed at these locations:

    /Library/LaunchDaemons/org.eduvpn.app.openvpnhelper.plist
    /Library/PrivilegedHelperTools/org.eduvpn.app.openvpnhelper
    ~/Library/Application Support/eduVPN/
    ~/Library/Caches/org.eduvpn.app/
    ~/Library/Preferences/org.eduvpn.app.plist
    
and in a temporary folder as provided by macOS, usually somewhere under `/private/var/folders`.
