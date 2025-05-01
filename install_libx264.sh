#!/bin/bash
set -e
set -u

ARCH=${1:-"$(uname -m)"}
X264_PREFIX=${2:-/opt/lib/libx264}

CONFIGURE="./configure"
MAKE="make"

crosscompile=()
if [ "$ARCH" != "$(uname -m)" ]; then
  # target architecture is different from host architecture
  if [ "$ARCH" == "wasm32" ]; then
    CONFIGURE="emconfigure ./configure"
    MAKE="emmake make"
    crosscompile+=(
      --host=i686-gnu 
      --extra-cflags="-s USE_PTHREADS=1"
    )
  fi
fi

echo "installing x264 (master) for ${ARCH} into ${X264_PREFIX}..."

mkdir -p $X264_PREFIX/source && cd $X264_PREFIX/source
rm -Rf x264 x264-*
wget --continue --no-check-certificate https://code.videolan.org/videolan/x264/-/archive/master/x264-master.tar.gz -O x264.tar.gz
tar -xf x264.tar.gz
cd x264-master

BUILD_ARGS=(
  --prefix=$X264_PREFIX
  --exec-prefix=$X264_PREFIX
  --enable-static
  --disable-cli
  --disable-asm
  # disable below on production
  # --enable-debug
)

${CONFIGURE} "${BUILD_ARGS[@]}" "${crosscompile[@]}"
${MAKE}
make install

# teardown
rm -Rf $X264_PREFIX/source