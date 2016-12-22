#Docker Search vuln & analyz
# Pull base image.
# Base box on Debian Jessie OS
FROM debian:8.0
MAINTAINER Lionel PRAT <lionel.prat9@gmail.com>

#set proxy env

#change sources.list
ADD src/sources.list /etc/apt/sources.list
ADD src/environment /etc/environment
#install compiler + utils
RUN apt-get update && apt-get install -y build-essential make wget flex bison git pkg-config python-pip python-lzma binutils cmake libgmp-dev gcc-4.9-plugin-dev
RUN apt-get install -y curl bc libcap-dev libboost-all-dev libncurses5-dev python-minimal unzip subversion xz-utils nano vim zlib1g-dev

#install for package build
RUN apt-get install -y fakeroot dpkg-dev devscripts

#trace tool & splint
RUN apt-get install -y strace ltrace splint gdb

#install radare2
RUN cd /opt/ && git clone https://github.com/radare/radare2.git && cd /opt/radare2/ && bash sys/install.sh

#install binwalk
RUN cd /tmp && git clone https://github.com/devttys0/binwalk.git && cd /tmp/binwalk && python setup.py install && cd /tmp && rm -rf /tmp/binwalk

#install binvis
RUN cd /opt/ && git clone https://github.com/cortesi/scurve.git && cd /opt/scurve && python setup.py install

#llvm 3.8 -> fuzzer coverage cmp
#install llvm & clang & adress sanatiz & fuzzer
#configure proxy subversion
RUN mkdir /opt/llvm && cd /opt/llvm && svn co http://llvm.org/svn/llvm-project/llvm/trunk llvm && cd llvm/tools && svn co http://llvm.org/svn/llvm-project/cfe/trunk clang && cd ../.. && cd llvm/tools/clang/tools && svn co http://llvm.org/svn/llvm-project/clang-tools-extra/trunk extra && cd ../../../.. && cd llvm/projects && svn co http://llvm.org/svn/llvm-project/compiler-rt/trunk compiler-rt && cd ../.. && mkdir build
#add diff scan TAINT
ADD src/GenericTaintChecker.cpp /opt/llvm/llvm/tools/clang/lib/StaticAnalyzer/Checkers/GenericTaintChecker.cpp 
RUN cd /opt/llvm/build && cmake -G "Unix Makefiles" ../llvm
RUN cd /opt/llvm/build && make 

