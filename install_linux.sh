set -euo pipefail

VERSION="0.2.0"
REPO="DezzurDev/Minimix"
TAG="Minimix_0.2.0"
BASE_URL="https://github.com/${REPO}/releases/download/${TAG}"

SYSTEM=0
DIR=""

usage() {
    cat <<EOF
MINIMIX installer 0.2.0 (Linux)

Usage: install_linux.sh [options]

  --version <ver>   version to install (default ${VERSION})
  --dir <path>      install directory (overrides default)
  --url <url>       direct download URL (overrides GitHub release)
  --system          system-wide install into /opt/minimix (requires root)
  --help            show this help

Default locations:
  user   ~/.local/share/minimix
  system /opt/minimix
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --help|-h) usage; exit 0 ;;
        --system) SYSTEM=1 ;;
        --version)
            [ $# -ge 2 ] || { echo "ERROR: --version needs a value" >&2; exit 1; }
            VERSION="$2"; shift ;;
        --version=*) VERSION="${1#*=}" ;;
        --dir)
            [ $# -ge 2 ] || { echo "ERROR: --dir needs a value" >&2; exit 1; }
            DIR="$2"; shift ;;
        --dir=*) DIR="${1#*=}" ;;
        --url)
            [ $# -ge 2 ] || { echo "ERROR: --url needs a value" >&2; exit 1; }
            URL="$2"; shift ;;
        --url=*) URL="${1#*=}" ;;
        *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
    esac
    shift
done

if [ "$SYSTEM" = "1" ]; then
    [ "$(id -u)" = "0" ] || { echo "ERROR: --system requires root (run with sudo)" >&2; exit 1; }
    DIR="${DIR:-/opt/minimix}"
else
    DIR="${DIR:-$HOME/.local/share/minimix}"
fi

ASSET="minimix-${VERSION}-linux.zip"
URL="${URL:-${BASE_URL}/${ASSET}}"

echo "MINIMIX installer"
echo "  version : ${VERSION}"
echo "  system  : $([ "$SYSTEM" = 1 ] && echo yes || echo no)"
echo "  install : ${DIR}"
echo ""

for tool in curl unzip; do
    command -v "$tool" >/dev/null 2>&1 || { echo "ERROR: '$tool' not found. Install it first." >&2; exit 1; }
done

mkdir -p "$DIR"

TMP="$DIR/.install_${ASSET}"
echo "  downloading $URL"
curl -fsSL --retry 2 -o "$TMP" "$URL" || {
    echo "ERROR: failed to download $URL" >&2
    echo "Make sure the release $TAG exists and $ASSET is uploaded." >&2
    rm -f "$TMP"
    exit 1
}

echo "  extracting $TMP"
unzip -q -o "$TMP" -d "$DIR" || { echo "ERROR: failed to extract archive" >&2; rm -f "$TMP"; exit 1; }
rm -f "$TMP"

BIN=""
for cand in "$DIR/bin" "$DIR/minimix-${VERSION}/bin"; do
    if [ -x "$cand/mx" ]; then BIN="$cand"; break; fi
done
[ -n "$BIN" ] || { echo "ERROR: mx binary not found after extraction" >&2; exit 1; }

add_to_path() {
    local shell_rc="$1"
    local marker="PATH+=:$BIN"
    if grep -qF "$marker" "$shell_rc" 2>/dev/null; then
        echo "  $BIN already in PATH ($shell_rc)"
        return 0
    fi
    printf '\n# MINIMIX %s\n%s\n' "$VERSION" "$marker" >> "$shell_rc"
    echo "  added '$marker' to $shell_rc"
}

echo "  adding $BIN to PATH"
if [ "$SYSTEM" = "1" ]; then
    ln -sf "$BIN/mx"    /usr/local/bin/mx
    ln -sf "$BIN/mxvm"  /usr/local/bin/mxvm
    ln -sf "$BIN/mxvm2" /usr/local/bin/mxvm2
    echo "  linked mx, mxvm, mxvm2 into /usr/local/bin"
else
    for rc in "$HOME/.bashrc" "$HOME/.profile" "$HOME/.zshrc"; do
        add_to_path "$rc"
    done
fi

echo ""
echo "Installation complete."
echo "Run:  source ~/.bashrc   (or open a new terminal)"
echo "Then:  mx --version"
