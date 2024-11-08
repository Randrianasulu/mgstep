
#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSConnection.h>
#include <Foundation/NSDistantObject.h>
#include <Foundation/NSString.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSAutoreleasePool.h>

#include "Stream.h"
#include "server.h"

@implementation Server

- init
{
	the_array = [[NSMutableArray alloc] init];
	return self;
}

- (NSUInteger) count			{ return [the_array count]; }
- (void) addObject: o			{ [the_array addObject:o]; }
- objectAt: (unsigned)i			{ return [the_array objectAtIndex: i]; }

- print:(const char *)msg
{
	printf(">>%s\n", msg);
	return self;
}

- getLong:(out unsigned long*)i
{
  printf(">>getLong:(out) from client %lu\n", *i);
  *i = 3;
  printf(">>getLong:(out) to client %lu\n", *i);
  return self;
}

- (oneway void) shout
{
  printf(">>Ahhhhh\n");
  return;
}

- callbackNameOn: obj
{
  printf (">>callback name is (%s)\n", object_get_class_name (obj));
  return self;
}
/* sender must also respond to 'bounce:count:' */
- bounce: sender count: (int)c
{
  if (--c)
    [sender bounce:self count:c];
  return self;
}
- (BOOL) doBoolean: (BOOL)b
{
  printf(">> got boolean '%c' (0x%x) from client\n", b, (unsigned int)b);
  return YES;
}
/* This causes problems, because the runtime encodes this as "*",
   a string! */
- getBoolean: (BOOL*)bp
{
  printf(">> got boolean pointer '%c' (0x%x) from client\n", 
	 *bp, (unsigned int)*bp);
  return self;
}
/* This also causes problems, because the runtime also encodes this as "*",
   a string! */
- getUCharPtr: (unsigned char *)ucp
{
  printf(">> got unsignec char pointer '%c' (0x%x) from client\n", 
	 *ucp, (unsigned int)*ucp);
  return self;
}

- (oneway void) outputStats:obj
{
id c = [obj connectionForProxy];
id o = [c statistics];
id a = [o allKeys];
int j;

  printf("Number of connections - %d\n", [[NSConnection allConnections] count]);
  printf("This connection -\n");
  for (j = 0; j < [a count]; j++)
    {
      id k = [a objectAtIndex:j];
      id v = [o objectForKey:k];
      printf("%s - %s\n", [k cString], [[v description] cString]);
    }
}

/* This isn't working yet */
- (foo*) sendStructPtr: (foo*)f
{
  printf(">>reference: i=%d s=%s l=%lu\n",
	 f->i, f->s, f->l);
  f->i = 88;
  return f;
}
- sendStruct: (foo)f
{
  printf(">>value: i=%d s=%s l=%lu\n",
	 f.i, f.s, f.l);
  f.i = 88;
  return self;
}
- sendSmallStruct: (small_struct)small
{
  printf(">>small value struct: z=%d\n", small.z);
  return self;
}
- (foo) returnStruct
{
  foo f = {1, "horse", 987654};
  return f;
}
- (small_struct) returnSmallStruct
{
  small_struct f = {22};
  return f;
}
- (foo) returnSetStruct: (int)x
{
  foo f = {1, "horse", 987654};
  f.l = x;
  return f;
}
- (small_struct) returnSetSmallStruct: (int)x
{
  small_struct f = {22};
  f.z = x;
  return f;
}
/* Doesn't work because GCC generates the wrong encoding: "@0@+8:+12^i+16" */
- sendArray: (int[3])a
{
  printf(">> array %d %d %d\n", a[0], a[1], a[2]);
  return self;
}
- sendStructArray: (struct myarray)ma
{
  printf(">>struct array %d %d %d\n", ma.a[0], ma.a[1], ma.a[2]);
  return self;
}

- sendDouble: (double)d andFloat: (float)f
{
  printf(">> double %f, float %f\n", d, f);
  return self;
}

- (double*) doDoublePointer: (double*)d
{
  printf(">> got double %f from client\n", *d);
  *d = 1.234567;
  printf(">> returning double %f to client\n", *d);
  return d;
}

- sendCharPtrPtr: (char**)sp
{
  printf(">> got char**, string %s\n", *sp);
  return self;
}

- sendBycopy: (bycopy id)o
{
  printf(">> bycopy class is %s\n", object_get_class_name (o));
  return self;
}
#ifdef	_F_BYREF
- sendByref: (byref id)o
{
  printf(">> byref class is %s\n", object_get_class_name (o));
  return self;
}
#endif
- manyArgs: (int)i1 : (int)i2 : (int)i3 : (int)i4 : (int)i5 : (int)i6
: (int)i7 : (int)i8 : (int)i9 : (int)i10 : (int)i11 : (int)i12
{
  printf(">> manyArgs: %d %d %d %d %d %d %d %d %d %d %d %d\n",
	 i1, i2, i3, i4, i5, i6, i7, i8, i9, i10, i11, i12);
  return self;
}

- (void) setPoint:(NSPoint)point
{
  printf(">> got point %f %f from client\n", point.x, point.y);
}

- (float) returnFloat
{
  static float f = 2.3456789f;
  return f;
}

- (double) returnDouble
{
  /* static <This is crashing gcc ss-940902 config'ed for irix5.1, 
     but running on irix5.2> */
  double d = 4.567891234;
  return d;
}

- (id) connectionBecameInvalid:(NSNotification*)notification
{
id anObj = [notification object];

	NSLog(@"- connectionBecameInvalid");
	if ([anObj isKindOfClass:[NSConnection class]])
		{
		int i, count = [the_array count];

		for (i = count-1; i >= 0; i--)
			{
			id o = [the_array objectAtIndex: i];

			if ([o isProxy] && [o connectionForProxy] == anObj)
				[the_array removeObjectAtIndex: i];
			}
		if (count != [the_array count])
			printf("$$$$$ connectionBecameInvalid: removed from the_array\n");
		}
	else
		[self error:"non Connection is invalid"];

	return self;
}

- (id) connectionDidInit:(NSNotification*)notification
{
id anObj = [notification object];

	NSLog(@"- connectionDidInit %#x", anObj);
	return self;
}

@end

int main(int argc, char *argv[])
{
	id s = [[Server alloc] init];
	id o = [[NSObject alloc] init];
	double d;
	NSConnection *c;
	NSAutoreleasePool *arp = [NSAutoreleasePool new];
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	NSString *n;

	[BinaryCStream _setDebugging:YES];

//	[NSDistantObject setProtocolForProxy:@protocol(ServerProtocol)];

	if (argc > 1)
		n = [NSString stringWithCString: argv[1]];
	else
		n = @"test2server";

	[nc addObserver: s
		selector: @selector(connectionDidInit:)
		name: NSConnectionDidInitializeNotification
		object: nil];

	[(c = [NSConnection defaultConnection]) setRootObject:s];
	if ([c registerName:n] == NO)
		NSLog(@"server error while registering connection name %@",n);

	[nc addObserver: s
		selector: @selector(connectionBecameInvalid:)
		name: NSConnectionDidDieNotification
		object: nil];

	[c setDelegate:s];
	[s addObject: o];
	d = [s returnDouble];
	printf("got double %f\n", d);
	printf("list's hash is 0x%x\n", (unsigned)[s hash]);
	printf("object's hash is 0x%x\n", (unsigned)[o hash]);
	
	[[NSRunLoop currentRunLoop] run];
	
	[arp release];

	exit(0);
}
