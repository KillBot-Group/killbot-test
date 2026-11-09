#!/bin/bash
#
# Refresh KillBot from the main repository, or from the test repository.
#
# Usage:
#   sudo /opt/killbot/UpdateAll.sh
#   sudo /opt/killbot/UpdateAll.sh main
#   sudo /opt/killbot/UpdateAll.sh test
#   sudo /opt/killbot/UpdateAll.sh latest
#   sudo /opt/killbot/UpdateAll.sh v3.4
#   sudo /opt/killbot/UpdateAll.sh <commit>
#
set -e

KB_MAIN_REPO="KillBot-Group/killbot"
KB_TEST_REPO="KillBot-Group/killbot-test"
REF="${1:-main}"

usage() {
    echo "Usage: $0 [main|test|latest|TAG|BRANCH|COMMIT]"
    echo "  (no arg) / main     installer and files from ${KB_MAIN_REPO}"
    echo "  test                installer and files from ${KB_TEST_REPO}"
    echo "  latest              installer from GitHub Releases of the main repository"
    echo "  v3.4                installer from that GitHub Release of the main repository"
    echo "  BRANCH / COMMIT     that revision of the main repository"
    exit 1
}

case "$REF" in
    -h|--help) usage ;;
esac

if [[ ! "$REF" =~ ^[A-Za-z0-9._/-]+$ ]] || [[ "$REF" == *..* ]]; then
    echo "ERROR: invalid ref: ${REF}"
    usage
fi

is_release_tag() {
    [[ "$1" =~ ^v?[0-9]+(\.[0-9]+)*$ ]]
}

release_tag() {
    local tag="$1"
    [[ "$tag" == v* ]] || tag="v${tag}"
    echo "$tag"
}

installer_url() {
    local ref="$1" tag
    case "$ref" in
        latest|release)
            echo "https://github.com/${KB_GIT_REPO}/releases/latest/download/kb_install.sh"
            ;;
        *)
            if is_release_tag "$ref"; then
                tag="$(release_tag "$ref")"
                echo "https://github.com/${KB_GIT_REPO}/releases/download/${tag}/kb_install.sh"
            else
                echo "https://raw.githubusercontent.com/${KB_GIT_REPO}/${ref}/kb_install.sh"
            fi
            ;;
    esac
}

install_ref() {
    local ref="$1"
    case "$ref" in
        latest|release)
            echo "main"
            ;;
        *)
            if is_release_tag "$ref"; then
                release_tag "$ref"
            else
                echo "$ref"
            fi
            ;;
    esac
}

if [[ "$REF" == "test" ]]; then
    KB_GIT_REPO="${KB_TEST_REPO}"
    KB_GIT_REF="main"
    URL="$(installer_url "main")"
else
    KB_GIT_REPO="${KB_MAIN_REPO}"
    URL="$(installer_url "$REF")"
    KB_GIT_REF="$(install_ref "$REF")"
fi

rm -f kbi.sh
rm -f kb_install.sh
echo "Downloading kb_install.sh from ${URL}"
echo "Repository ${KB_GIT_REPO}, ref ${KB_GIT_REF}"
wget -O kbi.sh "$URL"
chmod +x kbi.sh
echo "Installing with KB_GIT_REPO=${KB_GIT_REPO} KB_GIT_REF=${KB_GIT_REF}"
yes '' | sudo DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a KB_GIT_REPO="${KB_GIT_REPO}" KB_GIT_REF="${KB_GIT_REF}" ./kbi.sh
