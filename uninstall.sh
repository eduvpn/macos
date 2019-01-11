#!/bin/bash
echo "This will uninstall files related to eduVPN"
read -p "Continue (y/n)?" choice
case "$choice" in 
  y|Y ) ;;
  n|N ) echo "Aborting uninstall."; exit 0;;
  * ) echo "Invalid response."; exit 0;;
esac

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

echo "Removing helper process, you can now reinstall openvpn helper tool without restarting the MAC"
sudo launchctl remove org.eduvpn.app.openvpnhelper

echo "Uninstall completed. Reboot your machine for the uninstall to complete."
echo ""
echo "Do you want to reboot now?"
read -p "Reboot (y/n)?" choice
case "$choice" in 
  y|Y ) ;;
  n|N ) echo "Not rebooting. Please reboot later."; exit 0;;
  * ) echo "Invalid response. Not rebooting. Please reboot later."; exit 0;;
esac
sudo reboot
