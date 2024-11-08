#include <stdio.h>
#include <Foundation/NSString.h>
#include <CoreFoundation/CFBase.h>
#include <CoreFoundation/CFString.h>
#include <Foundation/NSAutoreleasePool.h>


int
main ()
{
	id pool = [[NSAutoreleasePool alloc] init];

	unsigned char m0[] = {0x0A};
	unsigned char m1[] = {0xC0, 0x8A};
	unsigned char m2[] = {0xE0, 0x80, 0x8A};
	unsigned char m3[] = {0xF0, 0x80, 0x80, 0x8A};
	unsigned char m4[] = {0xF8, 0x80, 0x80, 0x80, 0x8A};
	unsigned char m5[] = {0xFC, 0x80, 0x80, 0x80, 0x80, 0x8A};

	unsigned char m6[] = {0xfc, 0x80, 0x80, 0x80, 0x80, 0xaf};
	unsigned char m7[] = {0xC0, 0xaf};

	unsigned char m8[] = {0xfc, 0x83, 0xbf, 0xbf, 0xbf, 0xbf};
	unsigned char m9[] = {0x6c, 0x6f, 0x73, 0x74, 0xbf, 0x79, 0x74, 0x65, 0x00 };

	char buf[512] = {0};
	CFRange r = {0,1};
	CFString st = {0};
	CFStringRef s = (CFStringRef)&st;
	UInt32 u4;
	unsigned char *p = (unsigned char *)&u4;
	int i, j;
	CFIndex k;

	st._cString = (char *)m0;
	st._count = 1;
	j = CFStringGetBytes(s, r, NSUTF32StringEncoding, 0, 0, p, 4, NULL);
	printf ("CFStringGetBytes consumed %d **** UCS-4 %x\n", j, u4);
	u4 = 0;

	st._cString = (char *)m1;
	st._count = 2;
	j = CFStringGetBytes(s, r, NSUTF32StringEncoding, 0, 0, p, 4, NULL);
	printf ("CFStringGetBytes consumed %d **** UCS-4 %x\n", j, u4);
	u4 = 0;

	st._cString = (char *)m2;
	st._count++;
	j = CFStringGetBytes(s, r, NSUTF32StringEncoding, 0, 0, p, 4, NULL);
	printf ("CFStringGetBytes consumed %d **** UCS-4 %x\n", j, u4);
	u4 = 0;

	st._cString = (char *)m3;
	st._count++;
	j = CFStringGetBytes(s, r, NSUTF32StringEncoding, 0, 0, p, 4, NULL);
	printf ("CFStringGetBytes consumed %d **** UCS-4 %x\n", j, u4);
	u4 = 0;

	st._cString = (char *)m4;
	st._count++;
	j = CFStringGetBytes(s, r, NSUTF32StringEncoding, 0, 0, p, 4, NULL);
	printf ("CFStringGetBytes consumed %d **** UCS-4 %x\n", j, u4);
	u4 = 0;

	st._cString = (char *)m5;
	st._count++;
	j = CFStringGetBytes(s, r, NSUTF32StringEncoding, 0, 0, p, 4, NULL);
	printf ("CFStringGetBytes consumed %d **** UCS-4 %x\n", j, u4);

	st._cString = (char *)m6;
	st._count = 6;
	j = CFStringGetBytes(s, r, NSUTF32StringEncoding, 0, 0, p, 4, NULL);
	printf ("CFStringGetBytes consumed %d **** UCS-4 %x\n", j, u4);

	st._cString = (char *)m7;
	st._count = 2;
	j = CFStringGetBytes(s, r, NSUTF32StringEncoding, 0, 0, p, 4, NULL);
	printf ("CFStringGetBytes consumed %d **** UCS-4 %x\n", j, u4);

	st._cString = (char *)m8;
	st._count = 6;
	j = CFStringGetBytes(s, r, NSUTF32StringEncoding, 0, 0, p, 4, NULL);
	printf ("CFStringGetBytes consumed %d **** UCS-4 %x\n", j, u4);

	st._cString = (char *)m9;
	st._count = 9;
	r.length = 9;
	p = buf;
	j = CFStringGetBytes(s, r, NSUTF32StringEncoding, '#', 0, p, 9*4, &k);
	printf ("CFStringGetBytes consumed %d use %d UTF-8: %s UCS-4: ", j, k, m9);
	for (i = 0; i < st._count; i++)
		printf ("%c", buf[i*4]);
	printf ("\n");

	memset(buf, 0, 9*4);
	j = CFStringGetBytes(s, r, NSUTF32StringEncoding, 0, 0, p, 9*4, &k);
	printf ("CFStringGetBytes consumed %d use %d UTF-8: %s UCS-4: ", j, k, m9);
	for (i = 0; i < st._count; i++)
		printf ("%c", buf[i*4]);
	printf ("\n");

	memset(buf, 0, 9*4);
	s = (CFStringRef)@"*mGSTEP*";
	j = CFStringGetBytes(s, r, NSUTF32StringEncoding, 0, 0, p, 9*4, &k);
	printf ("CFStringGetBytes consumed %d use %d UCS-4: ", j, k);
	for (i = 0; i < j; i++)
		printf ("%c", buf[i*4]);
	printf ("\n");

	[pool release];
	printf("cfstring test complete\n");

	return 0;
}
