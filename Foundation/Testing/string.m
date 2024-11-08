
// Fri Oct 23 02:58:47 MET DST 1998 	dave@turbocat.de

#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSString.h>

void
print_string(NSString* s)
{
	printf("string: [%s], length %d\n", [s cString], [s length]);
}

int main()
{
	NSAutoreleasePool *arp = [NSAutoreleasePool new];
	id s = @"This is a test string";
	id s2, s3;
	NSString *a = @"/usr/src";
	NSString *b = @"/usr/src/";
	NSString *p = @"/mgstep";
	NSString *m = @"mgstep";

	NSString *c = @".tar";
	NSString *d = @"tar";

	print_string(s);
	
	s2 = [s copy];
	print_string(s2);
	s3 = [s2 mutableCopy];
	[s2 release];
	s2 = [s3 copy];
	[s3 release];
	[s2 release];
	
	s2 = [s copy];
	print_string(s2);
	
	s2 = [s stringByAppendingString:@" with something added"];
	print_string(s2);
	
	s2 = [s mutableCopy];
	[s2 replaceCharactersInRange:((NSRange){10,4}) withString:@"changed"];
	print_string(s2);
	
	/* Test the use of the `%@' format directive. */
	s2 = [NSString stringWithFormat: @"foo %@ bar", @"test"];
	print_string(s2);
	
	print_string([a stringByAppendingPathComponent: p]);
	print_string([a stringByAppendingPathComponent: m]);
	print_string([b stringByAppendingPathComponent: p]);
	print_string([b stringByAppendingPathComponent: m]);

	print_string([a stringByAppendingPathComponent: @"./.xinitrc"]);
	print_string([a stringByAppendingPathComponent: @".xinitrc"]);

	print_string([m stringByAppendingPathExtension: c]);
	print_string(a = [m stringByAppendingPathExtension: d]);
	print_string(a = [a stringByAppendingPathExtension: @"gz"]);
	print_string([a stringByDeletingPathExtension]);

	s2 = [@"" stringByStandardizingPath];
	print_string(s2);
	s2 = [@"~/test" stringByStandardizingPath];
	print_string(s2);
	s2 = [@"//" stringByStandardizingPath];
	print_string(s2);
	s2 = [@"/bin//" stringByStandardizingPath];
	print_string(s2);
	s2 = [@"/./" stringByStandardizingPath];
	print_string(s2);
	s2 = [@"/bin/./" stringByStandardizingPath];
	print_string(s2);
	s2 = [@"/usr/bin/../" stringByStandardizingPath];
	print_string(s2);
	s2 = [@"/usr/bin/../test" stringByStandardizingPath];
	print_string(s2);

	if (![@"" isEqualToString:[NSString new]])
		printf("Error: empty strings are not equal\n");
	else
		printf("PASS: empty strings are equal\n");

	{
	char buf[16] = {0};

	if ([@"/mach_kernel" getFileSystemRepresentation:buf maxLength:12])
		printf("FAIL with buf too small\n");
	if ([@"/mach_kernel" getFileSystemRepresentation:buf maxLength:13])
		printf("PASS get buf %s\n", buf);
	else
		printf("FAIL with bigger buf\n");
	}

	s2 = [NSMutableString stringWithCapacity:100];
	[s2 setString: @"Replace go with git wherever go is found."];
	printf("Replaced: %d \n",	[s2 replaceOccurrencesOfString:@"go"
		withString:@"git"
		options:NSLiteralSearch
		range:NSMakeRange(0, [s2 length])]);
	printf("Replaced: out: '%s'\n",	[s2 cString]);

	s2 = [NSString stringWithFormat: @" +%@", @"01"];
	s3 = [NSString stringWithFormat: @"  %@", @"T"];
	a = [NSString stringWithFormat: @" %@", @"Yes"];
	b = [NSString stringWithFormat: @"  %@", @"true"];
	printf("TRUE bool strings %d %d %d %d %d %d\n", [@"+1" boolValue], [@"y" boolValue],
				[s2 boolValue], [s3 boolValue], [a boolValue], [b boolValue]);
	s2 = [NSString stringWithFormat: @"   %@", @"0"];
	s3 = [NSString stringWithFormat: @"  %@", @"F"];
	printf("FALSE bool strings %d %d %d %d\n", [@"+0" boolValue], [@"n" boolValue],
											[s2 boolValue], [s3 boolValue]);

	{
	unichar ubuf[] = {0x0801, 0xA000, 0xD074, 0xE072, 0xF0F6, 0xE06D};
	const char *utf8;
	int i;

	s2 = [NSString stringWithCharacters:ubuf length:sizeof(ubuf)/sizeof(unichar)];
	utf8 = [s2 UTF8String];

	printf("UCS-2 to UTF-8: ");
	for(i=0; i < strlen(utf8); i++)
		printf("%02hhX ", utf8[i]);
	printf("\n");
	printf("strlen %d\n", strlen(utf8));
	}

	{
	unichar ubuf[] = {0x00C5, 0x0073, 0x0074, 0x0072, 0x00F6, 0x006D};
	unichar decomp[] = {0x0041, 0x030A, 0x0073, 0x0074, 0x0072, 0x006F, 0x0308, 0x006D};
	const char *utf8;
	int i;

	s2 = [NSString stringWithCharacters:ubuf length:sizeof(ubuf)/sizeof(unichar)];
	utf8 = [s2 UTF8String];

	for(i=0; i < strlen(utf8); i++)
		printf("%x ", utf8[i]);
	printf("\n");
	printf("%s  strlen %d\n", utf8, strlen(utf8));

	s2 = [NSString stringWithCharacters:decomp length:sizeof(decomp)/sizeof(unichar)];
	utf8 = [s2 UTF8String];

	for(i=0; i < strlen(utf8); i++)
		printf("%x ", utf8[i]);
	printf("\n");
	printf("%s  strlen %d\n", utf8, strlen(utf8));
	}

	s2 = [[NSString alloc] initWithCStringNoCopy:"FooFoo" length:6 freeWhenDone:NO];
	print_string(s2);
	[s2 release];
	s2 = [[NSString alloc] initWithCStringNoCopy:"FooFooFoo" length:9 freeWhenDone:NO];
	print_string(s2);
	[s2 release];

	[arp release];
	printf("string test complete\n");
	exit(0);
}
