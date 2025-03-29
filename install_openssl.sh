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
wget -nc "https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz" -O openssl-${OPENSSL_VERSION}.tar.gz
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

${CONFIGURE} "${BUILD_ARGS[@]}"

if [ "$ARCH" != "$(uname -m)" ]; then
  # Please note that there is an important remark in the generated makefile **openssl-x.x.x/Makefile** 
  # regarding the **CROSS_COMPILE** value.
  sed -i 's/CROSS_COMPILE=.*$/CROSS_COMPILE=""/' Makefile
fi

${MAKE} -j$(nproc)
make install_sw

# teardown
rm -Rf $OPENSSL_PREFIX/source