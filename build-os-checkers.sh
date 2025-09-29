gcc is_linux.c -o is_linux
gcc is_macos.c -o is_macos
gcc -std=c11 -D_POSIX_C_SOURCE=200809L prepare-ffmpeg-flags.c -o prepare-ffmpeg-flags
