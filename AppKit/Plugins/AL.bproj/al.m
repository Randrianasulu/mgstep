/*
   al.m

   OpenAL sound playback

   Copyright (C) 2021 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    May 2021

   ==========================================================================
   WAV/SND/AU parsing derived from freealut-1.0.0 (LGPL version 2)
   Copyright (C) 1994-2005 Free Software Foundation, Inc.
   Author: Steve Baker <sjbaker1@airmail.net>
   Author: Sven Panne <sven.panne@aedion.de>
   ==========================================================================

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <AppKit/AppKit.h>

#include <AL/al.h>
#include <AL/alc.h>


#define AU_HEADER_SIZE  24
#define OPENAL_BUFFERS  16


static NSArray *__filesSND = nil;

static ALCdevice  *__alDevice = NULL;
static ALCcontext *__alContext = NULL;



enum AUEncoding
{
	AU_ULAW_8   = 1,                // 8-bit ISDN u-law
	AU_PCM_8    = 2,                // 8-bit linear PCM (signed)
	AU_PCM_16   = 3,                // 16-bit linear PCM (signed, big-endian)
	AU_PCM_24   = 4,                // 24-bit linear PCM
	AU_PCM_32   = 5,                // 32-bit linear PCM
	AU_FLOAT_32 = 6,              	// 32-bit IEEE floating point
	AU_FLOAT_64 = 7,              	// 64-bit IEEE floating point
	AU_ALAW_8   = 27                // 8-bit ISDN a-law
};

typedef enum
{
	ALUT_ERROR_NO_ERROR                  = 0,
	ALUT_ERROR_OUT_OF_MEMORY             = 0x200,
	ALUT_ERROR_UNSUPPORTED_FILE_SUBTYPE  = 0x210,
	ALUT_ERROR_CORRUPT_OR_TRUNCATED_DATA = 0x211,
	ALUT_ERROR_CORRUPT_HEADER_DATA       = 0x212

} _NSSoundDecodeError;

typedef uint16_t UInt16LE;
typedef uint32_t UInt32LE;
typedef int32_t  Int32BE;

typedef struct
{
	const ALvoid *data;
	ALvoid *pcm;
	size_t length;
	ALenum format;
	ALint numChannels;
	ALint bitsPerSample;
	ALfloat sampleFrequency;
	_NSSoundDecodeError error;

} BufferInfo;

static void * _setError (BufferInfo *bufferInfo, int code)
{
	bufferInfo->error = code;
	return NULL;
}

/* ****************************************************************************

		Codec

** ***************************************************************************/

typedef BufferInfo *Codec(BufferInfo *);

static BufferInfo *
_codecLinear (BufferInfo *b)
{
	return b;
}

static BufferInfo *
_codecPCM8s (BufferInfo *b)
{
	int8_t *d = (int8_t *) b->data;
	size_t i;

	for (i = 0; i < b->length; i++)
		d[i] += (int8_t) 128;

	return b;
}

static BufferInfo *
_codecPCM16 (BufferInfo *b)
{
	int16_t *d = (int16_t *) b->data;
	size_t i, l = b->length / 2;

	for (i = 0; i < l; i++)
		{
		int16_t x = d[i];
		d[i] = ((x << 8) & 0xFF00) | ((x >> 8) & 0x00FF);
		}

	return b;
}

static int16_t
mulaw2linear (uint8_t mulawbyte)
{
	const int16_t exp_lut[8] = { 0, 132, 396, 924, 1980, 4092, 8316, 16764 };
	int16_t sign, exponent, mantissa, sample;

	mulawbyte = ~mulawbyte;
	sign = (mulawbyte & 0x80);
	exponent = (mulawbyte >> 4) & 0x07;
	mantissa = mulawbyte & 0x0F;
	sample = exp_lut[exponent] + (mantissa << (exponent + 3));

	if (sign != 0)
		sample = -sample;

	return sample;
}

static BufferInfo *
_codecULaw (BufferInfo *b)
{
	uint8_t *d = (uint8_t *) b->data;
	int16_t *buf = (int16_t *) malloc (b->length * 2);
	size_t i;

	if (buf == NULL)
		return _setError(b, ALUT_ERROR_OUT_OF_MEMORY);

	for (i = 0; i < b->length; i++)
		buf[i] = mulaw2linear (d[i]);

	b->pcm = buf;
	b->length *= 2;

	return b;
}

