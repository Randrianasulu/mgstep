/*
   NSSound.h

   Sound file loading and OpenAL based playback

   Copyright (C) 2021 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    May 2021

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSSound
#define _mGSTEP_H_NSSound

#include <Foundation/Foundation.h>

@class NSData;
@class NSURL;

@protocol NSSoundDelegate;



@interface NSSound : NSObject  <NSCopying, NSCoding>
{
	NSString *_name;
	NSTimer *_loadTimer;
	NSTimeInterval _playTime;
	NSTimeInterval _currentTime;
	float _volume;
	id _data;
    id _delegate;
    id _reserved[7];

    struct __SoundFlags {
		unsigned int encodeByName:1;			// do not archive audio data
		unsigned int loops:1;
		unsigned int loaded:1;
		unsigned int reload:1;
		unsigned int paused:1;
		unsigned int notifyEnd:1;
		unsigned int empty:1;
		unsigned int reserved:1;
	} _f;
}

+ (id) soundNamed:(NSString *)name;

+ (NSArray *) soundUnfilteredTypes;

- (id) initWithData:(NSData *)data;
//- (id) initWithContentsOfURL:(NSURL *)url byReference:(BOOL)encodeByName;
- (id) initWithContentsOfFile:(NSString *)path byReference:(BOOL)encodeByName;

- (BOOL) setName:(NSString *)string;
- (NSString *) name;

- (BOOL) play;									// play sound asynchronously
- (BOOL) pause;
- (BOOL) resume;
- (BOOL) stop;
- (BOOL) isPlaying;

- (id <NSSoundDelegate>) delegate;
- (void) setDelegate:(id <NSSoundDelegate>)delegate;

- (NSTimeInterval) duration;
- (NSTimeInterval) currentTime;					// seconds into playback
- (void) setCurrentTime:(NSTimeInterval)seconds;

- (void) setVolume:(float)volume;
- (float) volume;

- (void) setLoops:(BOOL)val;
- (BOOL) loops;

@end


@protocol NSSoundDelegate  <NSObject>

- (void) sound:(NSSound *)sound didFinishPlaying:(BOOL)flag;

@end


@interface NSSound  (Private)

+ (void) _closeDevice;
- (void) _startLoopTimer;
- (void) _setPanLeft:(float)left Right:(float)right;

@end

#endif /* _mGSTEP_H_NSSound */
