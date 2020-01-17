# eduVPN for macOS

# This code is deprecated, please go to https://github.com/eduvpn/apple"

### Requirements

You need macOS 10.12 or newer to run eduVPN. 

Supporting earlier versions of macOS is currently not possible due to:

- usage of date formatting API introduced in 10.12 (relatively easy to fix)
- usage of RSA signing API introduced in 10.12 (alternative needed)

### OpenVPN

This app includes openvpn as a binary. It is taken from the Tunnelblick binary distributions. The current version is `openvpn-2.4.7-openssl-1.1.1b`. No patches are applied to the openvpn binary, though the up and down scripts are edited to fit our needs and avoid namespace collisions. Note that Tunnelblick does apply some (minor) patches to the official openvpn source code.

### Notes

The helper will only run binaries that are signed. This is automatically done with a run script during the build process.

To verify code signing and priviliged helper settings use the SMJobBlessUtil.py tool.

    $ Tools/SMJobBlessUtil.py check eduVPN.app

Another tool that can be used to verify settings is [RB App Checker Lite](https://itunes.apple.com/nl/app/rb-app-checker-lite/id519421117?l=en&mt=12). (It currently crashes when you launch the app directly on macOS 10.13. Workaround: drag the eduVPN.app onto the RB App Checker Lite.app icon.)

The bundle identifier (`CFBundleIdentifier`) in the helper's Info.plist should be spelled out. Correct: `org.eduvpn.app.openvpnhelper`, wrong: `$(PRODUCT_BUNDLE_IDENTIFIER)`.

### Building

You need [Carthage](https://github.com/Carthage/Carthage) to build dependencies.

A version for distribution can be build using the provided script `build.sh`:

    > ./build.sh 
    Build Script for eduVPN (and derivatives)

    Which target do you want to build?
    1. eduVPN
    2. Let's Connect!
    0-9?1

    Which signing identity do you want to use?
    1. SURFnet B.V. (ZYJ4TZX4UU)
    2. Egeniq (E85CT7ZDJC)
    3. Other
    0-9?1

    You are currently on branch release/test1.

    Continue building eduVPN.app version test1 (using Developer ID Application: SURFnet B.V. (ZYJ4TZX4UU)) (y/n)?y
    
    (etc.)


### Building dependencies

To build with Xcode 10 using Carthage use:

    tee ${PWD}/Carthage/64bit.xcconfig <<-'EOF'
    ARCHS = $(ARCHS_STANDARD_64_BIT)
    EOF

    XCODE_XCCONFIG_FILE="${PWD}/Carthage/64bit.xcconfig" carthage build --platform macOS --no-skip-current --verbose

### Uninstalling

You can use the provided script `uninstall.sh` to uninstall the helper files.

Besides deleting the app, files are installed at these locations:

    /Library/LaunchDaemons/org.eduvpn.app.openvpnhelper.plist
    /Library/PrivilegedHelperTools/org.eduvpn.app.openvpnhelper
    ~/Library/Application Support/eduVPN/
    ~/Library/Caches/org.eduvpn.app/
    ~/Library/Preferences/org.eduvpn.app.plist
    
and in a temporary folder as provided by macOS, usually somewhere under `/private/var/folders`.

You need to logout or even restart your computer to complete the uninstall.

### Documentation

Please refer to [ARCH.md](ARCH.md) for an overview of the application architecture.
