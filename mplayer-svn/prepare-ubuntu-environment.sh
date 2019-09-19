#!/bin/bash

sudo apt update
sudo apt install -qq yasm
sudo apt install upx
sudo apt install -qq mingw-w64
sudo apt install golang

#sudo rm /usr/i686-w64-mingw32/lib/libwinpthread.dll.a
#sudo rm /usr/i686-w64-mingw32/lib/libwinpthread-1.dll
#sudo rm /usr/x86_64-w64-mingw32/lib/libwinpthread.dll.a
#sudo rm /usr/x86_64-w64-mingw32/lib/libwinpthread-1.dll
