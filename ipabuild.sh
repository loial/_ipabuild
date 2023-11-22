#!/bin/bash
usage() {
  printf 'Usage: %s [<project_path>] [<target_name.ipa>]\n' "$0"
  exit 0
}
set -e


while [[ "${1-}" ]]; do
    if [[ "$1" = "-h" ]] || [[ "$1" == "--help" ]]; then
        usage
    fi
    if [[ "${1//.ipa/}.ipa" = "$1" ]]; then
        TARGET_NAME="${1//.ipa/}"
        shift
    else
        PROJECT_PATH="$1"
        shift
    fi
done

printf '%s="%s"\n' "STATUS" "init"

PROJECT_PATH="${PROJECT_PATH-.}"
if [[ -d "${PROJECT_PATH//.xcodeproj/}.xcodeproj" ]]; then
    PROJECT_PATH="${PROJECT_PATH//.xcodeproj/}.xcodeproj"
else
    if [[ "$PROJECT_PATH" =~ .*/.* ]] || [[ "$PROJECT_PATH" == "." ]]; then
        _find="$(find "$PROJECT_PATH" -type d -name '*.xcodeproj' | head -1)"
        if [[ $_find ]]; then
            PROJECT_PATH="$_find"
        fi
    fi
fi

CURRENT_LOCATION="$(pwd)"
BUILD_PATH="$(pwd)/build"

cd "$(dirname $PROJECT_PATH)"
WORKING_LOCATION="$(pwd)"
APPLICATION_NAME="$(basename "${PROJECT_PATH//.xcodeproj/}")" # "Chicken Butt"

if [[ -z "$TARGET_NAME" ]]; then
    if [[ "$APPLICATION_NAME" != "App" ]]; then
        TARGET_NAME="$APPLICATION_NAME"
    else
        TARGET_NAME="$(basename "$(git rev-parse --show-toplevel)")"
    fi
fi

mkdir -p "$BUILD_PATH"
cd "$BUILD_PATH"

STATUS=running

# output current variables
for var in APPLICATION_NAME TARGET_NAME PROJECT_PATH STATUS ; do
    printf '%s="%s"\n' "$var" "${!var}"
done

# store original stdout
exec 9>&1
# send all output to stderr
exec 1>&2


xcodebuild -project "$PROJECT_PATH" \
    -scheme "$APPLICATION_NAME" \
    -configuration Release \
    -derivedDataPath "$BUILD_PATH/DerivedDataApp" \
    -destination 'generic/platform=iOS' \
    clean build \
    CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGN_ENTITLEMENTS="" CODE_SIGNING_ALLOWED="NO"

DD_APP_PATH="$BUILD_PATH/DerivedDataApp/Build/Products/Release-iphoneos/$APPLICATION_NAME.app"
TARGET_APP="$BUILD_PATH/$TARGET_NAME.app"
cp -r "$DD_APP_PATH" "$TARGET_APP"

codesign --remove "$TARGET_APP"
if [ -e "$TARGET_APP/_CodeSignature" ]; then
    rm -rf "$TARGET_APP/_CodeSignature"
fi
if [ -e "$TARGET_APP/embedded.mobileprovision" ]; then
    rm -rf "$TARGET_APP/embedded.mobileprovision"
fi

# Add entitlements
#echo "Adding entitlements"
#chmod a+x $WORKING_LOCATION/bin/ldid
#$WORKING_LOCATION/bin/ldid -S"$WORKING_LOCATION/entitlements.plist" "$TARGET_APP/$APPLICATION_NAME"

mkdir Payload
cp -r "$TARGET_APP" "Payload/${TARGET_NAME}.app"
strip "Payload/${TARGET_NAME}.app/${TARGET_NAME}"
zip -vr "${TARGET_NAME}.ipa" Payload
rm -rf "$TARGET_APP"
rm -rf Payload

# revert to normal stdout
exec 1>&9

echo 'STATUS=complete'

# output full path to the .ipa
printf 'FILENAME='
readlink -f "${TARGET_NAME}.ipa"
