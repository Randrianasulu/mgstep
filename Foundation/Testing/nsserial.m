#import <Foundation/Foundation.h>

int kCFPropertyListOpenStepFormat = 0;
int kCFPropertyListXMLFormat_v1_0 = 1;
int kCFPropertyListBinaryFormat_v1_0 = 2;


id makePlistObjects (void)
{
    NSMutableDictionary *top = [NSMutableDictionary dictionary];

    [top setObject: @"Hi I'm a string"  forKey: @"string"];
    [top setObject: [NSNumber numberWithInt: 23]  forKey: @"number"];
    [top setObject: [NSNumber numberWithInt: -46]  forKey: @"negnumber"];
    [top setObject: [NSNumber numberWithDouble: 108.8]  forKey: @"double"];
    [top setObject: [NSNumber numberWithBool: YES]  forKey: @"boolean"];
    [top setObject: [NSDate date]  forKey: @"date"];
//    [top setObject: [NSData dataWithBytes: "badger"  length: 7] forKey: @"data"];

    NSArray *array =
        [NSArray arrayWithObjects: @"I", @"seem", @"to", @"be", @"a", @"verb", nil];
    [top setObject: array  forKey: @"array"];

    NSDictionary *dict =
        [NSDictionary dictionaryWithObjectsAndKeys:
                      @"Ack", @"Oop",
                      @"Bill the Cat", @"It's", nil];
    [top setObject: dict  forKey: @"dictionary"];

    return top;
}

void saveAsOpenStep (id plist)
{
    if (![NSPropertyListSerialization
             propertyList: plist
             isValidForFormat: kCFPropertyListOpenStepFormat]) {
        NSLog (@"can't save as OpenStep prop list");  // can't save as open step any more
 //       return;
    }
    NSError *error;
    NSData *data = 
        [NSPropertyListSerialization dataWithPropertyList: plist
                                     format: kCFPropertyListOpenStepFormat
                                     options: 0
                                     error: &error];
    if (data == nil) {
        NSLog (@"error serializing as OpenStep plist: %@", error);
        return;
    }

 //                            options: NSDataWritingAtomic
    BOOL writeStatus = [data writeToFile: @"plist.plist"
                             options: 0
                             error: &error];
    if (!writeStatus)
        NSLog (@"error writing to file: %@", error);
}

void saveAsXML (id plist)
{
    if (![NSPropertyListSerialization 
             propertyList: plist
             isValidForFormat: kCFPropertyListXMLFormat_v1_0]) {
        NSLog (@"can't save as XML");
        return;
    }

    NSError *error;
    NSData *data = 
        [NSPropertyListSerialization dataWithPropertyList: plist
                                     format: kCFPropertyListXMLFormat_v1_0
                                     options: 0
                                     error: &error];
    if (data == nil) {
        NSLog (@"error serializing to xml: %@", error);
        return;
    }

 //                            options: NSDataWritingAtomic
    BOOL writeStatus = [data writeToFile: @"plist.xml"
                             options: 0
                             error: &error];
    if (!writeStatus)
        NSLog (@"error writing to file: %@", error);
}

void saveAsBinary (id plist)
{
    if (![NSPropertyListSerialization 
             propertyList: plist
             isValidForFormat: kCFPropertyListBinaryFormat_v1_0]) {
        NSLog (@"can't save as binary");
        return;
    }

    NSError *error;
    NSData *data = 
        [NSPropertyListSerialization dataWithPropertyList: plist
                                     format: kCFPropertyListBinaryFormat_v1_0
                                     options: 0
                                     error: &error];
    if (data == nil) {
        NSLog (@"error serializing to xml: %@", error);
        return;
    }

//                             options: NSDataWritingAtomic
    BOOL writeStatus = [data writeToFile: @"plist.bin"
                             options: 0
                             error: &error];
    if (!writeStatus)
        NSLog (@"error writing to file: %@", error);
}

id readFromFile (NSString *path)
{
    NSError *error;
    NSData *data = [NSData dataWithContentsOfFile: path
                           options: 0
                           error: &error];
    if (data == nil) {
        NSLog (@"error reading %@: %@", path, error);
        return nil;
    }

    NSPropertyListFormat format;
    id plist = [NSPropertyListSerialization propertyListWithData: data
                                            options: NSPropertyListImmutable
                                            format: &format
                                            error: &error];

    if (plist == nil) {
        NSLog (@"could not deserialize %@: %@", path, error);
    } else {
        NSString *formatDescription;
        switch (format) {
        case NSPropertyListOpenStepFormat:
            formatDescription = @"openstep";
            break;
        case NSPropertyListXMLFormat_v1_0:
            formatDescription = @"xml";
            break;
        case NSPropertyListBinaryFormat_v1_0:
            formatDescription = @"binary";
            break;
        default:
            formatDescription = @"unknown";
            break;
        }
        NSLog (@"%@ was in %@ format", path, formatDescription);
    }
    
    return plist;
}

void saveAsJSON (id plist)
{
    if (![NSJSONSerialization isValidJSONObject: plist]) {
        NSLog (@"can't save as JSON, invalid JSON");
        return;
    }

    NSError *error;
    NSData *data = 
        [NSJSONSerialization dataWithJSONObject: plist
                             options: NSJSONWritingPrettyPrinted
                             error: &error];
    if (data == nil) {
        NSLog (@"error serializing to json: %@", error);
        return;
    }

    BOOL writeStatus = [data writeToFile: @"plist.json"
                             options: NSDataWritingAtomic
                             error: &error];
    if (!writeStatus)
        NSLog (@"error writing to file: %@", error);
}

id readJSONFile (NSString *path)
{
    NSError *error;
    NSData *data = [NSData dataWithContentsOfFile: path
                           options: 0
                           error: &error];
    if (data == nil) {
        NSLog (@"error reading %@: %@", path, error);
        return nil;
    }

    id plist = [NSJSONSerialization JSONObjectWithData: data
                                    options: NSJSONReadingMutableContainers
                                    error: &error];
    if (plist == nil)
        NSLog (@"could not deserialize %@: %@", path, error);

    return plist;
}


int main (void)
{
//    @autoreleasepool {
	id pool = [[NSAutoreleasePool alloc] init];
	id plist = makePlistObjects ();

	DBLog(@"original plist %@ \n", plist);

	saveAsOpenStep (plist);
	saveAsXML (plist);
	saveAsBinary (plist);

//        id plist2 = readFromFile (@"plist.bin");
 //       NSLog (@"read plist: %@", plist2);

	if (![NSJSONSerialization isValidJSONObject: plist])
		printf ("PASS: JSON is not valid with NSDate\n");
	else
		printf ("FAIL: JSON is valid with NSDate\n");

	// Make JSON-happy.  Can't store dates, but we can store NULLs.
	[plist removeObjectForKey: @"date"];
	[plist setObject: [NSNull null]  forKey: @"null"];

	if (![NSJSONSerialization isValidJSONObject: plist])
		printf ("FAIL: JSON is not valid after removing NSDate\n");

	saveAsJSON (plist);
	id plist3 = readJSONFile (@"plist.json");
	DBLog(@"read JSON: %@ \n", plist3);
	
	if ([plist isEqual: plist3])
		printf ("PASS: saved JSON is identical to origial\n");
	else
		printf ("FAIL: saved JSON is NOT identical to origial\n");

//    }
	[pool release];

    return 0;
}
