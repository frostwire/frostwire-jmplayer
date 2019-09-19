#!/bin/bash

sudo apt-get update
sudo apt-get install -qq yasm
sudo apt-get install upx
sudo apt-get install -qq mingw-w64

#sudo rm /usr/i686-w64-mingw32/lib/libwinpthread.dll.a
#sudo rm /usr/i686-w64-mingw32/lib/libwinpthread-1.dll
#sudo rm /usr/x86_64-w64-mingw32/lib/libwinpthread.dll.a
#sudo rm /usr/x86_64-w64-mingw32/lib/libwinpthread-1.dll
