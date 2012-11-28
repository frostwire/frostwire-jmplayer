VIDEO_DECODERS =['h263', 'h263i', 'h264', 'mpeg4', 'wmv1', 'wmv2', 'mpeg1video', 'mpeg2video', 'vp6','vp6a','vp6f','vp8', 'flv', 'svq1', 'svq3', 'xvid', 'x264']
AUDIO_DECODERS =['aac', 'mp3lame', 'mp3', 'ac3', 'flac', 'libfaac', 'adpcm_g726', 'vorbis', 'mp2', 'wmav1', 'wmav2', 'pcm_alaw','pcm_f32be','pcm_f32le', 'pcm_f64be', 'pcm_f64le', 'pcm_lxf', 'pcm_mulaw', 'pcm_s8', 'pcm_s8_planar', 'pcm_s16be', 'pcm_s16le', 'pcm_s16le_planar', 'pcm_s24be', 'pcm_s24daud', 'pcm_s24le', 'pcm_s32be', 'pcm_s32le', 'pcm_u8', 'pcm_u16be', 'pcm_u16le', 'pcm_u24be', 'pcm_u24le', 'pcm_u32be', 'pcm_u32le']

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
    
        #for d in [d for d in decoders if d not in VIDEO_DECODERS and d not in AUDIO_DECODERS]:
        #    msg = "" + d + " \\"
        #    print msg
        
        for d in [d for d in decoders if d in VIDEO_DECODERS or d in AUDIO_DECODERS]:
            msg = "    --enable-decoder=" + d + " \\"
            print msg

        for e in encoders:
            print "    --disable-encoder=" + e + " \\"

        missing_decoders = [item for item in VIDEO_DECODERS if item not in decoders]
        missing_decoders = missing_decoders + [item for item in AUDIO_DECODERS if item not in decoders]
        found_decoders = [item for item in VIDEO_DECODERS if item in decoders]
        found_decoders = found_decoders + [item for item in AUDIO_DECODERS if item in decoders]

		# TODO: make gen_decoders(verbose=False) get this parameter from sys.argv.
		# and uncomment this work if verbose == True.
        #print "  \n\n\n ************** \n  Missing decoders: \n **************\n"
        #for item in missing_decoders:
        #    print item

        #print "  \n\n\n ************** \n  Found decoders: \n **************\n"
        #for item in found_decoders:
        #    print item

if __name__=='__main__':
    gen_decoders()
