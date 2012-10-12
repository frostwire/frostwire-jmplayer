//
//  JNIInterface.cpp
//  JMPlayer
//
//  Created by Erich Pleny on 10/12/12.
//
//

#include "JNIInterface.h"

jint GetJNIEnv(JavaVM* jvm, JNIEnv **env, bool *mustDetach);


JNIInterface::JNIInterface()
{
    jvm = NULL;
    env = NULL;
    initialized = false;
}

JNIInterface::~JNIInterface()
{
    if ( jvm && env && mustDetach )
    {
        jvm->DetachCurrentThread();
    }

}

JNIInterface& JNIInterface::GetInstance()
{
    static JNIInterface INSTANCE;
    return INSTANCE;
}


bool JNIInterface::Initialize(JavaVM* jvm)
{
    if ( initialized )
    {
        return true;
    }
    
    this->jvm = jvm;

    if ( JNI_OK == GetJNIEnv(jvm, &env, &mustDetach))
    {
        // initialize the class object & method ids
        cls = env->FindClass("MPlayerJNIHandler");
        
        if (cls == 0)
        {
            printf("ERROR: unable to locate class MPlayerJNIHandler");
            return false;
        }
        
        changeVolumeID = env->GetStaticMethodID(cls, "onVolumeChanged", "(F)V");
        if(changeVolumeID == 0 )
        {
            printf("ERROR: JNIInterface::Initialize() unable to get method id for onVolumeChanged");
            return false;
        }
        
        seekToTimeID = env->GetStaticMethodID(cls, "onSeekToTime", "(F)V");
        if(seekToTimeID == 0 )
        {
            printf("ERROR: JNIInterface::Initialize() unable to get method id for onSeekToTime");
            return false;
        }
        
        playPressedID = env->GetStaticMethodID(cls, "onPlayPressed", "()V");
        if(playPressedID == 0 )
        {
            printf("ERROR: JNIInterface::Initialize() unable to get method id for onPlayPressed");
            return false;
        }
        
        pausePressedID = env->GetStaticMethodID(cls, "onPausePressed", "()V");
        if(pausePressedID == 0 )
        {
            printf("ERROR: JNIInterface::Initialize() unable to get method id for onPausePressed");
            return false;
        }
        
        fastForwardPressedID = env->GetStaticMethodID(cls, "onFastForwardPressed", "()V");
        if(fastForwardPressedID == 0 )
        {
            printf("ERROR: JNIInterface::Initialize() unable to get method id for onFastForwardPressed");
            return false;
        }
        
        rewindPressedID = env->GetStaticMethodID(cls, "onRewindPressed", "()V");
        if(rewindPressedID == 0 )
        {
            printf("ERROR: JNIInterface::Initialize() unable to get method id for onRewindPressed");
            return false;
        }
        
        initialized = true;
        return true;
    }
    else
    {
        return false;
    }
    
}

void JNIInterface::OnVolumeChanged(float volume)
{
    //                fprintf(stdout, "This is invokeSimplified6.\n");
    //env->CallStaticVoidMethod(cls, get_main_id, args);

}

void JNIInterface::OnSeekToTime(float seconds)
{
    
}

void JNIInterface::OnPlayPressed()
{
    
}

void JNIInterface::OnPausePressed()
{
    
}

void JNIInterface::OnFastForwardPressed()
{
    
}

void JNIInterface::OnRewindPressed()
{
    
}


jint GetJNIEnv(JavaVM* jvm, JNIEnv **env, bool *mustDetach) {
    jint getEnvErr = JNI_OK;
    *mustDetach = false;
    if (jvm) {
        getEnvErr = jvm->GetEnv((void **)env, JNI_VERSION_1_4);
        if (getEnvErr == JNI_EDETACHED) {
            getEnvErr = jvm->AttachCurrentThread((void **)env, NULL);
            if (getEnvErr == JNI_OK) {
                *mustDetach = true;
            }
        }
    }
    return getEnvErr;
}
