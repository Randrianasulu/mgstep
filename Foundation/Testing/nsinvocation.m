/*
   Author:  Per Persson
   Date: 2006
*/ 

#include <Foundation/Foundation.h>
#include <Foundation/NSInvocation.h>
#include <Foundation/NSMethodSignature.h>

struct myarray {
  int a[3];
};

typedef struct _foo {
  int i;
  char *s;
  unsigned long l;
} foo;


@interface NSObject (Broker)

- (float) setAndReturnFloat:(float)flt;
- (double) setAndReturnDouble:(double)dbl;
- (unsigned int) setAndReturnUInt:(unsigned int)ui;
- (unsigned long) setAndReturnULong:(unsigned long)ul;
- (unsigned long long) setAndReturnULongLong:(unsigned long long)ull;
- (unsigned short) setAndReturnUShort:(unsigned short)us;
- (unsigned char) setAndReturnUChar:(unsigned char)uc;
- (id) setAndReturnString:(id)aString;

- (NSRect) setAndReturnNSRect:(NSRect)rect;
- (NSPoint) setAndReturnNSPoint:(NSPoint)point;

- (id) setStructArray:(struct myarray)ma;

- (id) getLong:(out unsigned long*)i;
- (foo*) sendStructPtr:(foo*)f;

- (NSRect) setStructs:(NSRect)r aLong:(unsigned long)ul andPoint:(NSPoint)p;

@end

@interface Broker : NSObject
@end

@interface Agent : NSObject
{
	id _broker;
}

- (void) setBroker:(id)aBroker;

@end


@implementation Broker

- (double) setAndReturnDouble:(double)dbl
{
	printf("setAndReturnDouble %f\n", dbl);
	return dbl + 1;
}

- (float) setAndReturnFloat:(float)flt
{
	printf("setAndReturnFloat %f\n", flt);
	return flt + 1;
}

- (unsigned long long) setAndReturnULongLong:(unsigned long long)ull
{
	printf("setAndReturnULongLong %llu\n", ull);
	return ull;
}

- (unsigned long) setAndReturnULong:(unsigned long)ul
{
	printf("setAndReturnULong %lu\n", ul);
	return ul;
}

- (unsigned int) setAndReturnUInt:(unsigned int)ui
{
	printf("setAndReturnUInt %d\n", ui);
	return ui;
}

- (unsigned short) setAndReturnUShort:(unsigned short)us
{
	printf("setAndReturnUShort %d\n", us);
	return us;
}

- (unsigned char) setAndReturnUChar:(unsigned char)uc
{
	printf("setAndReturnUChar %c\n", uc);
	return uc;
}

- (id) setAndReturnString:(id)aString
{
	printf("setAndReturnString:  %s\n", [aString cString]);
	return aString;
}

- (NSRect) setAndReturnNSRect:(NSRect)r
{
	printf("setAndReturnNSRect:  %2.2f %2.2f  %2.2f %2.2f\n",
		r.origin.x, r.origin.y, r.size.width, r.size.height);
	return r;
}

- (NSPoint) setAndReturnNSPoint:(NSPoint)p
{
	printf("setAndReturnNSPoint:  %2.2f %2.2f\n", p.x, p.y);
	return p;
}

- (id) setStructArray:(struct myarray)ma
{
	printf("setStructArray:  %d %d %d\n", ma.a[0], ma.a[1], ma.a[2]);
	return self;
}

- (id) getLong:(out unsigned long*)i
{
	printf("getLong: received %lu\n", *i);
	*i = 3;
	printf("getLong: return %lu\n", *i);
	return self;
}

- (foo*) sendStructPtr:(foo*)f
{
	printf("sendStructPtr: i=%d s=%s l=%lu\n", f->i, f->s, f->l);
	f->i = 88;
	return f;
}

- (NSRect) setStructs:(NSRect)r aLong:(unsigned long)ul andPoint:(NSPoint)p
{
	printf("setStructs NSRect:  %2.2f %2.2f  %2.2f %2.2f\n",
		r.origin.x, r.origin.y, r.size.width, r.size.height);
	printf("setStructs ULong    %lu\n", ul);
	printf("setStructs NSPoint: %2.2f %2.2f\n", p.x, p.y);
	return r;
}

@end


@implementation Agent

- (void) setBroker:(id)aBroker			{ _broker = [aBroker retain]; }

- (void) forwardInvocation:(NSInvocation *)invocation
{
    SEL aSelector = [invocation selector];
 
    if ([_broker respondsToSelector:aSelector])
        [invocation invokeWithTarget:_broker];
    else
        [super forwardInvocation:invocation];
}

- (NSMethodSignature *) methodSignatureForSelector:(SEL)aSelector
{
	return [_broker methodSignatureForSelector: aSelector];
}

@end



int main (int argc, const char * argv[])
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    void *data;
    id anObject;

    SEL selector = @selector(description);
    NSObject *obj = [[NSObject alloc] init];

    NSMethodSignature *signature = [obj methodSignatureForSelector:selector];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    [invocation setSelector:selector];
    [invocation setTarget:obj];
    printf("Created invocation: returnType = \"%s\", returnLength = %d\n",
	  [[invocation methodSignature] methodReturnType], [[invocation methodSignature] methodReturnLength]);

