//
//  OwnerWrapper.m
//  JMPlayer
//
//  Created by Alden Torres on 1/23/13.
//
//

#import "OwnerWrapper.h"

JavaVM* jvm = NULL;

jint GetJNIEnv(JNIEnv **env, bool *mustDetach);

@implementation OwnerWrapper

-(id) initWithOwner:(JNIEnv*) env theOwner: (jobject) theOwner;
{
    if (self = [super init])
    {
        owner = (*env)->NewGlobalRef(env, theOwner);
        [self initMethodIDs:env];
    }
    
    return self;
}

-(void) OnVolumeChanged:(float) volume
{
    [self invokeJavaMethodFloat:changeVolumeID param:volume];
}

-(void) OnIncrementVolumePressed
{
    [self invokeJavaMethod:volumeIncrementID];
}

-(void) OnDecrementVolumePressed
{
    [self invokeJavaMethod:volumeDecrementID];
}

-(void) OnSeekToTime:(float) seconds
{
    [self invokeJavaMethodFloat:seekToTimeID param:seconds];
}

-(void) OnPlayPressed
{
    [self invokeJavaMethod:playPressedID];
}

-(void) OnPausePressed
{
    [self invokeJavaMethod:pausePressedID];
}

-(void) OnFastForwardPressed
{
    [self invokeJavaMethod:fastForwardPressedID];
}

-(void) OnRewindPressed
{
    [self invokeJavaMethod:rewindPressedID];
}

-(void) OnToggleFullscreenPressed
{
    [self invokeJavaMethod:toggleFullscreenPressedID];
}

-(void) OnProgressSliderStarted
{
    [self invokeJavaMethod:progressSliderStartedID];
}

-(void) OnProgressSliderEnded
{
    [self invokeJavaMethod:progressSliderEndedID];
}

-(void) OnMouseMoved
{
    [self invokeJavaMethod:mouseMovedID];
}

-(void) OnMouseDoubleClick
{
    [self invokeJavaMethod:mouseDoubleClickID];
}

-(void) initMethodIDs: (JNIEnv*) env;
{
    // initialize the class object & method ids
    cls = (*env)->GetObjectClass(env, owner);
    
    if (cls == 0)
    {
        printf("ERROR: unable to locate class MPlayerJNIHandler");
    }
    
    changeVolumeID = (*env)->GetMethodID(env, cls, "onVolumeChanged", "(F)V");
    if (changeVolumeID == 0)
    {
        printf("ERROR: JNIInterface::Initialize() unable to get method id for onVolumeChanged");
    }
    
    volumeIncrementID = (*env)->GetMethodID(env, cls, "onIncrementVolumePressed", "()V");
    if (volumeIncrementID == 0)
    {
        printf("ERROR: JNIInterface::Initialize() unable to get method id for onIncrementVolumePressed");
    }
    
    volumeDecrementID = (*env)->GetMethodID(env, cls, "onDecrementVolumePressed", "()V");
    if (volumeDecrementID == 0)
    {
        printf("ERROR: JNIInterface::Initialize() unable to get method id for onDecrementVolumePressed");
    }
    
    seekToTimeID = (*env)->GetMethodID(env, cls, "onSeekToTime", "(F)V");
    if (seekToTimeID == 0)
    {
        printf("ERROR: JNIInterface::Initialize() unable to get method id for onSeekToTime");
    }
    
    playPressedID = (*env)->GetMethodID(env, cls, "onPlayPressed", "()V");
    if (playPressedID == 0)
    {
        printf("ERROR: JNIInterface::Initialize() unable to get method id for onPlayPressed");
    }
    
    pausePressedID = (*env)->GetMethodID(env, cls, "onPausePressed", "()V");
    if (pausePressedID == 0)
    {
        printf("ERROR: JNIInterface::Initialize() unable to get method id for onPausePressed");
    }
    
    fastForwardPressedID = (*env)->GetMethodID(env, cls, "onFastForwardPressed", "()V");
    if (fastForwardPressedID == 0)
    {
        printf("ERROR: JNIInterface::Initialize() unable to get method id for onFastForwardPressed");
    }
    
    rewindPressedID = (*env)->GetMethodID(env, cls, "onRewindPressed", "()V");
    if (rewindPressedID == 0)
    {
        printf("ERROR: JNIInterface::Initialize() unable to get method id for onRewindPressed");
    }
    
    toggleFullscreenPressedID = (*env)->GetMethodID(env, cls, "onToggleFullscreenPressed", "()V");
    if (toggleFullscreenPressedID == 0)
    {
        printf("ERROR: JNIInterface::Initialize() unable to get method id for onToggleFullscreenPressed");
    }
    
    progressSliderStartedID = (*env)->GetMethodID(env, cls, "onProgressSliderStarted", "()V");
    if (progressSliderStartedID == 0)
    {
        printf("ERROR: JNIInterface::Initialize() unable to get method id for onProgressSliderStarted");
    }
    
    progressSliderEndedID = (*env)->GetMethodID(env, cls, "onProgressSliderEnded", "()V");
    if (progressSliderEndedID == 0)
    {
        printf("ERROR: JNIInterface::Initialize() unable to get method id for onProgressSliderEnded");
    }
    
    mouseMovedID = (*env)->GetMethodID(env, cls, "onMouseMoved", "()V");
    if (mouseMovedID == 0)
    {
        printf("ERROR: JNIInterface::Initialize() unable to get method id for onMouseMoved");
    }
    
    mouseDoubleClickID = (*env)->GetMethodID(env, cls, "onMouseDoubleClick", "()V");
    if (mouseMovedID == 0)
    {
        printf("ERROR: JNIInterface::Initialize() unable to get method id for onMouseDoubleClick");
    }
}