#define SIGN_BIT 	(0x80)        // Sign bit for a A-law byte
#define QUANT_MASK 	(0xf)         // Quantization field mask
#define SEG_SHIFT 	(4)           // Left shift for segment number
#define SEG_MASK 	(0x70)        // Segment field mask

static int16_t
alaw2linear (uint8_t a_val)
{
	a_val ^= 0x55;

	int16_t t = (a_val & QUANT_MASK) << 4;
	int16_t seg = ((int16_t) a_val & SEG_MASK) >> SEG_SHIFT;

	switch (seg)
		{
		case 0:  t += 8;  		break;
		case 1:  t += 0x108;	break;
		default: t += 0x108;  t <<= seg - 1;
		}

	return (a_val & SIGN_BIT) ? t : -t;
}

static BufferInfo *
_codecALaw (BufferInfo *b)
{
	uint8_t *d = (uint8_t *) b->data;
	int16_t *buf = (int16_t *) malloc (b->length * 2);
	size_t i;

	if (buf == NULL)
		return _setError(b, ALUT_ERROR_OUT_OF_MEMORY);

	for (i = 0; i < b->length; i++)
		buf[i] = alaw2linear (d[i]);

	b->pcm = buf;
	b->length *= 2;

	return b;
}

/* ****************************************************************************

		InputStream

** ***************************************************************************/

typedef struct
{
	size_t length;
	size_t position;
	const ALvoid *data;

} InputStream;


static ALboolean
streamRead (InputStream *s, void *ptr, size_t numBytesToRead)
{
	if (s->position + numBytesToRead  > s->length)
          return AL_FALSE;

	memcpy (ptr, s->data + s->position, numBytesToRead);
	s->position += numBytesToRead;

	return AL_TRUE;
}

static ALboolean
streamPtr (InputStream *s, void **ptr, size_t numBytesToRead)
{
	if (s->position + numBytesToRead  > s->length)
          return AL_FALSE;

	*(const void **)ptr = s->data + s->position;
	s->position += numBytesToRead;

	return AL_TRUE;
}

static ALboolean
_skipBytes (InputStream *s, size_t numBytesToSkip)
{
	if (s->position + numBytesToSkip  > s->length)
		return AL_FALSE;

	s->position += numBytesToSkip;

	return AL_TRUE;
}

static size_t
_remainingLength (const InputStream *s)
{
	return s->length - s->position;
}

static ALboolean
_streamEOF (InputStream *s)
{
	return (s->length - s->position == 0) ? AL_TRUE : AL_FALSE;
}

static ALboolean
_readUInt16LE (InputStream *stream, UInt16LE *value)
{
	unsigned char buf[2];

	if (!streamRead (stream, buf, sizeof (buf)))
		return AL_FALSE;

	*value = ((UInt16LE) buf[1] << 8) | ((UInt16LE) buf[0]);

	return AL_TRUE;
}

static ALboolean
_readInt32BE (InputStream *stream, Int32BE *value)
{
	unsigned char buf[4];

	if (!streamRead (stream, buf, sizeof (buf)))
		return AL_FALSE;

	*value = ((Int32BE) buf[0] << 24) | ((Int32BE) buf[1] << 16)
			| ((Int32BE) buf[2] << 8) | ((Int32BE) buf[3]);

	return AL_TRUE;
}

static ALboolean
_readUInt32LE (InputStream *stream, UInt32LE *value)
{
	unsigned char buf[4];

	if (!streamRead (stream, buf, sizeof (buf)))
		return AL_FALSE;

	*value = ((UInt32LE) buf[3] << 24) | ((UInt32LE) buf[2] << 16)
		   | ((UInt32LE) buf[1] << 8) | ((UInt32LE) buf[0]);

	return AL_TRUE;
}

/* ****************************************************************************

		Loader

** ***************************************************************************/

