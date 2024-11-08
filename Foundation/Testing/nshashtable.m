#include <stdio.h>
#include <Foundation/NSHashTable.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSAutoreleasePool.h>

int main ()
{
	NSHashTable *ht;
	NSHashEnumerator he;
	int i;
	void *v;
	NSAutoreleasePool *arp = [NSAutoreleasePool new];

  /* Test with ints */

	ht = NSCreateHashTable (NSIntHashCallBacks, 0);
	
	printf ("Inserting integers into hashtable \n");
	for (i = 1; i < 16; i++)
		NSHashInsert (ht, INT2PTR(i));
	
	printf ("Removing integer 3 from hashtable \n");
	NSHashRemove (ht, INT2PTR(3));
	
	printf ("Enumerating hashtable \n");
	he = NSEnumerateHashTable (ht);
	while ((v = NSNextHashEnumeratorItem (&he)))
		printf ("(%d) ", PTR2INT(v));
	printf ("\n");
	
	NSFreeHashTable (ht);
	
	[arp release];
	printf("nshashtable test complete\n");
	exit (0);
}
