#!/bin/sh

set -e

EM_VERSION=${1:=3.1.46}

apt update && apt install -y wget unzip xz-utils python3

wget https://github.com/emscripten-core/emsdk/archive/main.zip -O /opt/emsdk.zip
unzip /opt/emsdk.zip -d /opt

/opt/emsdk-main/emsdk install $EM_VERSION
/opt/emsdk-main/emsdk activate $EM_VERSION