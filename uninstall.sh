#!/bin/bash
echo "This will uninstall files related to eduVPN"
read -p "Continue (y/n)?" choice
case "$choice" in 
  y|Y ) ;;
  n|N ) echo "Aborting uninstall."; exit 0;;
  * ) echo "Invalid response."; exit 0;;
esac

echo "Removing helper process"
sudo launchctl remove org.eduvpn.app.openvpnhelper

echo "Deleting /Library/LaunchDaemons/org.eduvpn.app.openvpnhelper.plist"
sudo rm -f /Library/LaunchDaemons/org.eduvpn.app.openvpnhelper.plist

echo "Deleting /Library/PrivilegedHelperTools/org.eduvpn.app.openvpnhelper"
sudo rm -f /Library/PrivilegedHelperTools/org.eduvpn.app.openvpnhelper

echo "Deleting ~/Library/Application Support/eduVPN/"
rm -rf ~/Library/Application\ Support/eduVPN/

echo "Deleting ~/Library/Caches/org.eduvpn.app/"
rm -rf ~/Library/Caches/org.eduvpn.app/

echo "Deleting ~/Library/Preferences/org.eduvpn.app.plist"
rm -f ~/Library/Preferences/org.eduvpn.app.plist

echo "Uninstall completed."
