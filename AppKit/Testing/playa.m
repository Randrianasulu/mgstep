/*
   playa.m

   Play audio file

   Copyright (C) 2021 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:	May 2021

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSProcessInfo.h>
#include <AppKit/NSSound.h>

#include <fcntl.h>
#include <termios.h>
#include <unistd.h>
#include <signal.h>
#include <stdlib.h>


static int __playa_exit = 0;
static int __console = 0;

static struct termios __org_state;



static void resetMode(void)
{
	if (__console > 0)
		tcsetattr(__console, TCSAFLUSH, &__org_state),  __console = 0;
}

static void setRawMode(int fd)
{
	tcgetattr(fd, &__org_state);
	
	atexit(resetMode);									// failsafe cleanup

	struct termios raw = __org_state;
	raw.c_lflag &= ~(ECHO | ICANON | ISIG);
    if ((tcsetattr(fd, TCSAFLUSH, &raw)) == -1)
		perror("tcsetattr: ");
}


@interface Controller : NSObject  <NSSoundDelegate>
{
	NSSound *snd;
	BOOL _paused;
	CFRunLoopSourceRef _rs;
}

- (void) update;

- (void) detachConsole;
- (void) attachConsole;

@end

@implementation Controller

- (id) initWithContentsOfFile:(NSString *)fn
						 seek:(NSTimeInterval)seconds
						 loop:(BOOL)flag
{
	if (!(snd = [[NSSound alloc] initWithContentsOfFile:fn byReference:NO]))
		return _NSInitError(self, @"init with invalid file");

	[snd setLoops: flag];
	[snd setDelegate: self];
	fprintf(stdout, "  %s\n", [[snd description] cString]);

	if (seconds > 0)
		[snd setCurrentTime: seconds];
	[snd play];

	return self;
}

- (void) dealloc
{
	[snd stop];
	[snd release];
	[super dealloc];
}

- (void) selfTest:(NSTimeInterval)seconds
{
	NSLog(@"pan left");
	[snd _setPanLeft:1.0 Right:0.5];

	NSLog(@"pan right");
	[snd _setPanLeft:0.5 Right:1.0];
}

- (void) update
{
	if (__playa_exit)
		return;
	fprintf(stdout, "  playa  %s  [ %1.2f / %1.2f ]\r",
			[[snd name] cString], [snd currentTime], [snd duration]);
	fflush(stdout);
}

- (void) sound:(NSSound *)sound didFinishPlaying:(BOOL)flag
{
    fprintf(stdout, "  playa didFinishPlaying (%d)  [ %f / %f ]\n",
			flag, [sound currentTime], [sound duration]);
	__playa_exit = 1;
}

- (void) _nextKeyboardEvent:(id)sender
{
	char c;
	int n = read(__console, &c, 1);

	if (n < 0)
		printf("ERROR %s\n", strerror(errno));
	else if (c < 31 && c != 10)
		__playa_exit = 1;						// CTRL anything terminates

	switch (c)
		{
		case ' ':
			(_paused) ? [snd resume] : [snd pause];
			if ((_paused = !_paused))
				fprintf(stdout, "  ====== PAUSED ======\n");
			break;
		case '/':	[snd setVolume: MAX(0.0, [snd volume] - 0.1)];  break;
		case '*':	[snd setVolume: MIN(1.0, [snd volume] + 0.1)];  break;
		case 'q':	__playa_exit = 1;  break;
		};
	if (c == '/' || c == '*')
		fprintf(stdout, "  volume [ %1.2f ]\n", [snd volume]);
}

- (void) detachConsole
{
	resetMode();
	CFRunLoopSourceInvalidate(_rs);
}

- (void) attachConsole
{
	CFOptionFlags fl = kCFSocketReadCallBack;
	CFSocketContext cx = { 0, self, NULL, NULL, NULL };
	SEL scb = @selector(_nextKeyboardEvent:);
	CFSocketCallBack cb = (CFSocketCallBack)scb;
	CFSocketRef sk;

	if ((__console = open("/dev/tty", O_RDONLY | O_NONBLOCK)) == -1)
		[NSException raise:NSGenericException format:@"Unable to open /dev/tty"];
	setRawMode(__console);

	sk = CFSocketCreateWithNative(NULL, __console, fl, cb, &cx);
	if ((_rs = CFSocketCreateRunLoopSource(NULL, sk, 0)) == NULL)
		[NSException raise:NSGenericException format:@"CFSocket init error"];
	CFRunLoopAddSource(CFRunLoopGetCurrent(), _rs, (CFStringRef)NSDefaultRunLoopMode);
	CFRelease(_rs);
}

@end


void
usage(const char *err_msg, int exit_status)
{
	if (exit_status)
		fprintf(stdout, "\n  Invalid command, %s.\n\nUsage:\n\n", err_msg);
	else
		fprintf(stdout, "\n%s\n\n", err_msg);

	fprintf(stdout, "  playa [-hlosv ] <audio file>      play audio (wav, snd, au, ogg) \n\n");
	fprintf(stdout, "  playa -o offset <audio file>      play file starting at offset seconds\n");
	fprintf(stdout, "  playa -s        <audio file>      perform self-test and play\n");
	fprintf(stdout, "  playa -l        <audio file>      play audio in a loop\n\n");
	fprintf(stdout, "  playa -h                          view this helpful info\n");
	fprintf(stdout, "  playa -v                          print version and exit\n\n");
	fprintf(stdout, "  Keys:    Volume +/-       '/' or '*'\n");
	fprintf(stdout, "           Pause & Resume   'SPACE'\n");
	fprintf(stdout, "\n");

	exit(exit_status);
}

void
run_client(int loop, float secs, int test)
{
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	NSArray *args = [[NSProcessInfo processInfo] arguments];
	NSString *fn = [args objectAtIndex: [args count] - 1];
	Controller *c = [[Controller alloc] initWithContentsOfFile:fn
										seek:secs
										loop:loop];
	[c attachConsole];

	while (c && !__playa_exit)
		{
		[[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow:.3]];
		[c update];
		[pool release];
		pool = [[NSAutoreleasePool alloc] init];
		}

	[c detachConsole];
	[c release];
	[NSSound _closeDevice];						// must do manually w/o NSApp

    [pool release];
}

int
main(int argc, char **argv, char **env)
{
	extern int optind;
	int c, loop = 0;
	int self_test = 0;
	float offset = 0;

	while ((c = getopt(argc, argv, "shlo:v")) != -1)
		switch (c)
			{
			case 'h':		usage("playa tool help:", 0);
			case 'v':		usage("mGSTEP playa v0.001", 0);
			case 'l':		loop = 1;               break;
			case 's':		self_test = 1;          break;
			case 'o':		offset = atof(optarg);  break;
			};

	if (optind >= argc)
		usage("expected audio file argument", 1);

	run_client(loop, offset, self_test);

	exit(0);
}
