VIDEO_DECODERS =['h263', 'h263i', 'h264', 'mpeg4', 'wmv1', 'wmv2', 'mpeg1video', 'mpeg2video', 'vp6','vp6a','vp6f','vp8', 'flv', 'svq1', 'svq3', 'xvid', 'x264']
AUDIO_DECODERS =['aac', 'mp3lame', 'mp3', 'ac3', 'flac', 'libfaac', 'adpcm_g726', 'vorbis', 'mp2', 'wmav1', 'wmav2']

def gen_decoders():
    with open("config.h") as f:
        content = f.readlines()

        decoders =[];
        encoders =[];

        for line in content:
            if ("#define CONFIG_" in line) and ("_DECODER" in line) and len(line[15:line.find("_DECODER")]) > 0:
                decoders.append( line[15:line.find("_DECODER")].lower() );
            if ("#define CONFIG_" in line) and ("_ENCODER" in line) and len(line[15:line.find("_ENCODER")]) > 0:
                encoders.append( line[15:line.find("_ENCODER")].lower() );
    
        for d in [d for d in decoders if d not in VIDEO_DECODERS and d not in AUDIO_DECODERS]:
            msg = "    --disable-decoder=" + d + " \\"
            print msg
        
        for d in [d for d in decoders if d in VIDEO_DECODERS or d in AUDIO_DECODERS]:
            msg = "    --enable-decoder=" + d + " \\"
            print msg

        for e in encoders:
            print "    --disable-encoder=" + e + " \\"

        missing_decoders = [item for item in VIDEO_DECODERS if item not in decoders]
        missing_decoders = missing_decoders + [item for item in AUDIO_DECODERS if item not in decoders]
        found_decoders = [item for item in VIDEO_DECODERS if item in decoders]
        found_decoders = found_decoders + [item for item in AUDIO_DECODERS if item in decoders]

        print "  \n\n\n ************** \n  Missing decoders: \n **************\n"
        for item in missing_decoders:
            print item

        print "  \n\n\n ************** \n  Found decoders: \n **************\n"
        for item in found_decoders:
            print item

if __name__=='__main__':
    gen_decoders()
