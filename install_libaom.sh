#!/bin/bash
set -e
set -u

ARCH=${1:-x86_64}
AOM_PREFIX=${2:-/opt/lib/libaom}
AOM_VERSION=${3:-3.8.0} # 3.8.0 is the latest version as of 2024-01-18

CONFIGURE="./configure"
CMAKE="cmake"
MAKE="make"

# @dev:  caveats on emscripten installation
# see https://web.dev/articles/wasm-av1#using_cmake_to_build_the_source_code
# https://aomedia.googlesource.com/aom#basic-build

EXTRA_FLAGS="-s USE_PTHREADS=1 -pthread"
BUILD_ARGS=(
  # -- for release
  -DCMAKE_BUILD_TYPE=Release
  # -- for debug
  # -DCMAKE_BUILD_TYPE=Debug
  # -DSANITIZE=address
  -DMSVC=0
  -DENABLE_CCACHE=0
  -DAOM_TARGET_CPU=generic
  
  -DENABLE_DOCS=0
  -DENABLE_TESTS=0
  -DENABLE_EXAMPLES=0
  
  # -DHAVE_PTHREAD_H=1
  # -DCONFIG_MULTITHREAD=0
  -DCONFIG_ACCOUNTING=0
  -DCONFIG_INSPECTION=0  
  -DCONFIG_RUNTIME_CPU_DETECT=0
  -DCONFIG_WEBM_IO=0
  
  -DCMAKE_INSTALL_PREFIX=$AOM_PREFIX
)

if [ "$ARCH" != "$(uname -m)" ]; then
  # target architecture is different from host architecture
  if [ "$ARCH" == "wasm32" ]; then
    CONFIGURE="emconfigure ./configure"
    CMAKE="emcmake cmake"
    MAKE="emmake make"
    BUILD_ARGS+=(
      -DCMAKE_TOOLCHAIN_FILE=$EMSDK/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake
    )
  fi  
fi

echo "installing libaom ${AOM_VERSION} into ${AOM_PREFIX}..."
mkdir -p $AOM_PREFIX/source && cd $AOM_PREFIX/source
wget --no-check-certificate https://aomedia.googlesource.com/aom/+archive/v${AOM_VERSION}.tar.gz -O aom.tar.gz
tar -xf aom.tar.gz
mkdir -p build && cd build

${CMAKE} .. "${BUILD_ARGS[@]}"
${MAKE} -j$(nproc)
${MAKE} install

# teardown
rm -Rf $AOM_PREFIX/source