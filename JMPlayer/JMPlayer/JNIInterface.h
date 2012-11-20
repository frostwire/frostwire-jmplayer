/*
 * Created by Erich Pleny (erichpleny)
 * Copyright (c) 2012, FrostWire(R). All rights reserved.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

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
    void OnIncrementVolumePressed();
    void OnDecrementVolumePressed();
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
    jmethodID volumeIncrementID;
    jmethodID volumeDecrementID;
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
