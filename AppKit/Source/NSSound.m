/*
   NSSound.m

   Sound file loading and playback.

   Copyright (C) 2021 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    May 2021

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSBundle.h>
#include <AppKit/NSSound.h>


static NSMutableDictionary *__soundNames = nil;
static NSMutableArray *__soundClasses = nil;
static NSArray *__sndFileTypes = nil;

static id __NSSoundConductor = Nil;



@implementation NSSound

+ (id) alloc									{ return __NSSoundConductor; }
+ (BOOL) canInitWithData:(NSData *)data			{ SUBCLASS return NO; }

+ (void) _registerSoundClass:(Class)sc
{
	DBLog(@" register %@", [sc description]);

	if (![sc respondsToSelector: @selector(soundUnfilteredTypes)])
		[NSException raise: NSInvalidArgumentException
					 format: @"plugin does not respond to soundUnfilteredTypes"];

	[__soundClasses addObject: sc];
	ASSIGN(__sndFileTypes, nil);				// regenerate types next access
}

+ (void) _loadPlugins
{
	int i, count;
	NSArray *bundles = [[NSBundle systemBundle] pathsForResourcesOfType:@"audio"
												inDirectory:@"AppKit/Plugins"];

	__soundClasses = [[NSMutableArray alloc] initWithCapacity: 4];

	for (i = 0, count = [bundles count]; i < count; i++)
		{
		NSString *path = [bundles objectAtIndex: i];
		NSBundle *bundle = [[NSBundle alloc] initWithPath:path];
		Class c;

		if (bundle)
			{
			NSLog(@"Loading bundle %@", path);
			if (!(c = [bundle principalClass]))
				NSLog(@"Error loading principalClass of bundle %@", path);
			else
				[NSSound _registerSoundClass: c];
			}
		else
			NSLog(@"Error loading bundle %@", path);
		}
}

+ (void) initialize
{
	if (!__soundNames)
		__soundNames = [[NSMutableDictionary alloc] initWithCapacity: 16];
	if (!__NSSoundConductor)
		__NSSoundConductor = NSAllocateObject(self);
	if (!__soundClasses)
		[self _loadPlugins];
}

+ (Class) _soundClassForData:(NSData *)data
{
	int i, count = [__soundClasses count];
	Class c;

	for (i = 0; i < count; i++)
		if ([(c = [__soundClasses objectAtIndex: i]) canInitWithData:data])
			return c;

	return Nil;
}

+ (Class) _soundClassForFileType:(NSString *)type
{
	int i, count = [__soundClasses count];

	for (i = 0; i < count; i++)
		{
		Class cls = [__soundClasses objectAtIndex: i];

		if ([[cls soundUnfilteredTypes] indexOfObject:type] != NSNotFound)
			return cls;
		}

	return Nil;
}

+ (NSArray *) soundUnfilteredTypes
{
	if (!__sndFileTypes)
		{
		NSCountedSet *sft = [NSCountedSet new];
		NSUInteger i, c = [__soundClasses count];
		
		for (i = 0; i < c; i++)
			{
			Class sc = [__soundClasses objectAtIndex: i];

			[sft addObjectsFromArray: [sc soundUnfilteredTypes]];
			}

		__sndFileTypes = [[sft allObjects] retain];
		}

	return __sndFileTypes;
}

+ (id) soundNamed:(NSString *)name
{
	NSSound *s = [__soundNames objectForKey:name];

	if (!s)
		{
		s = [[NSSound alloc] initWithContentsOfFile:name byReference:YES];
		[__soundNames setObject:[s autorelease] forKey:name];
		}

	return s;
}

- (id) initWithData:(NSData *)d
{
	Class c = [NSSound _soundClassForData: d];

	if (!c || !(self = [[c alloc] initWithData:d]))
		return _NSInitError(nil, @"NSSound init with invalid data");

	return self;
}

- (id) initWithContentsOfFile:(NSString *)p byReference:(BOOL)encodeByName
{
	NSString *ext = [p pathExtension];
	Class c;

	if (![ext length])
		return [self initWithData:[NSData dataWithContentsOfFile:p]];

	if ((c = [NSSound _soundClassForFileType: ext]))
		if ((self = [[c alloc] initWithData:[NSData dataWithContentsOfFile:p]]))
			{
			self->_f.encodeByName = encodeByName;
			self->_name = [[p lastPathComponent] retain];
			self->_volume = 0.5;

			return self;
			}

	return _NSInitError(nil, @"NSSound init with invalid path: %@", p);
}

- (void) dealloc
{
	[_name release],	_name = nil;
	[_data release],	_data = nil;
	[super dealloc];
}

- (BOOL) setName:(NSString *)name
{
	NSSound *s;

	if (!name && (s = [__soundNames objectForKey:_name]))
		[__soundNames removeObjectForKey:_name];
	else if (s || (s = [__soundNames objectForKey:name]))	// checks old & new
		return (s == self) ? YES : NO;

	ASSIGN(_name, name);
	if (name)
		[__soundNames setObject:self forKey:_name];

	return YES;
}

- (NSString *) name								{ return _name; }
- (id) copy										{ return [self retain]; }
- (float) volume								{ return _volume; }
- (void) setVolume:(float)volume				{ _volume = volume; }
- (void) setLoops:(BOOL)flag					{ _f.loops = flag; }
- (BOOL) loops									{ return _f.loops; }
- (id <NSSoundDelegate>) delegate				{ return _delegate; }

- (void) setDelegate:(id <NSSoundDelegate>)d
{
	_delegate = d;
	_f.notifyEnd = ([d respondsToSelector:@selector(sound:didFinishPlaying:)]);
}

- (BOOL) play									{ return NO; }
- (BOOL) pause									{ return NO; }
- (BOOL) resume									{ return NO; }
- (BOOL) stop									{ return YES; }
- (BOOL) isPlaying								{ return NO; }

- (NSTimeInterval) duration						{ return 0; }

- (NSTimeInterval) currentTime
{
	if ([self isPlaying])
		_currentTime = [NSDate timeIntervalSinceReferenceDate] - _playTime;

	return _currentTime;
}

- (void) setCurrentTime:(NSTimeInterval)secs
{
	_currentTime = MIN(secs, [self duration]);
}

- (void) _startLoopTimer
{
	if (!_loadTimer)
		{
		_loadTimer = [NSTimer timerWithTimeInterval: 0.5
							  target: self
							  selector: @selector(_loadBuffers:)
							  userInfo: nil
							  repeats: YES];

		[[NSRunLoop currentRunLoop] addTimer:_loadTimer
									forMode:NSDefaultRunLoopMode];
		}
}

- (void) encodeWithCoder:(NSCoder*)aCoder
{
	[super encodeWithCoder:aCoder];

	[aCoder encodeObject: _name];
	[aCoder encodeValueOfObjCType:@encode(unsigned int) at: &_f];
	if (!_f.encodeByName)
		[aCoder encodeObject: _data];
}

- (id) initWithCoder:(NSCoder*)aDecoder
{
	[super initWithCoder:aDecoder];
	
	_name = [aDecoder decodeObject];
	[aDecoder decodeValueOfObjCType:@encode(unsigned int) at: &_f];
	if (!_f.encodeByName)
		_data = [aDecoder decodeObject];

	return self;
}

@end
