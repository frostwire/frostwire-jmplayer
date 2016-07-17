#! /bin/bash
#
# The following ./configure flags should be the product of:
# 1. ./configure
# 2 all the codecs disabled past --disable-win32dll
# will come out of THEN executing 'python gen_decoders.py'
#
# It's important to execute the python script only after
# you've invoked ./configure one time, otherwise the gen_decoders.py
# will not have the right .h to parse.
#
# MAC NOTES:
# - To enable upx --ultra-brute, run: brew install upx +lzma
#
# WIN32 NOTES:
# - Use mingw, not cygwin. It seems the cygwin gcc compiler will add a cygwin1.dll dependency.
# - We've included yasm.exe in this folder, mingw does not install yasm.exe
# (See http://yasm.tortall.net/Download.html)
# - DO NOT FORGET TO SIGN THE EXECUTABLE
# signtool sign /a /n "FrostWire" /t http://timestamp.verisign.com/scripts/timstamp.dll /v c:\cygwin\home\username\frostwire-desktop\lib\native\fwplayer.exe
#

export MACOSX_DEPLOYMENT_TARGET=10.6
#make final executable smaller and copy it to the frostwire-desktop/lib/native/ folder.
isWINDOWS=`uname -a | awk '{print index($0,"MINGW32")}'`

CONFIGURE_BASE_FILE=configure.base.osx
if [ $isWINDOWS == 1]
then
   CONFIGURE_BASE_FILE=configure.base.win
fi
echo using configure base file $CONFIGURE_BASE_FILE

#clean up
function cleanConfigure() {
  make clean
  rm configure.out
  # we run configure the first time to generate the config.h file that gen_decoders.py needs.
  ./configure
}

#generate the full blown configure file.
#configure.base has the base compilation flags without the decoders.
function realConfigure() {
  python gen_decoders.py > configure.codec_flags
  cat $CONFIGURE_BASE_FILE configure.codec_flags > configure.out
  rm configure.codec_flags
  chmod +x configure.out
  ./configure.out
}


function makeIt() {
  OLDPATH=$PATH
  #add yasm.exe to the path...
  PATH=$PATH:`pwd`
  make
  PATH=$OLDPATH
}

cleanConfigure
realConfigure
checkUPX
makeIt
