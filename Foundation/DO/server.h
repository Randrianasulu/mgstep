#ifndef _server_h
#define _server_h

#include <Foundation/NSArray.h>
#include <Foundation/NSGeometry.h>

typedef struct _small_struct {
  unsigned char z;
} small_struct;

typedef struct _foo {
  int i;
  char *s;
  unsigned long l;
} foo;

struct myarray {
  int a[3];
};
 
@protocol ServerProtocol 
- (void) addObject: o;
- objectAt: (unsigned)i;
- (NSUInteger) count;
- print: (const char *)msg;
- getLong: (out unsigned long*)i;
- (oneway void) shout;
- callbackNameOn: obj;
- bounce: sender count: (int)c;
- (BOOL) doBoolean: (BOOL)b;
- getBoolean: (BOOL*)bp;
- getUCharPtr: (unsigned char *)ucp;
- (oneway void) outputStats:obj;
- (foo*) sendStructPtr: (foo*)f;
- sendStruct: (foo)f;
- sendSmallStruct: (small_struct)small;
- (foo) returnStruct;
- (foo) returnSetStruct: (int)x;
- (small_struct) returnSmallStruct;
- (small_struct) returnSetSmallStruct: (int)x;
- sendArray: (int[3])a;
- sendStructArray: (struct myarray)ma;
- sendDouble: (double)d andFloat: (float)f;
- (double*) doDoublePointer: (double*)d;
- (void) setPoint:(NSPoint)point;
- sendCharPtrPtr: (char**)sp;
- sendBycopy: (bycopy id)o;
#ifdef	_F_BYREF
- sendByref: (byref id)o;
#endif
- manyArgs: (int)i1 : (int)i2 : (int)i3 : (int)i4 : (int)i5 : (int)i6
: (int)i7 : (int)i8 : (int)i9 : (int)i10 : (int)i11 : (int)i12;
- (float) returnFloat;
- (double) returnDouble;
@end

@interface Server : NSObject <ServerProtocol>
{
  id the_array;
}
@end

#endif /* _server_h */
