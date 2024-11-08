/*
   NSHost.m

   Host properties abstraction class

   Copyright (C) 1996-2019 Free Software Foundation, Inc.

   Author:	Luke Howard <lukeh@xedoc.com.au> 
   Date:	1996

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSHost.h>
#include <Foundation/NSLock.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSString.h>
#include <Foundation/NSCoder.h>

#include <sys/param.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>



@implementation NSHost

+ (NSHost *) currentHost
{
	char name[MAXHOSTNAMELEN];
	
	if (gethostname(name, sizeof(name)) < 0)
		return _NSLogError(@"Unable to determine current host's name");

	return [self hostWithName: [NSString stringWithCString:name]];
}

+ (NSHost *) _withHostent:(struct hostent *)ht
					 name:(NSString *)name
				  address:(NSString *)address
{
	NSHost *h = [[self alloc] autorelease];

	h->_names = [[NSMutableArray array] retain];
	h->_addresses = [[NSMutableArray array] retain];

	if (name != nil)
		[h->_names addObject:name];

	if (ht != (struct hostent *)NULL)
		{
		int i;
		char *p;

		if (name == nil)
			[h->_names addObject:[NSString stringWithCString:ht->h_name]];
		else
			{
			NSString *h_name = [NSString stringWithCString:ht->h_name];

			if (![h_name isEqual:name])
				[h->_names addObject:h_name];
			}
		
		p = ht->h_aliases[0];
		for (i = 0; p != NULL; i++, p = ht->h_aliases[i])
			[h->_names addObject:[NSString stringWithCString:p]];
	
		p = ht->h_addr_list[0];
		for (i = 0; p != NULL; i++, p = ht->h_addr_list[i])
			{
			char buf[INET6_ADDRSTRLEN+1] = {0};
			const char *na = NULL;

			if (ht->h_addrtype == AF_INET)
				{
				struct in_addr n;

				memcpy((void *)&n.s_addr, (const void *)p, ht->h_length);
				na = inet_ntop(ht->h_addrtype, &n, buf, INET_ADDRSTRLEN);
				}
			else
				{
				struct in6_addr n6;

				memcpy((void *)&n6.s6_addr, (const void *)p, ht->h_length);
				na = inet_ntop(ht->h_addrtype, &n6, buf, INET6_ADDRSTRLEN);
				}

			if (na != NULL)
				[h->_addresses addObject: [NSString stringWithCString: na]];
			}
		}
	else if (address != nil)
		[h->_addresses addObject:address];

	return h;
}

+ (NSHost *) hostWithName:(NSString *)name
{
	struct hostent *h;

	if (name == nil)
		return _NSLogError(@"nil host name");

	if ((h = gethostbyname((char *)[name cString])) == NULL)
		NSLog(@"Host '%@' not found: (%d) %s", name, h_errno, hstrerror(h_errno));
	
	return [self _withHostent:h name:name address:nil];
}

+ (NSHost *) hostWithAddress:(NSString *)address
{
	struct hostent *h;
	struct {  struct in_addr  a;
			  struct in6_addr a6; } u;
	int r, type = AF_INET;
	int size = sizeof(struct in_addr);
	const char *cs = [address cString];
	char *p;

	if (address == nil || strlen(cs) < 4)
		return _NSLogError(@"Invalid or nil address");

	if ((p = strchr(cs, ':')) && (strchr(++p, ':')))		// 2 or more ':'
		{													// IPv6
		r = inet_pton(AF_INET6, cs, &u.a6);
		size = sizeof(struct in6_addr);
		type = AF_INET6;
		}
	else
		r = inet_aton(cs, &u.a);

	if (r != 1)
		return _NSLogError(@"%@ address conversion failed '%s'",
						 ((type == AF_INET) ? @"IPv4" : @"IPv6") , cs);

	if ((h = gethostbyaddr(&u, size, type)) == NULL)
		NSLog(@"Host not found for address '%@': (%d) %s",
				address, h_errno, hstrerror(h_errno));

	return [self _withHostent:h name:nil address:address];
}

- (id) init												 { return nil; }
- (id) replacementObjectForPortCoder:(NSPortCoder*)coder { return self; }

- (void) dealloc
{
	[_names release];
	[_addresses release];
	[super dealloc];
}

/*
	The OpenStep spec says that [-hash] must be the same for any two
	objects that [-isEqual:] returns YES for.  We have a problem in
	that [-isEqualToHost:] is specified to return YES if any name or
	address part of two hosts is the same.  That means we can't
	reasonably calculate a hash since two hosts with radically
	different ivar contents may be 'equal'.  The best I can think of
	is for all hosts to hash to the same value - which makes it very
	inefficient to store them in a set, dictionary, map or hash table.
*/
- (NSUInteger) hash
{
	return 1;
}

- (BOOL) isEqual:(id)other
{
	if (other == self)
		return YES;
	if ([other isKindOfClass: [NSHost class]])
		return [self isEqualToHost: (NSHost*)other];
	return NO;
}

- (BOOL) isEqualToHost:(NSHost *)aHost
{
	NSArray *a;
	int i, count;

	if (aHost == self)
		return YES;
	
	a = [aHost addresses];
	for (i = 0, count = [a count]; i < count; i++)
		if ([_addresses containsObject:[a objectAtIndex:i]])
			return YES;
	
	a = [aHost names];
	for (i = 0, count = [a count]; i < count; i++)
		if ([_addresses containsObject:[a objectAtIndex:i]])
			return YES;
	
	return NO;
}

- (NSString*) name						{ return [_names objectAtIndex:0]; }
- (NSArray *) names						{ return _names; }
- (NSString*) address					{ return [_addresses objectAtIndex:0];}
- (NSArray *) addresses					{ return _addresses ; }

- (NSString *) description
{
	return [NSString stringWithFormat:@"Host %@ (%@ %@)", 
										[self name],
										[[self names] description], 
										[[self addresses] description]];
}

@end
