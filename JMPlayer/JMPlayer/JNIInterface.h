//
//  JNIInterface.h
//  JMPlayer
//
//  Created by Erich Pleny on 10/12/12.
//
//

#ifndef __JMPlayer__JNIInterface__
#define __JMPlayer__JNIInterface__

#include <JavaVM/jni.h>

class JNIInterface
{

public:
    
    ~JNIInterface();
    static JNIInterface& GetInstance();
    bool Initialize(JavaVM* jvm);
    
    // JNI callback methods    
    void OnVolumeChanged(float volume);
    void OnSeekToTime(float seconds);
    void OnPlayPressed();
    void OnPausePressed();
    void OnFastForwardPressed();
    void OnRewindPressed();
    
private:
    JNIInterface();
    JNIInterface(JNIInterface const&);   // do not implement
    void operator=(JNIInterface const&); // do not implement
    
    bool initialized;
    
    JavaVM* jvm;
    JNIEnv* env;
    bool mustDetach;
    
    jclass cls;
    jmethodID changeVolumeID;
    jmethodID seekToTimeID;
    jmethodID playPressedID;
    jmethodID pausePressedID;
    jmethodID fastForwardPressedID;
    jmethodID rewindPressedID;
};

#endif /* defined(__JMPlayer__JNIInterface__) */
