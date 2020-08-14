#!/bin/bash
set -e -x

#Download a file from internet
function GetFile {
  local uri=$1
  local path=$2
  local force=${3:-false}
  local download_retries=${4:-5}
  local retry_wait_time_seconds=${5:-30}

  if [[ -f $path ]]; then
    if [[ $force = false ]]; then
      echo "File '$path' already exists. Skipping download"
      return 0
    else
      rm -rf $path
    fi
  fi

  if [[ -f $uri ]]; then
    echo "'$uri' is a file path, copying file to '$path'"
    cp $uri $path
    return $?
  fi

  echo "Downloading $uri"
  # Use aria2c if available, otherwise use curl
  if command -v aria2c > /dev/null; then
    aria2c -q -d $(dirname $path) -o $(basename $path) "$uri"
  else
    curl "$uri" -sSL --retry $download_retries --retry-delay $retry_wait_time_seconds --create-dirs -o "$path" --fail
  fi

  return $?
}

PYTHON_EXES=("/opt/python/cp35-cp35m/bin/python3.5" "/opt/python/cp36-cp36m/bin/python3.6" "/opt/python/cp37-cp37m/bin/python3.7" "/opt/python/cp38-cp38/bin/python3.8")

SYS_LONG_BIT=$(getconf LONG_BIT)
mkdir -p /tmp/src
GLIBC_VERSION=$(getconf GNU_LIBC_VERSION | cut -f 2 -d \.)

DISTRIBUTOR=$(lsb_release -i -s)

if [[ "$DISTRIBUTOR" = "CentOS" && $SYS_LONG_BIT = "64" ]]; then
  LIBDIR="lib64"
else
  LIBDIR="lib"
fi

cd /tmp/src

  echo "Installing azcopy"
  mkdir -p /tmp/azcopy
  GetFile https://aka.ms/downloadazcopy-v10-linux /tmp/azcopy/azcopy.tar.gz
  tar --strip 1 -xf /tmp/azcopy/azcopy.tar.gz -C /tmp/azcopy
  cp /tmp/azcopy/azcopy /usr/bin
  echo "Installing cmake"
  GetFile https://github.com/Kitware/CMake/releases/download/v3.18.1/cmake-3.18.1-Linux-x86_64.tar.gz /tmp/src/cmake-3.18.1-Linux-x86_64.tar.gz
  tar -zxf /tmp/src/cmake-3.18.1-Linux-x86_64.tar.gz --strip=1 -C /usr
  echo "Installing Ninja"
  GetFile https://github.com/ninja-build/ninja/archive/v1.10.0.tar.gz /tmp/src/ninja-linux.tar.gz
  tar -zxf ninja-linux.tar.gz
  cd ninja-1.10.0
  cmake -Bbuild-cmake -H.
  cmake --build build-cmake
  mv ./build-cmake/ninja /usr/bin
  echo "Installing Node.js"
  GetFile https://nodejs.org/dist/v12.16.3/node-v12.16.3.tar.xz /tmp/src/node-v12.16.3.tar.xz
  tar -xf /tmp/src/node-v12.16.3.tar.xz
  cd node-v12.16.3
  LDFLAGS=-lrt /opt/python/cp27-cp27m/bin/python configure --ninja
  LDFLAGS=-lrt make -j$(getconf _NPROCESSORS_ONLN)
  LDFLAGS=-lrt make install

cd /tmp/src
GetFile https://downloads.gradle-dn.com/distributions/gradle-6.3-bin.zip /tmp/src/gradle-6.3-bin.zip
unzip /tmp/src/gradle-6.3-bin.zip
mv /tmp/src/gradle-6.3 /usr/local/gradle


for PYTHON_EXE in "${PYTHON_EXES[@]}"
do
  ${PYTHON_EXE} -m pip install -r ${0/%install_deps\.sh/requirements\.txt}
done


cd /
rm -rf /tmp/src
