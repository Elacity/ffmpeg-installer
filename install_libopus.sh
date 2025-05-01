#!/bin/bash
set -e

ARCH=${1:-"$(uname -m)"}
OPUS_PREFIX=${2:-/opt/lib/opus}
OPUS_VERSION=${3:-1.4}

CONFIGURE="./configure"
MAKE="make"

crosscompile=()
if [ "$ARCH" != "$(uname -m)" ]; then
  # target architecture is different from host architecture
  if [ "$ARCH" == "wasm32" ]; then
    CONFIGURE="emconfigure ./configure"
    MAKE="emmake make"
  fi
fi

echo "installing libopus ${OPUS_PREFIX} for ${ARCH} into ${OPUS_VERSION}..."
mkdir -p $OPUS_PREFIX/source && cd $OPUS_PREFIX/source
rm -Rf opus opus-*
wget --continue --no-check-certificate "https://github.com/xiph/opus/releases/download/v${OPUS_VERSION}/opus-${OPUS_VERSION}.tar.gz" -O opus.tar.gz
tar -xf opus.tar.gz
cd opus-${OPUS_VERSION}

echo "preparing opus compilation"

BUILD_ARGS=(
	--prefix=$OPUS_PREFIX
	--enable-shared=no
	--disable-asm
	--disable-rtcd
	--enable-check-asm
	--disable-doc
	--disable-extra-programs
	--disable-stack-protector
)

if [[ "$OSTYPE" == "darwin"* ]]; then
  BUILD_ARGS+=(
	--disable-intrinsics
	--disable-neon
  )
fi

${CONFIGURE} "${BUILD_ARGS[@]}"
${MAKE}
make install

# teardown
rm -Rf $OPUS_PREFIX/source