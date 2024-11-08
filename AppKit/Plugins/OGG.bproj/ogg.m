/*
   ogg.m

   Ogg/Vorbis sound loading and playback

   Copyright (C) 2021 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    May 2021

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <AppKit/AppKit.h>

#include <AL/al.h>
#include <AL/alc.h>

#define OV_EXCLUDE_STATIC_CALLBACKS  1

#include <vorbis/codec.h>
#include <vorbis/vorbisfile.h>


#define OPENAL_BUFFERS  16


static NSArray *__filesSND = nil;



typedef struct
{
	size_t length;
	size_t position;
	const ALvoid *data;

} InputStream;


static size_t
ogg_read(void *ptr, size_t size, size_t nmemb, InputStream *s)
{
	size_t numBytesToRead = size * nmemb;

	if (s->position + numBytesToRead > s->length)
		{
		if (s->position < s->length)
			numBytesToRead = s->length - s->position;
		else
			numBytesToRead = 0;
		}

	if (numBytesToRead)
		{
		memcpy(ptr, s->data + s->position, numBytesToRead);
		s->position += numBytesToRead;
		}

	return numBytesToRead;
}

static size_t
ogg_seek(InputStream *s, ogg_int64_t offset, int whence)
{
	switch (whence)
		{
		case SEEK_SET:  s->position = offset;  break;
		case SEEK_CUR:  s->position += offset; break;
		case SEEK_END:  s->position = s->length + offset;  break;
		default:		return -1;
		}

	return (s->position < s->length) ? 0 : -1;
}

static size_t
ogg_tell(InputStream *s)
{
	return s->position;
}

static ov_callbacks OV_CALLBACKS = {
	(size_t (*)(void *, size_t, size_t, void *))  ogg_read,
	(int (*)(void *, ogg_int64_t, int))           ogg_seek,
	(int (*)(void *))                             NULL,
	(long (*)(void *))                            ogg_tell
};

/* ****************************************************************************

		_NSSoundOgg

** ***************************************************************************/

@interface _NSSoundOgg : NSSound
{
	ALuint source;
	ALuint _buffers[OPENAL_BUFFERS];
	ALCenum _error;
	ALenum _format;
	OggVorbis_File vf;
	vorbis_info *vi;
	InputStream stream;
	char _pcm[OPENAL_BUFFERS*1024];
}
@end

@implementation _NSSoundOgg

+ (void) initialize
{
	if (!__filesSND)
		__filesSND = [[NSArray arrayWithObjects:@"ogg", nil] retain];
}

+ (id) alloc								{ return NSAllocateObject(self); }
+ (NSArray *) soundUnfilteredTypes			{ return __filesSND; }

+ (BOOL) canInitWithData:(NSData *)data
{
	unsigned char sig[] = {'O','g','g','S'};

	return _CGImageCanInitWith( (CFDataRef)data, sig, sizeof(sig) );
}

- (id) initWithData:(NSData *)d
{
	if (!(_data = [d retain]))
		return _NSInitError(self, @"init with nil data");

	stream.data = [_data bytes];
	stream.length = [_data length];

	if (ov_open_callbacks(&stream, &vf, NULL, stream.length, OV_CALLBACKS) < 0)
		return _NSInitError(self, @"sound is not an ogg bitstream");

	vi = ov_info(&vf, -1);
	_format = (vi->channels == 1) ? AL_FORMAT_MONO16 : AL_FORMAT_STEREO16;

	return self;
}

- (void) dealloc
{
	if (_f.loaded)
		{
		alDeleteSources(1, &source);
		alDeleteBuffers(OPENAL_BUFFERS, _buffers);
		}
	if (vi != NULL)
		ov_clear(&vf),		vi = NULL;
	[super dealloc];
}

- (NSTimeInterval) duration					{ return ov_time_total(&vf, -1); }

- (NSString *) description
{										// secs = vf->pcmlengths[1] / vi->rate
	return [NSString stringWithFormat:
				@"NSSound: %@ - %u ch, %u bits, %d Hz, %u Bytes (%u secs)",
				_name,  (vi) ? vi->channels : 0, 16,
				(vi) ? (int)vi->rate : 0, [_data length], (int)[self duration]];
}

- (void) _soundFinishedPlaying
{
	if (_f.paused || _f.loops)
		return;

	_currentTime = [NSDate timeIntervalSinceReferenceDate] - _playTime;
	if (([self duration] > _currentTime))
		return;

	if ((_error = alGetError()) != AL_NO_ERROR)
		NSLog(@"ERROR: OpenAL failed to play sound (%d)", _error);

	if (_f.notifyEnd)
		[_delegate sound:self didFinishPlaying:(_error == AL_NO_ERROR)];
	_currentTime = 0;
}

