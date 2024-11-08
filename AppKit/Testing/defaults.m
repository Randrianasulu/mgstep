/*
   defaults.m

   Tool to manage a user's defaults database

   Copyright (C) 2005-2016 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:	April 2005

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSString.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSUserDefaults.h>
#include <Foundation/NSProcessInfo.h>
#include <Foundation/NSEnumerator.h>
#include <Foundation/NSArray.h>


void
usage(const char *err_msg, int exit_status)
{
// ./defaults write < ft.plist
// ./defaults readkey FileTypes

	if (exit_status)
		fprintf(stdout, "\nInvalid options, %s.\nUsage:\n\n", err_msg);
	else
		fprintf(stdout, "\n%s\n\n", err_msg);

	fprintf(stdout, " defaults [-h] help        you are here\n");
	fprintf(stdout, " defaults [-v]             print version and exit\n\n");

	fprintf(stdout, " read                      show all defaults\n");
	fprintf(stdout, " read     [domain [key]]   show defaults for domain\n");
	fprintf(stdout, " delete   [domain [key]]   remove domain or key\n");

//	fprintf(stdout, " write  <domain> { 'plist' | key 'value' }\n");
//	fprintf(stdout, " rename <domain> <key>  <new-key>\n");
//	fprintf(stdout, " domains              list all domains \n");
//	fprintf(stdout, " find <word>          search for entries containing word\n");
	fprintf(stdout, "\n");

	exit(exit_status);
}

void
delete_default(NSString *domain, NSString *key)
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSDictionary *pd = [defaults persistentDomainForName:domain];
	id o;

	if (key && (o = [pd objectForKey: key]))
		[(NSMutableDictionary *)pd removeObjectForKey:key];
	else if (pd)
		[defaults removePersistentDomainForName:domain];
	[defaults synchronize];
}

void
print_default(NSUserDefaults *defaults, NSString *domain, NSString *key)
{
	NSDictionary *pd = [defaults persistentDomainForName:domain];

	if (key)
		{
		id o = [pd objectForKey: key];
		printf("%s\n", [[o description] cString]);
		}
	else
		{
		NSEnumerator *e = [pd keyEnumerator];

		printf("%s = {\n", [domain cString]);
		while (key = [e nextObject])
			{
			id o = [pd objectForKey: key];

			printf("%s = ", [key cString]);
			
			if (o)
				printf("%s\n",  [[o description] cString]);
			else
				printf("{};\n");
			}
		printf("};\n");
		}
	printf("\n");
}

void
read_defaults(NSString *domain, NSString *key)
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

//	if (!domain)
//		domain = @"NSGlobalDomain";

	if (domain)
		print_default(defaults, domain, key);
	else
		{
		NSArray *domains = [defaults persistentDomainNames];
		int i, count = [domains count];

		for (i = 0; i < count; i++)
			print_default(defaults, [domains objectAtIndex: i], key);
		printf("\n");
		}
}

void
parse_cmd_line(void)
{
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	NSArray *args = [[NSProcessInfo processInfo] arguments];
	int i, c = [args count];

	for (i = 1; i < c; i++)
		{
		NSString *domain = nil;
		NSString *key = nil;
		NSString *cmd = [args objectAtIndex: i];

		if ([cmd isEqualToString: @"read"])
			{
			if (c > i + 2)
				usage("expected argument after read option", 1);

			if (++i < c)
				domain = [args objectAtIndex: i];
			if (++i < c)
				key = [args objectAtIndex: i];
			read_defaults(domain, key);
			}
		else if ([cmd isEqualToString: @"delete"])
			{
			if (c > i + 2)
				usage("expected argument after delete option", 1);

			if (++i < c)
				domain = [args objectAtIndex: i];
			if (++i < c)
				key = [args objectAtIndex: i];
			delete_default(domain, key);
			}
		else
			usage([[NSString stringWithFormat:@"unknown command: %@", cmd] cString], 1);
		}

    [pool release];
}

int
main(int argc, char **argv, char **env)
{
	extern int optind;
	int c;

	while ((c = getopt(argc, argv, "vh")) != -1)
		switch (c)
			{
			case 'h':		usage("Defaults database tool help:", 0);
			case 'v':		usage("mGSTEP defaults v0.003", 0);
			};

	if (optind >= argc)
		usage("expected argument after options", 1);

	parse_cmd_line();

	exit(0);
}
