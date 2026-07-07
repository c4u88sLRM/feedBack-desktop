#!/bin/bash

# Build the JUCE audio engine as a Node.js native addon
# Usage: ./scripts/build-audio.sh [debug|release]
# Optional env:
#   MACOS_BUILD_ARCH=universal  -> build arm64 + x64 and lipo merge on macOS

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

BUILD_TYPE="${1:-Release}"
MACOS_BUILD_ARCH="${MACOS_BUILD_ARCH:-native}"

cd "$PROJECT_DIR"

# Ensure JUCE submodule is available
if [ ! -f "JUCE/CMakeLists.txt" ]; then
    echo "Initializing JUCE submodule..."
    git submodule update --init --recursive
fi

# Ensure node_modules exist (for node-addon-api headers)
if [ ! -d "node_modules" ]; then
    echo "Installing npm dependencies..."
    npm install
fi

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
    x86_64) CMAKE_ARCH="x64" ;;
    aarch64|arm64) CMAKE_ARCH="arm64" ;;
    *) CMAKE_ARCH="$ARCH" ;;
esac

# Linux compiler selection (unchanged)
if [ "$(uname -s)" = "Linux" ] && [ -z "${CXX:-}" ]; then
    default_major="$(g++ -dumpversion 2>/dev/null | cut -d. -f1)"
    if [ -n "$default_major" ] && [ "$default_major" -lt 12 ] 2>/dev/null; then
        for v in 14 13 12; do
            if command -v "g++-$v" >/dev/null 2>&1; then
                export CC="gcc-$v" CXX="g++-$v"
                echo "Default g++ is $default_major (<12, lacks std::atomic<shared_ptr>); using g++-$v for the NAM A2 sources"
                if [ -f build/CMakeCache.txt ] && ! grep -q "CMAKE_CXX_COMPILER:.*g++-$v" build/CMakeCache.txt; then
                    echo "Removing stale build/ (configured with a different compiler) so cmake reconfigures"
                    rm -rf build
                fi
                break
            fi
        done
        if [ -z "${CXX:-}" ]; then
            echo "Warning: default g++ is $default_major (<12) and no g++-12+ was found." >&2
            echo "         The NAM A2 sources need std::atomic<shared_ptr> (GCC 12+ libstdc++); the build will likely fail." >&2
        fi
    fi
fi

echo "Detecting Electron version..."
ELECTRON_PKG="node_modules/electron/package.json"
if [[ ! -f "$ELECTRON_PKG" ]]; then
    echo "Error: $ELECTRON_PKG not found. Run \`npm install\` before building native addons." >&2
    exit 1
fi
ELECTRON_VERSION=$(node -p "require('./$ELECTRON_PKG').version" 2>/dev/null | tr -d '\r\n')
if [[ -z "$ELECTRON_VERSION" ]]; then
    echo "Error: failed to read Electron version from $ELECTRON_PKG." >&2
    exit 1
fi
echo "  Electron version: $ELECTRON_VERSION"

build_one_arch() {
    local target_arch="$1"

    export CMAKE_JS_RUNTIME="electron"
    export CMAKE_JS_RUNTIME_VERSION="$ELECTRON_VERSION"
    export CMAKE_JS_ARCH="$target_arch"

    export npm_config_runtime="electron"
    export npm_config_target="$ELECTRON_VERSION"
    export npm_config_arch="$target_arch"
    export npm_config_target_arch="$target_arch"

    if [ "${CLEAN_CMAKE_JS:-}" = "1" ] || { [ -n "${CI:-}" ] && [ -d "$HOME/.cmake-js" ]; }; then
      echo "Clearing cmake-js cache..."
      rm -rf "$HOME/.cmake-js"
    fi

    echo ""
    echo "Building audio engine..."
    echo "  Platform: $(uname -s)"
    echo "  Arch: $target_arch"
    echo "  Electron: $ELECTRON_VERSION"
    echo "  Build type: $BUILD_TYPE"
    echo ""

    echo "Environment for cmake-js:"
    echo "  CMAKE_JS_RUNTIME=$CMAKE_JS_RUNTIME"
    echo "  CMAKE_JS_RUNTIME_VERSION=$CMAKE_JS_RUNTIME_VERSION"
    echo "  CMAKE_JS_ARCH=$CMAKE_JS_ARCH"
    echo "  npm_config_runtime=$npm_config_runtime"
    echo "  npm_config_target=$npm_config_target"
    echo ""

    npx cmake-js build \
        --runtime electron \
        --runtime-version "$ELECTRON_VERSION" \
        --arch "$target_arch" \
        --CDCMAKE_BUILD_TYPE="$BUILD_TYPE"
}

# Universal macOS mode: build arm64 + x64 and merge .node
if [[ "$(uname -s)" == "Darwin" && "$MACOS_BUILD_ARCH" == "universal" ]]; then
    echo "macOS universal mode enabled for audio addon"

    # arm64 build
    rm -rf build
    build_one_arch arm64
    ARM_NODE="$(find build -name "slopsmith_audio.node" | head -n1 || true)"
    if [[ -z "${ARM_NODE:-}" || ! -f "$ARM_NODE" ]]; then
        echo "Error: arm64 slopsmith_audio.node not found" >&2
        exit 1
    fi
    cp "$ARM_NODE" /tmp/slopsmith_audio.arm64.node

    # x64 build
    rm -rf build
    build_one_arch x64
    X64_NODE="$(find build -name "slopsmith_audio.node" | head -n1 || true)"
    if [[ -z "${X64_NODE:-}" || ! -f "$X64_NODE" ]]; then
        echo "Error: x64 slopsmith_audio.node not found" >&2
        exit 1
    fi
    cp "$X64_NODE" /tmp/slopsmith_audio.x64.node

    # Merge to universal at final expected output path
    mkdir -p build/Release
    lipo -create /tmp/slopsmith_audio.arm64.node /tmp/slopsmith_audio.x64.node \
        -output build/Release/slopsmith_audio.node

    ARCHS="$(lipo -archs build/Release/slopsmith_audio.node 2>/dev/null || true)"
    if [[ "$ARCHS" != *"arm64"* || "$ARCHS" != *"x86_64"* ]]; then
        echo "Error: merged addon is not universal: ${ARCHS:-<none>}" >&2
        exit 1
    fi

    echo ""
    echo "Build complete (universal)!"
    echo "Output: build/Release/slopsmith_audio.node"
    ls -lh build/Release/slopsmith_audio.node
    echo "Architectures: $ARCHS"
else
    # Native single-arch build (existing behavior)
    build_one_arch "$CMAKE_ARCH"

    echo ""
    echo "Build complete!"
    if [ -f "build/Release/slopsmith_audio.node" ]; then
        echo "Output: build/Release/slopsmith_audio.node"
        ls -lh "build/Release/slopsmith_audio.node"
    else
        echo "Warning: slopsmith_audio.node not found in expected location"
        find build -name "*.node" 2>/dev/null
    fi
fi