-(void) invokeJavaMethodFloat: (jmethodID) mID param: (float) f
{
    if (mID != 0)
    {
        JNIEnv *env = NULL;
        bool shouldDetach = false;
        
        if (GetJNIEnv(&env, &shouldDetach) != 0) {
            NSLog(@"ERROR: unable to get JNIEnv");
        }
        
        if (env != NULL) {
            (*env)->CallVoidMethod(env, owner, mID, f);
        }
        
        if (shouldDetach) {
            (*jvm)->DetachCurrentThread(jvm);
        }
    }
}

-(void) invokeJavaMethod: (jmethodID) mID
{
    if (mID != 0)
    {
        JNIEnv *env = NULL;
        bool shouldDetach = false;
        
        if (GetJNIEnv(&env, &shouldDetach) != 0) {
            NSLog(@"ERROR: unable to get JNIEnv");
        }
        
        if (env != NULL) {
            (*env)->CallVoidMethod(env, owner, mID);
        }
        
        if (shouldDetach) {
            (*jvm)->DetachCurrentThread(jvm);
        }
    }
}

@end

JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM *vm, void *reserved)
{
    jvm = vm;
    return JNI_VERSION_1_6;
}

JNIEXPORT void JNICALL JNI_OnUnload(JavaVM *vm, void *reserved)
{
}

jint GetJNIEnv(JNIEnv **env, bool *mustDetach)
{
	jint getEnvErr = JNI_OK;
	*mustDetach = false;
	if (jvm)
    {
		getEnvErr = (*jvm)->GetEnv(jvm, (void **)env, JNI_VERSION_1_4);
		if (getEnvErr == JNI_EDETACHED)
        {
			getEnvErr = (*jvm)->AttachCurrentThread(jvm, (void **)env, NULL);
			if (getEnvErr == JNI_OK)
            {
				*mustDetach = true;
			}
		}
	}
	return getEnvErr;
}

int IntegerValue(JNIEnv*env, jobject integerObject) {
    
    jclass cls = (*env)->FindClass(env, "java/lang/Integer");
    
    if(cls == NULL){
        return 0;
    }
    
    jmethodID getVal = (*env)->GetMethodID(env, cls, "intValue", "()I");
    if(getVal == NULL){
        return 0;
    }
    
    int i = (*env)->CallIntMethod(env, integerObject, getVal);
    return i;
}

float FloatValue(JNIEnv*env, jobject floatObject) {
    
    jclass cls = (*env)->FindClass(env, "java/lang/Float");
    
    if(cls == NULL){
        return 0;
    }
    
    jmethodID getVal = (*env)->GetMethodID(env, cls, "floatValue", "()F");
    if(getVal == NULL){
        return 0;
    }
    
    float f = (*env)->CallFloatMethod(env, floatObject, getVal);
    return f;
}
