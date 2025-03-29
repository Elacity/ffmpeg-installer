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
  --disable-logging
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

# handle dynamic arguments
VALID_ARGS=$(getopt -o h --long help,bindir:,maximum-memory:,libs-only,enable-libopus,libopus-prefix:,enable-libdav1d,libdav1d-prefix:,enable-libaom,libaom-prefix:,enable-libx264,libx264-prefix:,enable-libxml2,libxml2-prefix:,enable-openssl,openssl-prefix: -- "$@")
eval set -- "$VALID_ARGS"
while [ : ]; do
  case "$1" in
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

if [ "$ARCH" != "$(uname -m)" ]; then
  # target architecture is different from host architecture
  if [ "$ARCH" == "wasm32" ]; then
    export EMCC_FORCE_STDLIBS=1
    export EM_PKG_CONFIG_PATH=$PKG_PATH
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
wget https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.xz -O ffmpeg-${FFMPEG_VERSION}.tar.xz
tar -xf ffmpeg-${FFMPEG_VERSION}.tar.xz
cd ffmpeg-${FFMPEG_VERSION}

${CONFIGURE} "${CONFIG_ARGS[@]}"
${MAKE} -j$(nproc)
if [ $libs_only -eq 0 ]; then
  # there should binary available that we store as sudo
  sudo -S ${MAKE} install
else
  ${MAKE} install
fi

# teardown
rm -Rf $FFMPEG_PREFIX/source