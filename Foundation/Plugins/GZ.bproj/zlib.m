/*
   zlib.m

   Copyright (C) 2020 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date: 	November 2020

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSString.h>
#include <Foundation/NSData.h>

#include <zlib.h>
#include <assert.h>


/* ****************************************************************************

		_NSDataDecompressGZ

** ***************************************************************************/

#define CHUNK 16384

static int
DecompressGZ(NSData *source, NSMutableData *dest)
{
    int r;
    z_stream s = {0};
    unsigned char obuf[CHUNK];

    if ((r = inflateInit2(&s, 16)) != Z_OK)				// gzip format
        return r;

	s.next_in = (unsigned char *)[source bytes];
	if (s.next_in && (s.avail_in = [source length]) > 0)
		{
        do {							// decompress until deflate stream ends
            s.avail_out = CHUNK;
            s.next_out = obuf;

            r = inflate(&s, Z_NO_FLUSH);				// inflate() input

            assert(r != Z_STREAM_ERROR);
 			if (r < 0 || r == Z_NEED_DICT)
				{
				inflateEnd(&s);
				return r;
				}

			[dest appendBytes:obuf length: (CHUNK - s.avail_out)];
			}											// if out buf consumed
		while (s.avail_out == 0 && r != Z_STREAM_END);	// but not inflate end
		}

	inflateEnd(&s);										// clean up zlib

    return r == Z_STREAM_END ? Z_OK : r;
}


@implementation NSData  (_NSDataDecompressGZ)

- (id) decompressGZ
{
	NSMutableData *d = [NSMutableData new];
	int r;

	if ((r = DecompressGZ(self, d)) != Z_OK)
		{
		[d release],	d = nil;
		NSLog(@"ZLIB: decompress failed (%d)", r);
		}

    return d;				// FIX ME by convention s/b autoreleased
}

@end
