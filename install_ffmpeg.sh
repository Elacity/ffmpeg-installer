#!/bin/bash
set -e

ARCH=${1:-"$(uname -m)"}
FFMPEG_PREFIX=${2:-/opt/lib/ffmpeg}
FFMPEG_VERSION=${3:-"6.0"}

# 1Gb by default or you can set to  2Gb = 2146435072
MAXIMUM_MEMORY=1073741824

# the basics for ffmpeg build
# see https://gist.github.com/omegdadi/6904512c0a948225c81114b1c5acb875
CONFIG_ARGS=(
  --prefix=$FFMPEG_PREFIX
  --enable-version3
  --disable-sdl2 # may need this on non-MSE rendering
  --enable-decoder=h264
  --enable-decoder=av1
  --enable-decoder=opus
  --pkg-config-flags="--static"
  --disable-stripping       # disable stripping
  --disable-doc             # disable doc
  --disable-htmlpages
  --disable-manpages
  --disable-podpages
  --disable-txtpages
  #--disable-logging
  --disable-devices
  --disable-hwaccels

  # development purpose
  --disable-debug
  --disable-indevs
  --disable-outdevs # this may be need when using gpl  

  --enable-protocol=http
  --enable-protocol=httpproxy
  --enable-protocol=tcp
)

CONFIGURE="./configure"
MAKE="make"

export PKG_PATH="/usr/lib/pkgconfig"

libs_only=0
need_sudo=0

# handle dynamic arguments
if [[ "$OSTYPE" == "darwin"* ]]; then
  VALID_ARGS=$(getopt -o h --l help,bindir:,maximum-memory:,libs-only,enable-libopus,libopus-prefix:,enable-libdav1d,libdav1d-prefix:,enable-libaom,libaom-prefix:,enable-libx264,libx264-prefix:,enable-libxml2,libxml2-prefix:,enable-openssl,openssl-prefix:,sudo: -- "$@")
else
  VALID_ARGS=$(getopt -o h --long help,bindir:,maximum-memory:,libs-only,enable-libopus,libopus-prefix:,enable-libdav1d,libdav1d-prefix:,enable-libaom,libaom-prefix:,enable-libx264,libx264-prefix:,enable-libxml2,libxml2-prefix:,enable-openssl,openssl-prefix:,sudo: -- "$@")
fi

eval set -- "$VALID_ARGS"
while [ : ]; do
  case "$1" in
    --sudo)
      need_sudo=1
      shift 1
      ;;
    --maximum-memory)
      MAXIMUM_MEMORY=$2
      shift 2
      ;;

    --libs-only)
      libs_only=1
      CONFIG_ARGS+=(
        --disable-programs
        --disable-ffmpeg
        --disable-ffplay
        --disable-ffprobe
        --disable-doc
        --disable-swresample
        --disable-swscale
        --disable-avfilter
        --disable-avdevice
      )
      shift 1
      ;;

    --bindir)
      CONFIG_ARGS+=(
        --bindir=$2
      )
      shift 2
      ;;

    --enable-libopus)
      CONFIG_ARGS+=(
        --enable-libopus
      )
      shift 1
      ;;
    --libopus-prefix)
      export PKG_PATH="$PKG_PATH:$2/lib/pkgconfig"
      shift 2
      ;;

    --enable-libdav1d)
      CONFIG_ARGS+=(
        --enable-libdav1d
      )
      shift 1
      ;;
    --libdav1d-prefix)
      if [ "$ARCH" == "wasm32" ]; then
        export PKG_PATH="$PKG_PATH:$2/lib/pkgconfig"
      else 
        export PKG_PATH="$PKG_PATH:$2/lib/$(uname -m)-$(uname -s | tr '[:upper:]' '[:lower:]')-gnu/pkgconfig"
      fi
      shift 2
      ;;

    --enable-libaom)
      CONFIG_ARGS+=(
        --enable-libaom
      )
      shift 1
      ;;
    --libaom-prefix)
      export PKG_PATH="$PKG_PATH:$2/lib/pkgconfig"
      shift 2
      ;;     

    --enable-libx264)
      CONFIG_ARGS+=(
        --enable-gpl      # enable GPL, it comes with x264
        --enable-libx264
      )
      shift 1
      ;;
    --libx264-prefix)
      export PKG_PATH="$PKG_PATH:$2/lib/pkgconfig"
      shift 2
      ;;

    --enable-libxml2)
      CONFIG_ARGS+=(
        --enable-demuxer=dash
        --enable-libxml2
      )
      shift 1
      ;;
    --libxml2-prefix)
      export PKG_PATH="$PKG_PATH:$2/lib/pkgconfig"
      shift 2
      ;;

    --enable-openssl)
      CONFIG_ARGS+=(
        --enable-openssl
        --enable-protocol=https
        --enable-protocol=crypto
        --enable-protocol=tls        
      )
      shift 1
      ;;
    --openssl-prefix)
      if [ "$ARCH" == "wasm32" ]; then
        export PKG_PATH="$PKG_PATH:$2/libx32/pkgconfig"
      else 
        export PKG_PATH="$PKG_PATH:$2/lib64/pkgconfig"
      fi
      shift 2
      ;;
    -h | --help)
      echo "usage: $0 <ffmpeg-options>, see https://ffmpeg.org/ffmpeg.html for more details"
      exit 0
      ;;
    --)
      shift
      break
      ;;
    *) # unknown option
      CONFIG_ARGS+=("$1")
      shift
      ;;
  esac
