#!/bin/bash
set -e
set -u

ARCH=${1:-"$(uname -m)"}
LIBXML2_PREFIX=${2:-/opt/lib/libxml2}
LIBXML2_VERSION=${3:-"2.10.1"}

CONFIGURE="./configure"
MAKE="make"

if [ "$ARCH" != "$(uname -m)" ]; then
  # target architecture is different from host architecture
  if [ "$ARCH" == "wasm32" ]; then
    CONFIGURE="emconfigure ./configure"
    MAKE="emmake make"
  fi
fi

echo "installing libxml2..."
mkdir -p $LIBXML2_PREFIX/source && cd $LIBXML2_PREFIX/source
wget --continue "https://gitlab.gnome.org/GNOME/libxml2/-/archive/v${LIBXML2_VERSION}/libxml2-v${LIBXML2_VERSION}.tar.gz" -O libxml2-v${LIBXML2_VERSION}.tar.gz
tar -xf libxml2-v${LIBXML2_VERSION}.tar.gz
cd libxml2-v${LIBXML2_VERSION}

BUILD_ARGS=(
  --enable-shared=no
  --enable-static=yes
  --disable-maintainer-mode
  --with-http=no
  --with-html=no
  --with-ftp=no
  --with-python=no
  --with-writer=no
  --with-docbook=no
  --with-debug=no               # set to 'yes' to enable debug
  --prefix=$LIBXML2_PREFIX
  --exec-prefix=$LIBXML2_PREFIX
)

sh -c "./autogen.sh"
${CONFIGURE} "${BUILD_ARGS[@]}"
${MAKE} install

# Apply change for ffmpeg requirement
cd $LIBXML2_PREFIX
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS requires an argument after -i (even if it's an empty string)
  sed -i '' 's@-I${includedir}/libxml2@& -I${includedir}@' lib/pkgconfig/libxml-2.0.pc
else
  # Linux/other systems
  sed -i 's@-I${includedir}/libxml2@& -I${includedir}@' lib/pkgconfig/libxml-2.0.pc
fi

# teardown
rm -Rf $LIBXML2_PREFIX/source
