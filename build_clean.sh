#!/bin/bash
# Clean build from scratch

cd mplayer-trunk/ffmpeg
./configure --target-os=linux --enable-nonfree --enable-openssl --disable-doc --disable-programs --disable-bsfs --disable-muxers --disable-demuxers --disable-devices --disable-filters --disable-iconv --disable-alsa --disable-openal --disable-lzma --disable-decoder=dirac --disable-decoder=snow --disable-demuxer=mcc --disable-muxer=mcc --disable-decoder=amrnb --disable-decoder=amrwb --disable-decoder=g723_1 --enable-protocol=file --enable-protocol=pipe --enable-protocol=tcp --enable-protocol=udp --enable-protocol=tls --enable-protocol=rtmp --enable-protocol=rtmps --enable-protocol=http --enable-protocol=https --enable-protocol=httpproxy --enable-protocol=icecast --enable-protocol=hls --extra-cflags="-Os" 2>&1 | tail -30
echo ""
echo "Building FFmpeg..."
make -j 8 2>&1 | tail -20
cd ../..
echo ""
echo "Cleaning problematic files..."
./mplayer-trunk/post_ffmpeg_build.sh
cd mplayer-trunk
echo ""
echo "Building mplayer..."
make -j 8 2>&1 | tail -50
cd ..