done

# Check if both OpenSSL and libx264 (GPL) are enabled
for arg in "${CONFIG_ARGS[@]}"; do
  if [ "$arg" == "--enable-openssl" ]; then
    has_openssl=1
  fi
  if [ "$arg" == "--enable-gpl" ]; then
    has_gpl=1
  fi
done

# If both OpenSSL and GPL are enabled, add --enable-nonfree to allow their combination
if [ "${has_openssl:-0}" -eq 1 ] && [ "${has_gpl:-0}" -eq 1 ]; then
  echo "Both OpenSSL and GPL-licensed components detected. Adding --enable-nonfree flag."
  CONFIG_ARGS+=(
    --enable-nonfree
  )
fi

if [ "$ARCH" != "$(uname -m)" ]; then
  # target architecture is different from host architecture
  if [ "$ARCH" == "wasm32" ]; then
    export EMCC_FORCE_STDLIBS=1
    export EM_PKG_CONFIG_PATH=$PKG_PATH
    export PKG_CONFIG_PATH=$PKG_PATH  # Also set the standard pkg-config path
    
    echo "PKG_CONFIG_PATH: $PKG_CONFIG_PATH"
    echo "EM_PKG_CONFIG_PATH: $EM_PKG_CONFIG_PATH"
    
    # Debug: Check if pkg-config can find OpenSSL
    echo "Checking if pkg-config can find OpenSSL:"
    pkg-config --modversion openssl || echo "pkg-config couldn't find openssl"
    pkg-config --modversion libssl || echo "pkg-config couldn't find libssl"
    
    CONFIGURE="emconfigure ./configure"
    MAKE="emmake make"

    CFLAGS="-sUSE_PTHREADS"
    LDFLAGS="$CFLAGS -sINITIAL_MEMORY=33554432 -sMAXIMUM_MEMORY=$MAXIMUM_MEMORY -sALLOW_MEMORY_GROWTH=1"
    CONFIG_ARGS+=(
      --target-os=none          # use none to prevent any os specific configurations
      --arch=x86_32             # use x86_32 to achieve minimal architectural optimization
      --enable-cross-compile    # enable cross compile
      --disable-x86asm          # disable x86 asm
      --disable-inline-asm      # disable inline asm
      --enable-pthreads
      --extra-cflags="$CFLAGS"
      --extra-cxxflags="$CFLAGS"
      --extra-ldflags="$LDFLAGS"
      --extra-libs="-lpthread -lm"
      --ar=emar
      --ranlib=emranlib
      --cc=emcc
      --cxx=em++
      --objcc=emcc
      --dep-cc=emcc
    )
  fi
else
  export PKG_CONFIG_PATH="$PKG_PATH"
  echo $PKG_CONFIG_PATH
fi

# install ffplay if --libs-only is not set
if [ $libs_only -eq 0 ]; then
  CONFIG_ARGS+=(
    --enable-ffplay
  )
fi

echo "installing ffmpeg ${FFMPEG_VERSION}..."
mkdir -p $FFMPEG_PREFIX/source && cd $FFMPEG_PREFIX/source
wget --continue https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.xz -O ffmpeg-${FFMPEG_VERSION}.tar.xz
tar -xf ffmpeg-${FFMPEG_VERSION}.tar.xz
cd ffmpeg-${FFMPEG_VERSION}

# Add debugging to see where FFmpeg is looking for libraries
echo "Running FFmpeg configure with verbose output to debug OpenSSL detection..."
${CONFIGURE} "${CONFIG_ARGS[@]}"

# If the above fails, try to find the config.log file which contains detailed information
if [ $? -ne 0 ]; then
  echo "Configure failed. Searching for config.log..."
  find . -name "config.log" -exec cat {} \; | grep -i openssl
  echo "Checking FFmpeg's configure script for OpenSSL detection logic..."
  grep -n -A 5 -B 5 "openssl" ./configure
  exit 1
fi
${MAKE}
if [ $libs_only -eq 0 ]; then
  if [ $need_sudo -eq 1 ]; then
    # there should binary available that we store as sudo
    sudo -S ${MAKE} install
  else
    ${MAKE} install
  fi
else
  ${MAKE} install
fi

# teardown
rm -Rf $FFMPEG_PREFIX/source
