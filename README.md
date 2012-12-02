frostwire-jmplayer
==================

The frostwire-jmplayer project (JMPlayer) contains the sources for the <a href="https://github.com/frostwire/frostwire-desktop">frostwire</a> media player.

<a href="https://github.com/frostwire/frostwire-jmplayer/tree/master/MPlayer-OSX-Extended">MPlayer-OSX-Extended</a> is the original source that the JMPlayer is based on. it is a library that provides a gui wrapper on top of the MPlayer video-playback process.

<a href="https://github.com/frostwire/frostwire-jmplayer/tree/master/JMPlayer-Bundle">JMPlayer-Bundle</a> is the mac osx resource bundle containing the images resources for the fullscreen overlay controll popup.

<a href="https://github.com/frostwire/frostwire-jmplayer/tree/master/JMPlayer">JMPlayer</a> is the native library used on mac osx platforms to interface between the java frostwire player and the native mplayer process. it is the library which reads the video buffer produced by the mplayer process and renders it to a NSView on the screen as well as shows an overlay control dialog in fullscreen view.

<a href="https://github.com/frostwire/frostwire-jmplayer/tree/master/MPlayer-1.1">MPlayer-1.1</a> is the original mplayer 1.1 executable source.  our version of it compiles to not use the dependency for libiconv. the build script BUILD compiles the project and copies the mplayer result to fwplayer_osx (for mac) or fwplayer.exe (for Win32) located in frostwire-desktop/lib/native folder.

