#!/bin/bash
set -e
set -u

ARCH=${1:-"$(uname -m)"}
OPENSSL_PREFIX=${2:-/opt/lib/openssl}
OPENSSL_VERSION=${3:-"3.0.12"}

CONFIGURE="./Configure"
MAKE="make"

if [ "$ARCH" != "$(uname -m)" ]; then
  # target architecture is different from host architecture
  if [ "$ARCH" == "wasm32" ]; then
    export EMCC_FORCE_STDLIBS=1
    CONFIGURE="emconfigure ./Configure"
    MAKE="emmake make"
  fi
fi

echo "installing openssl as libssl..."
mkdir -p $OPENSSL_PREFIX/source && cd $OPENSSL_PREFIX/source
wget --continue "https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz" -O openssl-${OPENSSL_VERSION}.tar.gz
tar -xf openssl-${OPENSSL_VERSION}.tar.gz
cd openssl-${OPENSSL_VERSION}

BUILD_ARGS=(
  # disable debug on production
  # --debug
  -no-tests
  -no-asm
  -no-shared
  -no-async
  -static
  --with-rand-seed=os,devrandom,getrandom
  --prefix=$2
  --openssldir=$2
)

# When building for WebAssembly, specify a target platform that doesn't include macOS-specific flags
if [ "$ARCH" == "wasm32" && "$OSTYPE" == "darwin"* ]; then
  BUILD_ARGS=(
    linux-generic32
    "${BUILD_ARGS[@]}"
  )
fi

${CONFIGURE} "${BUILD_ARGS[@]}"

if [ "$ARCH" != "$(uname -m)" ]; then
  # Please note that there is an important remark in the generated makefile **openssl-x.x.x/Makefile** 
  # regarding the **CROSS_COMPILE** value.
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS requires an argument after -i (even if it's an empty string)
    sed -i '' 's/CROSS_COMPILE=.*$/CROSS_COMPILE=""/' Makefile
    
    # Remove macOS-specific flags when building with Emscripten on macOS
    if [ "$ARCH" == "wasm32" ]; then
      sed -i '' 's/-arch arm64//g' Makefile
      sed -i '' 's/-search_paths_first//g' Makefile
    fi
  else
    # Linux/other systems
    sed -i 's/CROSS_COMPILE=.*$/CROSS_COMPILE=""/' Makefile
  fi
fi

${MAKE}
make install_sw

# teardown
rm -Rf $OPENSSL_PREFIX/source
