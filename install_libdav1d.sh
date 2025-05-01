#!/bin/bash
set -e
set -u

ARCH=${1:-x86_64}
DAV1D_PREFIX=${2:-/opt/lib/libdav1d}
DAV1D_VERSION=${3:-1.3.0} # 1.3.0 is the latest version as of 2024-01-18

crosscompile=()
if [ "$ARCH" != "$(uname -m)" ]; then
  # target architecture is different from host architecture
  # will enable cross complie
  crosscompile+=(
    --cross-file=package/crossfiles/${ARCH}.meson
  )
fi

echo "installing dav1d ${DAV1D_VERSION} for ${ARCH} into ${DAV1D_PREFIX}..."

mkdir -p $DAV1D_PREFIX/source && cd $DAV1D_PREFIX/source
rm -Rf dav1d dav1d-*
wget --continue --no-check-certificate https://code.videolan.org/videolan/dav1d/-/archive/${DAV1D_VERSION}/dav1d-${DAV1D_VERSION}.tar.gz -O dav1d.tar.gz
tar -xf dav1d.tar.gz
cd dav1d-${DAV1D_VERSION}

echo "preparing dav1d compilation"
echo "meson version $(meson --version)"
echo "Ninja version $(ninja --version)"

BUILD_ARGS=(
  # disable debug on production
  # --debug
  --prefix=$DAV1D_PREFIX
  --default-library=static
  -Denable_tests=false
  -Denable_tools=false
  -Denable_examples=false
)

meson setup build "${BUILD_ARGS[@]}" "${crosscompile[@]}"
ninja -C build
ninja -C build install

# teardown
rm -Rf $DAV1D_PREFIX/source