#llvm deux version 3.6 -> klee
#install llvm & clang & adress sanatiz & klee
RUN wget -nv http://llvm.org/releases/3.6.0/cfe-3.6.0.src.tar.xz -O /tmp/cfe.tgz; tar xf /tmp/cfe.tgz -C /tmp; \
  wget -nv http://llvm.org/releases/3.6.0/llvm-3.6.0.src.tar.xz -O /tmp/llvm.tgz; \
  tar xf /tmp/llvm.tgz -C /tmp; \
  wget -nv http://llvm.org/releases/3.6.0/compiler-rt-3.6.0.src.tar.xz -O /tmp/crt.tgz; \
  tar xf /tmp/crt.tgz -C /tmp; \
  wget -nv http://llvm.org/releases/3.6.0/clang-tools-extra-3.6.0.src.tar.xz -O /tmp/clangextra.tgz; \
  tar xf /tmp/clangextra.tgz -C /tmp; \
  rm /tmp/*.tgz; mkdir /opt/llvm-3.6; \
  mv /tmp/llvm-3.6.0.src /opt/llvm-3.6/llvm; \
  mv /tmp/cfe-3.6.0.src /opt/llvm-3.6/llvm/tools/clang; \
  mv /tmp/clang-tools-extra-3.6.0.src /opt/llvm-3.6/llvm/tools/clang/tools/extra; \
  mv /tmp/compiler-rt-3.6.0.src  /opt/llvm-3.6/llvm/projects/compiler-rt; \
  mkdir /opt/llvm-3.6/build
RUN cd /opt/llvm-3.6/build && ../llvm/configure --enable-optimized --enable-assertions 
#cmake -G "Unix Makefiles" ../llvm
RUN cd /opt/llvm-3.6/build && make
#GCC=gcc-4.6 LLVM_CONFIG=directory_where_llvm_installed/bin/llvm-config make

#stp install
RUN cd /opt && git clone https://github.com/stp/minisat.git
RUN cd /opt/minisat && mkdir build && cd build && cmake -DCMAKE_INSTALL_PREFIX=/usr/ ../
RUN cd /opt/minisat/build && make install
RUN cd /opt && git clone https://github.com/stp/stp.git
RUN cd /opt && mkdir stp/build && cd stp/build && cmake -DBUILD_SHARED_LIBS:BOOL=OFF -DENABLE_PYTHON_INTERFACE:BOOL=OFF ..
RUN cd /opt/stp/build && make
RUN cd /opt/stp/build && make install
RUN ulimit -s unlimited
# /etc/security/limits.conf

#uclibc
RUN cd /opt && git clone https://github.com/klee/klee-uclibc.git  
RUN cd /opt/klee-uclibc && ./configure --make-llvm-lib --with-llvm-config=/opt/llvm-3.6/build/Release+Asserts/bin/llvm-config
RUN cd /opt/klee-uclibc && make -j2  

#klee
#https://github.com/klee/klee/pull/238/files?diff=split
#https://github.com/ccadeptic23/klee.git
#RUN cd /opt && git clone https://github.com/klee/klee.git
RUN cd /opt && git clone https://github.com/ccadeptic23/klee.git
RUN cd /opt/klee && ./configure --with-llvmsrc=/opt/llvm-3.6/llvm --with-llvmobj=/opt/llvm-3.6/build/ --with-stp=/opt/stp/build --with-uclibc=/opt/klee-uclibc --enable-posix-runtime 
RUN cd /opt/klee && make
#--with-llvmsrc=/opt/llvm-3.6/llvm --with-llvmobj=/opt/llvm-3.6/build --with-llvm=/opt/llvm-3.6/llvm
# --with-llvmobj=/opt/llvm-3.6/build --with-llvmcc=/opt/llvm-3.6/build/bin/clang --with-llvmcxx=/opt/llvm-3.6/build/bin/clang++
#whole projet
RUN cd /opt/ && git clone https://github.com/travitch/whole-program-llvm.git
#CREATE ENV WLLVM
SET LLVM_COMPILER_PATH /opt/llvm-3.6/build/Release+Asserts/bin
#export LLVM_COMPILER=clang
#tar xf pkg-config-0.26.tar.gz
#cd pkg-config-0.26
#CC=wllvm ./configure
#make
# Produces pkg-config.bc
#extract-bc pkg-config
#OR
#tar -xvf bullet-2.81-rev2613.tgz
#mkdir bullet-bin
#cd bullet-bin
#CC=wllvm CXX=wllvm++ cmake ../bullet-2.81-rev2613/
#make
# Produces src/LinearMath/libLinearMath.bca
#extract-bc src/LinearMath/libLinearMath.a



#install pin & bap
ADD src/bap-0.8.tar.gz /opt/bap-0.8.tar.gz
RUN cd /opt/ && tar -zxf bap-0.8.tar.gz && mv bap-0.8 bap && rm bap-0.8.tar.gz
ADD src/gentrace.cpp /opt/bap/pintraces/gentrace.cpp
ADD src/pin_taint.cpp /opt/bap/pintraces/pin_taint.cpp
ADD src/pin_taint.h /opt/bap/pintraces/pin_taint.h
ADD src/getpin.sh /opt/bap/pintraces/getpin.sh
RUN cd /opt/bap/pintraces/ && bash getpin.sh
RUN cd /opt/bap/ && ./autogen.sh
#apt install automake libcamomile-ocaml-dev ocaml-native-compilers camlp4-extra camlidl binutils-dev libiberty-dev libpcre3-dev g++-multilib gcc-multilib libtool lib32z1-dev
RUN cd /opt/bap/ && ./configure 
#erreur de compilation mais continuer
RUN cd /opt/bap/libtracewrap/libtrace && make
#erreur de compilation mais continuer 
RUN cd /opt/bap/libtracewrap/libtrace32/ && make
RUN cd /opt/bap/pintraces && make

# apt-get build-dep PKG-NAME
# exit
#$ cd ~
#$ mkdir build
#$ cd build
#$ apt-get source irssi
#$ cd irssi-0.8.15/
#$ dch --local +shepherd201202191915
#$ export DEB_BUILD_HARDENING=1
#$ dpkg-buildpackage -rfakeroot -b

#docker rm $(docker ps -a -q) //clean contenaire





