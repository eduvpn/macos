#!/bin/bash

# TODO: Make this customizable?
TARGET="eduVPN"

echo "Build Script for $TARGET"
echo ""

BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "You are currently on branch $BRANCH."

if [[ $BRANCH != "release/"* ]]
then
    echo "You must always build from a release branch. Switch to the correct branch or ask the developer to create it for you."
    exit
fi

VERSION=$(git rev-parse --abbrev-ref HEAD | cut -d "/" -f 2)

read -p "Continue building $TARGET version $VERSION (y/n)?" choice
case "$choice" in
  y|Y ) ;;
  n|N ) exit 0;;
  * ) echo "Invalid response."; exit 0;;
esac

FILENAME="$TARGET-$VERSION"

echo ""
echo "Bootstrapping dependencies using carthage"
carthage bootstrap --cache-builds --platform macOS

# TODO: Let user specify Development Team

echo ""
echo "Building and archiving"
xcodebuild archive -project eduVPN.xcodeproj -scheme $TARGET -archivePath $FILENAME.xcarchive

echo ""
echo "Exporting"
xcodebuild -exportArchive -archivePath $FILENAME.xcarchive -exportPath $FILENAME -exportOptionsPlist ExportOptions.plist

echo ""
read -p "Create disk image (requires DropDMG license) (y/n)?" choice
case "$choice" in
  y|Y ) ;;
  n|N ) exit 0;;
  * ) echo "Invalid response."; exit 0;;
esac

echo ""
echo "Creating a disk image"
dropdmg --config-name "$TARGET" $FILENAME/$TARGET.app

echo ""
echo "Creating app cast XML"
DISTRIBUTIONPATH="../eduvpn-macos-distrib/"
# Assumptions are being made about the location of this script
# Also, this often fails due to extended attribute
echo "Using: $DISTRIBUTIONPATH/generate_appcast $DISTRIBUTIONPATH/dsa_priv.pem $DISTRIBUTIONPATH/updates/"
$DISTRIBUTIONPATH/generate_appcast $DISTRIBUTIONPATH/dsa_priv.pem $DISTRIBUTIONPATH/updates/

echo ""
echo "Done! You can now upload the files in the updates folders to your file server. Also remember to merge the release branch into master and tag it."