static BufferInfo *
loadWAV (InputStream *stream, BufferInfo *b)
{
	ALboolean found_header = AL_FALSE;
	UInt32LE chunkLength;
	Int32BE magic;
	UInt16LE audioFormat;
	UInt16LE numChannels;
	UInt32LE sampleFrequency;
	UInt32LE byteRate;
	UInt16LE blockAlign;
	UInt16LE bitsPerSample;
	Codec *codec = _codecLinear;

	if (!_readUInt32LE(stream, &chunkLength) || !_readInt32BE(stream, &magic))
		return _setError(b, ALUT_ERROR_CORRUPT_HEADER_DATA);

	if (magic != 0x57415645)      /* "WAVE" */
		return _setError(b, ALUT_ERROR_CORRUPT_HEADER_DATA);

	while (1)
		{
		if (!_readInt32BE(stream, &magic) || !_readUInt32LE(stream, &chunkLength))
			return _setError(b, ALUT_ERROR_CORRUPT_HEADER_DATA);

		if (magic == 0x666d7420)  			// "fmt "
			{
			found_header = AL_TRUE;

			if (chunkLength < 16)
				return _setError(b, ALUT_ERROR_CORRUPT_OR_TRUNCATED_DATA);

			if ( !_readUInt16LE (stream, &audioFormat)
					|| !_readUInt16LE (stream, &numChannels)
					|| !_readUInt32LE (stream, &sampleFrequency)
					|| !_readUInt32LE (stream, &byteRate)
					|| !_readUInt16LE (stream, &blockAlign)
					|| !_readUInt16LE (stream, &bitsPerSample) )
				return _setError(b, ALUT_ERROR_CORRUPT_HEADER_DATA);

			if (!_skipBytes(stream, chunkLength - 16))
				return _setError(b, ALUT_ERROR_CORRUPT_OR_TRUNCATED_DATA);

			switch (audioFormat)
				{
				case 1:						// PCM
#ifdef WORDS_BIGENDIAN
				  codec = (bitsPerSample == 8) ? _codecLinear : _codecPCM16;
#else
				  codec = _codecLinear;
#endif
				  break;

				case 7:						// u-law
				  bitsPerSample *= 2;
				  codec = _codecULaw;
				  break;

				default:
				  return _setError(b, ALUT_ERROR_UNSUPPORTED_FILE_SUBTYPE);
				}
			}
		else if (magic == 0x64617461)		// "data"
			{
			ALvoid *data = NULL;

			if (!found_header) 				// FIX ME fmt chunk can come later??
				return _setError(b, ALUT_ERROR_CORRUPT_OR_TRUNCATED_DATA);

			if (!streamPtr (stream, &data, chunkLength))
				return _setError(b, ALUT_ERROR_CORRUPT_OR_TRUNCATED_DATA);

			b->data = data;
			b->length = chunkLength;
			b->numChannels = numChannels;
			b->bitsPerSample = bitsPerSample;
			b->sampleFrequency = sampleFrequency;

			return codec(b);
			}
		else if (!_skipBytes(stream, chunkLength))
			return _setError(b, ALUT_ERROR_CORRUPT_OR_TRUNCATED_DATA);

		if ((chunkLength & 1) && !_streamEOF(stream) && !_skipBytes(stream, 1))
			return _setError(b, ALUT_ERROR_CORRUPT_OR_TRUNCATED_DATA);
		}
}

