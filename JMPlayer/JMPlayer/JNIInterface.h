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
    
    bool Initialize(JNIEnv *env, jobject component);
    
    int getJNIIntValue(jobject integerObject);
    float getJNIFloatValue(jobject floatObject);
    
    // JNI callback methods    
    void OnVolumeChanged(float volume);
    void OnSeekToTime(float seconds);
    void OnPlayPressed();
    void OnPausePressed();
    void OnFastForwardPressed();
    void OnRewindPressed();
    void OnToggleFullscreenPressed();
    void OnProgressSliderStarted();
    void OnProgressSliderEnded();
    
private:
    JNIInterface();
    JNIInterface(JNIInterface const&);   // do not implement
    void operator=(JNIInterface const&); // do not implement
    
    bool initialized;
    
    JNIEnv* env;
    bool mustDetach;
    
    jobject owner;
    jclass  cls;
    jmethodID changeVolumeID;
    jmethodID seekToTimeID;
    jmethodID playPressedID;
    jmethodID pausePressedID;
    jmethodID fastForwardPressedID;
    jmethodID rewindPressedID;
    jmethodID toggleFullscreenPressedID;
    jmethodID progressSliderStartedID;
    jmethodID progressSliderEndedID;
};

#endif /* defined(__JMPlayer__JNIInterface__) */