//[obj description];
    [invocation invoke];
    data = (void *)malloc([[invocation methodSignature] methodReturnLength]);
    [invocation getReturnValue:data];
    printf("Received data at 0x%08x, isa-pointer (at 0x%08x)\n", data, *(id *)data);
    anObject = *(id *)data;
    NSLog(@"Result is @\"%@\" of class %@ (type is %s)", 
	  anObject, [anObject class], [[invocation methodSignature] methodReturnType]);

	{
    SEL selector = @selector(stringByAppendingString:);
    NSString *x = [@"Target string" mutableCopy];
    NSString *arg1 = @" + Static string"; 
    NSMethodSignature *signature = [x methodSignatureForSelector:selector];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    [invocation setSelector:selector];
    [invocation setTarget:x];
    [invocation setArgument:&arg1 atIndex:2];
    [invocation invoke];

    printf("Created invocation: returnType = \"%s\", returnLength = %d\n",
	  [[invocation methodSignature] methodReturnType], [[invocation methodSignature] methodReturnLength]);

    data = (void *)malloc([[invocation methodSignature] methodReturnLength]);
    [invocation getReturnValue:data];
    printf("Received data at 0x%08x, isa-pointer (at 0x%08x)\n", data, *(id *)data);
    anObject = *(id *)data;
    NSLog(@"Result is @\"%@\" of class %@ (type is %s)", 
	  anObject, [anObject class], [[invocation methodSignature] methodReturnType]);
	}

	{
	NSRect r = (NSRect){{0,1},{2,-3}};
	NSRect or = {0};
    SEL selector = @selector(setAndReturnNSRect:);
	Broker *x = [Broker new];
    NSMethodSignature *signature = [x methodSignatureForSelector:selector];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    [invocation setSelector:selector];
    [invocation setTarget:x];
    [invocation setArgument:&r atIndex:2];
    [invocation invoke];
    [invocation getArgument:&or atIndex:2];
	printf("   Returned NSRect:  %2.2f %2.2f  %2.2f %2.2f\n",
			or.origin.x, or.origin.y, or.size.width, or.size.height);
	}

	{
	struct myarray msa = { 1, 2, -3 };
    SEL selector = @selector(setStructArray:);
	Broker *x = [Broker new];
    NSMethodSignature *signature = [x methodSignatureForSelector:selector];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    [invocation setSelector:selector];
    [invocation setTarget:x];
    [invocation setArgument:&msa atIndex:2];
    [invocation invoke];
//    [invocation getArgument:&or atIndex:2];
	}

	{
	foo f = {99, "cow", 9876543};
	foo *p = &f;
    SEL selector = @selector(sendStructPtr:);
	Broker *x = [Broker new];
    NSMethodSignature *signature = [x methodSignatureForSelector:selector];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    [invocation setSelector:selector];
    [invocation setTarget:x];
    [invocation setArgument:&p atIndex:2];
    [invocation invoke];
//    [invocation getArgument:&or atIndex:2];
	}

	printf("\n## Forwarding Invocation tests\n\n");
	{
	Agent *a = [Agent new];
	NSString *s = nil;
	NSString *q =  @"What is foo ?";
	unsigned int rui, ui = 42;
	NSRect r = {0};
	NSPoint p = {0};
	unsigned long ul = 4UL;
	foo f = {99, "cow", 9876543};
	foo *fp;

	[a setBroker: [Broker new]];
	s = [a setAndReturnString: q];
	if ([s isEqualToString: q])
		printf("PASS setAndReturnString is equal to input\n");
	else
		printf("FAIL Return is @\"%@\" of class\n", s, [s class]);
	if ((rui = [a setAndReturnUInt: ui]) == ui)
		printf("PASS setAndReturnUInt is equal to input\n");
	else
		printf("FAIL unsigned int return is %u\n", rui);
	printf("______ReturnDouble %f\n", [a setAndReturnDouble: 1234.5678]);
	printf("______ReturnFloat %f\n", [a setAndReturnFloat: 753.210]);
	printf("______ReturnUChar %c\n", [a setAndReturnUChar: 'A']);
	printf("______ReturnUShort %d\n", [a setAndReturnUShort: 123]);
	printf("______ReturnULong %lu\n", [a setAndReturnULong: 123456789000]);
	printf("______ReturnULong %lu\n", [a setAndReturnULong: ULONG_MAX - 1]);
	printf("______ReturnULongLong %llu\n", [a setAndReturnULongLong: ULLONG_MAX - 1]);
	r = [a setAndReturnNSRect: (NSRect){{88,1},{2,3}}];
	printf("______ReturnNSRect   %2.2f %2.2f  %2.2f %2.2f\n",
		r.origin.x, r.origin.y, r.size.width, r.size.height);
	p = [a setAndReturnNSPoint: (NSPoint){44,-1}];
	printf("______ReturnNSPoint   %2.2f %2.2f\n", p.x, p.y);
	[a getLong: &ul];
	printf("getLong:   %lu\n", ul);
	fp = [a sendStructPtr: &f];
	printf("____StructPtr: i=%d s=%s l=%lu\n", fp->i, fp->s, fp->l);
	r = [a setStructs:(NSRect){{0,-1},{2,3}} aLong:4UL andPoint:(NSPoint){5,6}];
	printf("______ReturnNSRect   %2.2f %2.2f  %2.2f %2.2f\n",
		r.origin.x, r.origin.y, r.size.width, r.size.height);
	}

    [pool release];
	printf("nsinvocation test complete\n");

    return 0;
}