static BufferInfo *
loadAU (InputStream *stream, BufferInfo *b)
{
	Int32BE dataOffset;				// byte offset to data part, minimum 24
	Int32BE len;					// # of bytes in data part, -1 = unknown
	Int32BE encoding;				// encoding of data part, see AUEncoding
	Int32BE sampleFrequency;		// number of samples per second
	Int32BE numChannels;			// number of interleaved channels
	size_t length;
	Codec *codec;
	ALvoid *data = NULL;
	ALint bitsPerSample = 16;

	if (!_readInt32BE (stream, &dataOffset) || !_readInt32BE (stream, &len)
			|| !_readInt32BE (stream, &encoding)
			|| !_readInt32BE (stream, &sampleFrequency)
			|| !_readInt32BE (stream, &numChannels))
		return _setError(b, ALUT_ERROR_CORRUPT_HEADER_DATA);

	length = (len == -1) ? (_remainingLength(stream) - AU_HEADER_SIZE - dataOffset)
						 : (size_t) len;

	if (!(dataOffset >= AU_HEADER_SIZE && length > 0 && sampleFrequency >= 1 && numChannels >= 1))
		return _setError(b, ALUT_ERROR_CORRUPT_HEADER_DATA);

	if (!_skipBytes(stream, dataOffset - AU_HEADER_SIZE))
		return _setError(b, ALUT_ERROR_CORRUPT_OR_TRUNCATED_DATA);

	switch (encoding)
		{
		case AU_ALAW_8:  codec = _codecALaw;  break;
		case AU_ULAW_8:  codec = _codecULaw;  break;
		case AU_PCM_8:   codec = _codecPCM8s;  bitsPerSample = 8;  break;
		case AU_PCM_16:
#ifdef WORDS_BIGENDIAN
		  codec = _codecLinear;		break;
#else
		  codec = _codecPCM16;		break;
#endif
		default:	return _setError(b, ALUT_ERROR_UNSUPPORTED_FILE_SUBTYPE);
		}

	if (!streamPtr (stream, &data, length))
		return _setError(b, ALUT_ERROR_CORRUPT_OR_TRUNCATED_DATA);

	b->data = data;
	b->length = length;
	b->numChannels = numChannels;
	b->bitsPerSample = bitsPerSample;
	b->sampleFrequency = sampleFrequency;

	return codec(b);
}

static BufferInfo *
loadRaw (InputStream *stream, BufferInfo *b)
{
	size_t length = _remainingLength(stream);
	ALvoid *data = NULL;

	if (!streamPtr(stream, &data, length))
		return _setError(b, ALUT_ERROR_CORRUPT_OR_TRUNCATED_DATA);

	b->data = data;
	b->length = length;
	b->numChannels = 1;
	b->bitsPerSample = 8;
	b->sampleFrequency = 8000;

	return _codecLinear(b);
}

