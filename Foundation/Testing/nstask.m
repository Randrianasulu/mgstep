#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSProcessInfo.h>
#include <Foundation/NSTask.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSString.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSFileHandle.h>

int
main()
{
	NSDictionary *e;
	id pool = [[NSAutoreleasePool alloc] init];
	NSTask *task = [NSTask launchedTaskWithLaunchPath: @"/bin/ls" arguments: nil];

	[task waitUntilExit];
	printf("Exit status - %d\n", [task terminationStatus]);
	
	[pool release];
	pool = [[NSAutoreleasePool alloc] init];
	
	task = [NSTask new];
	e = [[[[NSProcessInfo processInfo] environment] mutableCopy] autorelease];
	[task setEnvironment: e];
	[task setLaunchPath: @"/bin/sh"];
	[task setArguments: [NSArray arrayWithObjects: @"-c", @"echo $PATH", nil]];
	[task launch];
	[task waitUntilExit];
	[task release];

	[pool release];
	pool = [[NSAutoreleasePool alloc] init];

	{
	NSTask *t = [[[NSTask alloc] init] autorelease];		// NSPipe support
	NSPipe *sin;
	NSPipe *sout;
	NSFileHandle *input;
	NSFileHandle *output;
	NSString *data = @"nstring NSString hello NSString goodbye";

	[t setLaunchPath: @"/bin/sh"];
	[t setArguments: [NSArray arrayWithObjects: @"-c", @"sed -e s/NSString/*******/", nil]];
//	[t setArguments: [NSArray arrayWithObjects: @"-c", @"cat - > /tmp/out.txt", nil]];

	sin = [[[NSPipe alloc] init] autorelease];
	[t setStandardInput: sin];
	input = [sin fileHandleForWriting];
	sout = [[[NSPipe alloc] init] autorelease];
	[t setStandardOutput: sout];
	output = [sout fileHandleForReading];

	printf("launch task\n");
	[t launch];

	if (data)		// send input to command
		{
		printf("write data\n");
		[input writeData: [data dataUsingEncoding: NSUTF8StringEncoding]];
		}
	[input closeFile];

	printf("get result\n");

	if (1)		// expect return data
		{
		NSString *s;
		NSData *result = [output readDataToEndOfFile];

		printf("# got %d bytes of data\n", [result length]);
		s = [[[NSString alloc] initWithData:result encoding:NSASCIIStringEncoding] autorelease];
		printf("## returned: %s\n", [s cString]);
		}
	else
		{
		printf("ignore output\n");
		[output closeFile];
		[t waitUntilExit];
		}
	}

	[pool release];

	printf("nstask test complete\n");
	
	exit(0);
}

