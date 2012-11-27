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
# WIN32 NOTES:
# - Use mingw, not cygwin. It seems the cygwin gcc compiler will add a cygwin1.dll dependency.
# - We've included yasm.exe in this folder, mingw does not install yasm.exe
# (See http://yasm.tortall.net/Download.html)
#

#clean up and create base configuration
function cleanConfigure() {
make clean
./configure
}

#generate the full blown configure file.
#configure.base has the base compilation flags without the decoders.
function realConfigure() {
python gen_decoders.py > configure.codec_flags
cat configure.base configure.codec_flags > configure.out
rm configure.codec_flags
chmod +x configure.out
./configure.out
}

#check if UPX is installed, if not abort.
function checkUPX() {
command -v upx >/dev/null 2>&1 || { echo >&2 "I require upx but it's not installed.  Aborting."; exit 1; }
}

#go!
function makeAll() {
OLDPATH=$PATH
#add yasm.exe to the path...
PATH=$PATH:`pwd`
make
PATH=$OLDPATH

#make final executable smaller and copy it to the frostwire-desktop/lib/native/ folder.
isWINDOWS=`echo $C | awk '{print index($0,"MINGW32")}'`

MPLAYER_EXECUTABLE=mplayer
FWPLAYER_EXECUTABLE=fwplayer_osx

if [ $isWINDOWS == 1 ]
then
  MPLAYER_EXECUTABLE=mplayer.exe
  FWPLAYER_EXECUTABLE=fwplayer.exe
fi

echo Before Stripping
ls -lh $MPLAYER_EXECUTABLE
strip $MPLAYER_EXECUTABLE
echo After Stripping, Before UPX
ls -lh $MPLAYER_EXECUTABLE
cp $MPLAYER_EXECUTABLE $MPLAYER_EXECUTABLE.uncompressed

#if your upx has not been compiled with LZMA the "--ultra-brute" flag will not work.
#upx $MPLAYER_EXECUTABLE
upx --ultra-brute $MPLAYER_EXECUTABLE

echo After UPX
ls -lh $MPLAYER_EXECUTABLE

cp $MPLAYER_EXECUTABLE ../../frostwire-desktop/lib/native/$FWPLAYER_EXECUTABLE
}

#cleanConfigure
#realConfigure
#checkUPX
makeAll