static size_t
pcm_read(void *ptr, size_t numBytesToRead, InputStream *s)
{
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
pcm_time_seek(InputStream *s, BufferInfo *b, NSTimeInterval time)
{
	NSTimeInterval duration = b->length / (b->bitsPerSample/8)
							/ b->sampleFrequency / b->numChannels;

	s->position = time / duration * b->length;
	s->position = (s->position + (8 - 1)) & -8;						// align 8

	return (s->position < s->length) ? 0 : -1;
}

/* ****************************************************************************

		_NSSoundOpenAL

** ***************************************************************************/

@interface _NSSoundOpenAL : NSSound
{
	ALuint source;
	ALuint _buffers[OPENAL_BUFFERS];
	ALCenum _error;
	InputStream stream;
	char _pcm[OPENAL_BUFFERS*1024];
}
@end

@implementation NSSound  (PrivateOpenAL)

+ (void) _closeDevice
{
	if (!alcMakeContextCurrent(NULL))
		NSLog(@"ERROR: making OpenAL context NULL (%d)", alGetError());
	else if (__alDevice)
		{
		alcDestroyContext(__alContext);
		if (alcGetError(__alDevice) != ALC_NO_ERROR)
			NSLog(@"ERROR: destroying OpenAL context (%d)", alGetError());
		else if (!alcCloseDevice(__alDevice))
			NSLog(@"ERROR: closing OpenAL device (%d)", alGetError());
		}
}

@end /* NSSound  (OpenAL) */

@implementation _NSSoundOpenAL

+ (void) initialize
{
	if (!__alDevice)			// open default output device & create context
		{
		if ((__alDevice = alcOpenDevice(NULL)) == NULL)
			NSLog(@"ERROR: opening OpenAL device (%d)", alGetError());
		else if ((__alContext = alcCreateContext(__alDevice, 0)) == NULL)
			NSLog(@"ERROR: creating OpenAL context (%d)", alGetError());
		else if (!alcMakeContextCurrent(__alContext))
			NSLog(@"ERROR: making OpenAL context current (%d)", alGetError());
		else
			{
			NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

			[nc addObserver: self
				selector: @selector(_closeDevice)
				name: NSApplicationWillTerminateNotification
				object: NSApp];
		}	}

	if (!__filesSND)
		__filesSND = [[NSArray arrayWithObjects:@"wav", @"snd", @"au", nil] retain];
}

+ (id) alloc								{ return NSAllocateObject(self); }
+ (NSArray *) soundUnfilteredTypes			{ return __filesSND; }

+ (BOOL) canInitWithData:(NSData *)data
{
	unsigned char sig[] = {'R','I','F','F'};
	unsigned char sg2[] = {'.','s','n','d'};

	return _CGImageCanInitWith( (CFDataRef)data, sig, sizeof(sig) )
		|| _CGImageCanInitWith( (CFDataRef)data, sg2, sizeof(sg2) );
}

- (id) initWithData:(NSData *)d
{
	Int32BE magic;
	BufferInfo *b;

	if (!(_data = [d retain]))
		return _NSInitError(self, @"init with nil data");

	stream.data = [_data bytes];
	stream.length = [_data length];

	if (_name && [[[_name pathExtension] lowercaseString] isEqualToString:@"raw"])
		b = loadRaw (&stream, (BufferInfo *)_reserved);
	else
		{	// files with a known ext should have matching magic bytes signature
		if (!_readInt32BE (&stream, &magic))
			return _NSInitError(self, @"unable to read sound signature");

		if (magic == 0x52494646)	// 'RIFF' is Microsoft '.wav' format
			b = loadWAV (&stream, (BufferInfo *)_reserved);

		if (magic == 0x2E736E64)	// NeXT / Sun '.snd' or '.au' format
			b = loadAU (&stream, (BufferInfo *)_reserved);
		}

	if (!b)
		return _NSInitError(self, @"error parsing sound data");

	if (b->bitsPerSample == 8)
		b->format = (b->numChannels == 1) ? AL_FORMAT_MONO8
				  : (b->numChannels == 2) ? AL_FORMAT_STEREO8 : 0;
	else if (b->bitsPerSample == 16)
		b->format = (b->numChannels == 1) ? AL_FORMAT_MONO16
				  : (b->numChannels == 2) ? AL_FORMAT_STEREO16 : 0;

	if (!b->format)
		return _NSInitError(self, @"unknown sound format");

	stream.data = (b->pcm) ? b->pcm : b->data;
	stream.length = b->length;
	stream.position = 0;

	return self;
}

- (void) dealloc
{
	BufferInfo *b = (BufferInfo *)_reserved;

	free(b->pcm),		b->pcm = NULL;

	if (_f.loaded)
		{
		alDeleteSources(1, &source);
		alDeleteBuffers(OPENAL_BUFFERS, _buffers);
		}
	[super dealloc];
}

- (NSTimeInterval) duration
{
	BufferInfo *b = (BufferInfo *)_reserved;

	if (b->length == 0 || b->numChannels == 0 || b->sampleFrequency == 0)
		return 0;

	return b->length / (b->bitsPerSample/8) / b->sampleFrequency / b->numChannels;
}

- (NSString *) description
{
	BufferInfo *b = (BufferInfo *)_reserved;

	return [NSString stringWithFormat:
				@"NSSound: %@ - %u ch, %u bits, %d Hz, %u Bytes (%u secs)",
				_name,  b->numChannels, b->bitsPerSample,
				(int)b->sampleFrequency, b->length, (int)[self duration]];
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
	BufferInfo *b = (BufferInfo *)_reserved;
	ALint i, count = OPENAL_BUFFERS;
	ALuint buf[count];
	ALuint *buffers = (_f.loaded) ? buf : _buffers;
	int eos = 0;

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
			long r = pcm_read(_pcm + pos, sizeof(_pcm) - pos, &stream);

			if (r == 0)
				{
				eos = 1;
				break;
				}
			pos += r;
			}

		alBufferData(buffers[i], b->format, _pcm, pos, b->sampleFrequency);
		}
	alSourceQueueBuffers(source, count, buffers);

	if (eos)
		{
		if (_f.loops)
			pcm_time_seek(&stream, (BufferInfo *)_reserved, 0);
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

	pcm_time_seek(&stream, (BufferInfo *)_reserved, _currentTime);

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
		NSLog(@"ERROR: OpenAL _setPanLeft:Right: failed (%x)", _error);
}

@end /* _NSSoundOpenAL */
