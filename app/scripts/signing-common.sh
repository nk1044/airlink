# Shared by setup-signing.sh and build.sh. Source it; don't run it.
#
# The identity lives in its own keychain with a generated password, so signing never prompts
# and nothing is added to the login keychain. macOS keys the Bluetooth permission to the app's
# designated requirement (bundle id + certificate), so a stable identity keeps the permission
# across rebuilds. Ad-hoc signatures change on every build and lose it.

EARSHOT_IDENTITY="Earshot Local Signing"
EARSHOT_KEYCHAIN="${EARSHOT_KEYCHAIN:-$HOME/Library/Keychains/earshot-signing.keychain-db}"
EARSHOT_PASSWORD_FILE="${EARSHOT_PASSWORD_FILE:-$HOME/.config/earshot/signing-keychain-password}"

# Prints the identity's SHA-1, or nothing if it is not set up.
earshot_identity_hash() {
    [[ -f "$EARSHOT_KEYCHAIN" && -f "$EARSHOT_PASSWORD_FILE" ]] || return 0
    security unlock-keychain -p "$(cat "$EARSHOT_PASSWORD_FILE")" "$EARSHOT_KEYCHAIN" >/dev/null 2>&1 || return 0
    # Without -v, so the self-signed (untrusted) identity is listed too; codesign accepts it by hash.
    security find-identity -p codesigning "$EARSHOT_KEYCHAIN" 2>/dev/null |
        awk -v name="\"$EARSHOT_IDENTITY\"" 'index($0, name) && $2 ~ /^[0-9A-F]{40}$/ { print $2; exit }'
}

# earshot_sign <bundle-or-binary> <identifier>
earshot_sign() {
    local target="$1" identifier="$2" hash
    hash="$(earshot_identity_hash)"
    if [[ -n "$hash" ]]; then
        codesign --force --sign "$hash" --keychain "$EARSHOT_KEYCHAIN" --identifier "$identifier" \
            --timestamp=none "$target"
        echo "Signed with \"$EARSHOT_IDENTITY\" (${hash:0:8}…)."
    else
        echo "warning: \"$EARSHOT_IDENTITY\" is not set up, so this build is signed ad-hoc." >&2
        echo "         macOS will ask for Bluetooth permission again after every rebuild." >&2
        echo "         Run scripts/setup-signing.sh once to fix that." >&2
        codesign --force --sign - --identifier "$identifier" "$target"
    fi
    codesign --verify --strict "$target"
}