- (BOOL) _loadBuffers:(id)sender
{
	ALint i, count = OPENAL_BUFFERS;
	ALuint buf[count];
	ALuint *buffers = (_f.loaded) ? buf : _buffers;
	int eos = 0;
	int cs;										// current ogg section

	if (!_f.loaded)
		{
		_f.loaded = YES;
		alGenBuffers(count, buffers);			// generate buffers
		}
	else
		{										// reload consumed buffers
		alGetSourcei(source, AL_BUFFERS_PROCESSED, &count);
		alSourceUnqueueBuffers(source, count, buffers);
		}

	for (i = 0; i < count; ++i)					// load buffers
		{
		long pos = 0;

		while (pos < sizeof(_pcm))				// load data into pcm buffer
			{
			long r = ov_read(&vf, _pcm + pos, sizeof(_pcm) - pos, 0, 2, 1, &cs);

			if (r == 0)
				{
				eos = 1;
				break;
				}
			pos += r;
			}

		alBufferData(buffers[i], _format, _pcm, pos, vi->rate);
		}
	alSourceQueueBuffers(source, count, buffers);

	if (eos)
		{
		if (_f.loops)
			ov_time_seek(&vf, 0);
		else
			[_loadTimer invalidate],  _loadTimer = nil;
		}

	if (_f.loops && count && _f.empty)				// short audio in a loop
		alSourcePlay(source);						// restart audio playback
	_f.empty = (count == 0);						// detect buffer underrun

	if ((eos && !_loadTimer))
		[self performSelector:@selector(_soundFinishedPlaying)
			  withObject: self
			  afterDelay: [self duration] - [self currentTime]];

	return (eos == NO);
}

- (BOOL) play
{
	if (!_f.loaded)
		alGenSources (1, &source);

	ov_time_seek(&vf, _currentTime);

	_f.paused = NO;
	_f.reload = [self _loadBuffers: nil];

	alSourcePlay(source);						// play audio

	if (_currentTime)
		_playTime = [NSDate timeIntervalSinceReferenceDate] - _currentTime;
	else
		_playTime = [NSDate timeIntervalSinceReferenceDate];

	if ((_error = alGetError()) != AL_NO_ERROR)
		NSLog(@"ERROR: OpenAL failed to play sound (%d)", _error);

	if (_f.reload || _f.loops)
		[self _startLoopTimer];

	return (_error == AL_NO_ERROR);
}

- (BOOL) resume
{
	_f.paused = NO;
	alSourcePlay(source);
	_playTime = [NSDate timeIntervalSinceReferenceDate] - _currentTime;

	if ((_error = alGetError()) != AL_NO_ERROR)
		NSLog(@"ERROR: OpenAL failed to resume sound (%d)", _error);

	[self _loadBuffers: self];

	return (_error == AL_NO_ERROR);
}

- (BOOL) pause
{
	_f.paused = YES;
	alSourcePause(source);
	_currentTime = [NSDate timeIntervalSinceReferenceDate] - _playTime;

	if ((_error = alGetError()) != AL_NO_ERROR)
		NSLog(@"ERROR: OpenAL failed to pause sound (%d)", _error);

	return (_error == AL_NO_ERROR);
}

- (BOOL) stop
{
	[_loadTimer invalidate],  _loadTimer = nil,  _currentTime = 0;
	alSourceStop(source);

	if ((_error = alGetError()) != AL_NO_ERROR)
		NSLog(@"ERROR: OpenAL failed to stop sound (%d)", _error);

	return (_error == AL_NO_ERROR);
}

- (BOOL) isPlaying
{
	ALsizei source_state = 0;

	if (_f.loaded)
		alGetSourcei(source, AL_SOURCE_STATE, &source_state);

	return (source_state == AL_PLAYING);
}

- (void) setVolume:(float)volume
{
	_volume = MAX(0, MIN(1, volume));
	alSourcef(source, AL_GAIN, _volume);
}

- (void) _setPanLeft:(float)left Right:(float)right
{
	float pan = (acosf(left) + asinf(right)) / ((float)M_PI);

	pan = 2 * pan - 1;		// convert to [-1, 1]
	pan *= 0.5f;			// 0.5 = sin(30') is a +/- 30 degree arc
	alSourcei(source, AL_SOURCE_RELATIVE, 1);
	alSource3f(source, AL_POSITION, pan, 0, -sqrtf(1.0f - pan*pan));

	if ((_error = alGetError()) != AL_NO_ERROR)
		NSLog(@"ERROR: OpenAL _setPanningLeft:Right: failed (%x)", _error);
}

@end /* _NSSoundOgg */
