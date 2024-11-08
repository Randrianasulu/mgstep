#include <Foundation/NSFileManager.h>
#include <Foundation/NSString.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSEnumerator.h>
#include <Foundation/NSAutoreleasePool.h>

int main(int argc, char *argv[]) 
{
NSAutoreleasePool *arp = [NSAutoreleasePool new];
NSFileManager *fm = [NSFileManager defaultManager];
NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath:@"./"];
NSString *file;
NSDictionary *d;
NSArray *a;

	printf("Enumerate files at: ./\n");
	while (file = [enumerator nextObject])
		printf("  %s\n",[file cString]);

	printf("directoryContentsAtPath: ./\n");
	a = [fm directoryContentsAtPath:@"./"];
	printf("%s\n",[[a description] cString]);

	printf("subpathsAtPath: ../\n");
	a = [fm subpathsAtPath:@"../"];
	printf("%s\n",[[a description] cString]);

	d = [fm fileSystemAttributesAtPath:@"./"];
	printf("%s\n",[[d description] cString]);

	[arp release];
	printf("nsfilemanager test complete\n");
	
	exit(0);
}
