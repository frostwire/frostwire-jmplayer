#!/bin/bash

sudo apt update
sudo apt install -qq yasm
sudo apt install upx -y
sudo apt install -qq mingw-w64 mingw-w64-tools
sudo apt install libzstd-dev -y
sudo apt install libmad0-dev liba52-dev libvorbis-dev libmp3lame-dev -y
sudo apt install libavcodec-dev libavformat-dev libavutil-dev -y
sudo apt install libswscale-dev libswresample-dev libmad0-dev liba52-dev -y
sudo apt install libvorbis-dev libmp3lame-dev libxml2-dev -y

# it will build but it wont make a sound without this
sudo apt install libsdl1.2-dev -y

