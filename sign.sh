#!/bin/bash
# DO NOT RUN THIS SCRIPT MANUALLY OR IT WILL REMOVE Entitlements.plist
# IT IS MEANT TO BE RAN FROM INSIDE THE .app to be signed since it copies
# the Entitlements.plist file to it and then deletes it after it signs the .app
function signFile() {
    local TEAM_ID="KET68JTS3L"
    local app=`pwd`/$1
    codesign --verbose=4 -s ${TEAM_ID} --options=runtime --timestamp --deep --force ${app}
    echo "Done with signing"
}
signFile $1
