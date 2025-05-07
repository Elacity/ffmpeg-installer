#!/bin/bash
set -e
set -u

ARCH=${1:-"$(uname -m)"}
LIBVPX_PREFIX=${2:-/opt/lib/libvpx}
LIBVPX_VERSION=${3:-"1.13.1"} # Latest stable version as of script creation

CONFIGURE="./configure"
MAKE="make"

crosscompile=()
if [ "$ARCH" != "$(uname -m)" ]; then
  # target architecture is different from host architecture
  if [ "$ARCH" == "wasm32" ]; then
    CONFIGURE="emconfigure ./configure"
    MAKE="emmake make"
    RANLIB="emranlib"
    
    # Specific flags for wasm compilation
    EXTRA_FLAGS="-s USE_PTHREADS=1"
    crosscompile+=(
      --target=generic-gnu
      --extra-cflags="$EXTRA_FLAGS"
      --extra-cxxflags="$EXTRA_FLAGS"
    )
  fi
fi

echo "Installing libvpx ${LIBVPX_VERSION} for ${ARCH} into ${LIBVPX_PREFIX}..."
mkdir -p $LIBVPX_PREFIX/source && cd $LIBVPX_PREFIX/source
rm -Rf libvpx

# Download and extract libvpx specific version
echo "Downloading libvpx ${LIBVPX_VERSION}..."

FILENAME="${LIBVPX_VERSION}.tar.gz"
URL="https://github.com/webmproject/libvpx/archive/refs/tags/${FILENAME}"

# Check if file already exists
if [ ! -f "$FILENAME" ]; then
    wget "$URL"
else
    echo "File ${FILENAME} already exists, skipping download."
fi

tar -xf "$FILENAME"

cd libvpx-${LIBVPX_VERSION#v}

# Configure build options
BUILD_ARGS=(
  --prefix=$LIBVPX_PREFIX
  --target=generic-gnu                               # target with miminal features
  --disable-install-bins                             # not to install bins
  --disable-examples                                 # not to build examples
  --disable-tools                                    # not to build tools
  --disable-docs                                     # not to build docs
  --disable-unit-tests                               # not to do unit tests
  --disable-dependency-tracking                      # speed up one-time build
)

# For wasm, disable some features that might cause issues
if [ "$ARCH" == "wasm32" ]; then
  BUILD_ARGS+=(
    --disable-multithread
  )
fi

${CONFIGURE} "${BUILD_ARGS[@]}" "${crosscompile[@]}"
${MAKE} -j$(nproc)
${MAKE} install
${RANLIB} $LIBVPX_PREFIX/lib/libvpx.a

# teardown
rm -Rf $LIBVPX_PREFIX/source

echo "libvpx installation completed successfully!"
