#!/usr/bin/env bash

# Creates installer for different channel versions.
# Run this script from the local BlackHole repo's root directory.
# If this script is not executable from the Terminal, 
# it may need execute permissions first by running this command:
#   chmod +x create_installer.sh

devTeamID="YR8DY3NL4F" # ⚠️ Replace this with your own developer team ID
notarize=true # To skip notarization, set this to false
notarizeProfile="Developer ID Installer: TIM ALEXANDER PROEGLER (YR8DY3NL4F)" # ⚠️ Replace this with your own notarytool keychain profile name

############################################################################

# Basic Validation
if [ ! -d BlackHole.xcodeproj ]; then
    echo "This script must be run from the BlackHole repo root folder."
    echo "For example:"
    echo "  cd /path/to/BlackHole"
    echo "  ./Installer/create_installer.sh"
    exit 1
fi

declare -a arr=("A1" "A2" "B1" "B2")
version="0.5.0"
driverName="SLP-Virtual"

for ver in "${arr[@]}"; do
    # Env
    bundleID="audio.sessionlinkpro.$driverName-$ver"
    
    # Build
    xcodebuild \
      -project BlackHole.xcodeproj \
      -configuration Release \
      -target BlackHole CONFIGURATION_BUILD_DIR=build \
      PRODUCT_BUNDLE_IDENTIFIER=$bundleID \
      GCC_PREPROCESSOR_DEFINITIONS='$GCC_PREPROCESSOR_DEFINITIONS 
      kNumber_Of_Channels=2 
      kPlugIn_BundleID=\"'$bundleID'\"
      kPlugIn_Icon=\"SLP-Virtual.icns\"
      kDevice_Name=\"'$driverName'\ '$ver'\" 
      kDriver_Name=\"'$driverName'\ '$ver'\"'
    
    # Generate a new UUID
    uuid=$(uuidgen)
    awk '{sub(/e395c745-4eea-4d94-bb92-46224221047c/,"'$uuid'")}1' build/BlackHole.driver/Contents/Info.plist > Temp.plist
    mv Temp.plist build/BlackHole.driver/Contents/Info.plist
    
    mkdir Installer/root
    driverBundleName="$driverName $ver.driver"
    mv build/BlackHole.driver "Installer/root/$driverBundleName"
    rm -r build
    
    # Sign
    codesign \
      --force \
      --deep \
      --options runtime \
      --sign $devTeamID \
      "Installer/root/$driverBundleName"
      
done

# Create package with pkgbuild
chmod 755 Installer/Scripts/preinstall
chmod 755 Installer/Scripts/postinstall

pkgbuild \
  --sign $devTeamID \
  --identifier "audio.sessionlinkpro.SLP-Virtual" \
  --root Installer/root \
  --scripts Installer/Scripts \
  --install-location /Library/Audio/Plug-Ins/HAL \
  Installer/SLP-Virtual.pkg
rm -r Installer/root

# Create installer with productbuild
cd Installer

echo "<?xml version=\"1.0\" encoding='utf-8'?>
<installer-gui-script minSpecVersion='2'>
    <title>SLP-Virtual: Virtual Audio Drivers $version</title>
    <welcome file='welcome.html'/>
    <license file='../LICENSE'/>
    <conclusion file='conclusion.html'/>
    <domains enable_anywhere='false' enable_currentUserHome='false' enable_localSystem='true'/>
    <pkg-ref id=\"audio.sessionlinkpro.SLP-Virtual\"/>
    <options customize='never' require-scripts='false' hostArchitectures='x86_64,arm64'/>
    <volume-check>
        <allowed-os-versions>
            <os-version min='10.9'/>
        </allowed-os-versions>
    </volume-check>
    <choices-outline>
        <line choice=\"audio.sessionlinkpro.SLP-Virtual\"/>
    </choices-outline>
    <choice id=\"audio.sessionlinkpro.SLP-Virtual\" visible='true' title=\"SLP-Virtual\" start_selected='true'>
        <pkg-ref id=\"audio.sessionlinkpro.SLP-Virtual\"/>
    </choice>
    <pkg-ref id=\"audio.sessionlinkpro.SLP-Virtual\" version=\"$version\" onConclusion='none'>SLP-Virtual.pkg</pkg-ref>
</installer-gui-script>" >> distribution.xml

# Build
installerPkgName="SLP-Virtual.$version.pkg"
productbuild \
  --sign $devTeamID \
  --distribution distribution.xml \
  --resources . \
  --package-path SLP-Virtual.pkg $installerPkgName
rm distribution.xml
rm -f SLP-Virtual.pkg

# Notarize and Staple
if [ "$notarize" = true ]; then
    xcrun \
      notarytool submit $installerPkgName \
      --team-id $devTeamID \
      --progress \
      --wait \
      --keychain-profile "$notarizeProfile"
    
    xcrun stapler staple $installerPkgName
fi

cd ..
