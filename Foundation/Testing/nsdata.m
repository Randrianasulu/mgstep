#include <Foundation/NSData.h>
#include <Foundation/NSArchiver.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSString.h>
#include <Foundation/NSObjCRuntime.h>

int
main ()
{
	id a;
	id d;
	id o;
	id pool = [[NSAutoreleasePool alloc] init];

//	[NSAutoreleasePool enableDoubleReleaseCheck:YES];

	d = [NSData dataWithContentsOfMappedFile:@"nsdata.m"];
	if (d == nil)
	printf("Unable to map file");
	printf("Mapped %d bytes\n", [d length]);
	
	o = [d copy];
	printf("Copied %d bytes\n", [o length]);
	[o release];
	
	o = [d mutableCopy];
	printf("Copied %d bytes\n", [o length]);
	[o release];
	
	d = [NSData dataWithContentsOfFile:@"nsdata.m"];
	if (d == nil)
	printf("Unable to read file");
	printf("Read %d bytes\n", [d length]);
	
	o = [d copy];
	printf("Copied %d bytes\n", [o length]);
	[o release];
	
	o = [d mutableCopy];
	printf("Copied %d bytes\n", [o length]);
	[o release];
	
	o = [d copy];
	printf("Copied %d bytes\n", [o length]);
	[o release];
	
	o = [d mutableCopy];
	printf("Copied %d bytes\n", [o length]);
	[o release];
	
	o = [d copy];
	printf("Copied %d bytes\n", [o length]);
	[o release];
	
	d = [d mutableCopy];
	printf("Copied %d bytes\n", [d length]);
	
	[d appendBytes: "Hello world" length: 11];
	printf("Extended by 11 bytes to %d bytes\n", [d length]);
	a = [[NSArchiver new] autorelease];
	[a encodeRootObject: d];
	printf("Encoded data into archive\n");
	a = [[NSUnarchiver alloc] initForReadingWithData: [a archiverData]];
	o = [a decodeObject];
	printf("Decoded data from archive - length %d\n", [o length]);
	[a release];

	{
	char b[] = "1234567890";
	
	d = [[NSData alloc] initWithBytesNoCopy:b length:10 freeWhenDone:NO];
	printf("%s initWithBytesNoCopy %d bytes\n",
			[NSStringFromClass([d class]) cString], [d length]);
	[d release];

	d = [[NSMutableData alloc] initWithBytesNoCopy:b length:10 freeWhenDone:NO];
	printf("%s initWithBytesNoCopy %d bytes\n",
			[NSStringFromClass([d class]) cString], [d length]);
	[d setLength:99];
	printf("setLength (99) %d bytes\n", [d length]);
	[d setLength:15];
	printf("setLength (15) %d bytes\n", [d length]);
	[d appendBytes:"abcde" length:5];
	printf("appendBytes (5) %d bytes\n", [d length]);
	[d increaseLengthBy:10];
	printf("increaseLengthBy (10) %d size\n", [d length]);
	[d release];

	d = [NSMutableData dataWithBytesNoCopy:malloc(10) length:10];
	printf("%s dataWithBytesNoCopy %d bytes\n",
			[NSStringFromClass([d class]) cString], [d length]);
	d = [NSMutableData data];
	printf("%s data %d bytes\n",
			[NSStringFromClass([d class]) cString], [d length]);
	d = [NSMutableData dataWithBytes:b length:10];
	printf("%s dataWithBytes:length: %d bytes\n",
			[NSStringFromClass([d class]) cString], [d length]);
	d = [NSMutableData dataWithData:d];
	printf("%s dataWithData: %d bytes\n",
			[NSStringFromClass([d class]) cString], [d length]);
	o = [d copy];
	printf("%s copy %d bytes\n",
			[NSStringFromClass([o class]) cString], [o length]);
	printf("Data copy is equal: %s\n", [o isEqual: d] ? "YES" : "NO");
	}

	{
	char *base64_tests[][2] = { { "", "" },
								{ "f", "Zg==" },
								{ "fo", "Zm8=" },
								{ "foo", "Zm9v" },
								{ "foob", "Zm9vYg==" },
								{ "fooba", "Zm9vYmE=" },
								{ "foobar", "Zm9vYmFy" },
								{ "foo:barpwd", "Zm9vOmJhcnB3ZA==" },
								{ NULL, NULL }};
	int i = 0;

	for (; base64_tests[i][0] != NULL; i++)
		{
		char *b = base64_tests[i][0];
		const char *x = base64_tests[i][1];
		const char *rz;

//			printf("TEST: base64 strings '%s' '%s' (%d)\n", b, x, strlen(b));

		d = [[NSData alloc] initWithBytesNoCopy:b length:strlen(b) freeWhenDone:NO];
		if (!strcmp((rz = [[d base64String] cString]), x))
			printf("PASS: base64 strings equal '%s' '%s'\n",
					[[d base64String] UTF8String], x);
		else
			printf("FAIL: base64 strings NOT equal '%s' '%s'\n",
					[[d base64String] UTF8String], x);
		[d autorelease];
		}

	d = [[NSMutableData alloc] initWithBase64String: @"Zm9vYmFy"];
	[d appendBytes:"\0" length:1];
	if (!strcmp([d bytes], "foobar"))
		printf("PASS: base64 string '%s' is '%s'\n", "Zm9vYmFy", [d bytes]);
	else
		printf("FAIL: base64 string '%s' NOT '%s'\n", "Zm9vYmFy", [d bytes]);
	}

	[[[NSMutableData alloc] initWithCapacity: 0] setData: [[NSMutableData alloc] initWithLength: 1]];

	[pool release];
	printf("nsdata test complete\n");
	
	exit(0);
}
