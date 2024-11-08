/*
   tableview.m

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#import <AppKit/AppKit.h>


@interface Controller : NSObject
{
	id table;
	id tableData;
	NSRect viewFrame;
	NSImage *URL;
}

- (void) sortData;

@end

@implementation Controller

- (void) applicationDidFinishLaunching:(NSNotification *)aNotification
{
	NSTableColumn *theColumn;
	id prototypeCell;
	NSWindow *window;
	NSRect winRect = {{100, 100}, {500, 300}};
	NSRect f = {{0, 0}, {800, 400}};
	NSScrollView *scrollView;
	NSRect scrollViewRect = {{10, 10}, {480, 280}};
	NSString *p = [[NSBundle mainBundle] pathForResource:@"data" ofType:@"plist"];

    tableData = [[NSArray arrayWithContentsOfFile:p] retain];
	window = [[NSWindow alloc] initWithContentRect:winRect
							   styleMask:_NSCommonWindowMask
							   backing:NSBackingStoreBuffered
							   defer:NO];
	[window setTitle:@"mGSTEP TableView"];

	table = [[NSTableView alloc] initWithFrame:f];

    theColumn = [[NSTableColumn alloc] initWithIdentifier:@"URL"];
    [[theColumn headerCell] setStringValue:@"URL"];
    [[theColumn dataCell] setImage:nil];
    [theColumn setWidth:24];
    [theColumn setMinWidth:24];
    [theColumn setMaxWidth:24];
    [table addTableColumn:theColumn];

    theColumn = [[NSTableColumn alloc] initWithIdentifier:@"Title"];
    [[theColumn headerCell] setStringValue:@"Title"];
    [theColumn setWidth:130];
    [theColumn setMinWidth:24];
    [theColumn setEditable:YES];
    [theColumn setResizable:YES];
    [table addTableColumn:theColumn];

    theColumn = [[NSTableColumn alloc] initWithIdentifier:@"Author"];
    [[theColumn headerCell] setStringValue:@"Author"];
    [theColumn setWidth:110];
    [theColumn setMaxWidth:150];
    [theColumn setResizable:YES];
    [table addTableColumn:theColumn];

    theColumn = [[NSTableColumn alloc] initWithIdentifier:@"ArticleType"];
    [[theColumn headerCell] setStringValue:@"ArticleType"];
    [theColumn setWidth:70];
    [table addTableColumn:theColumn];

    theColumn = [[NSTableColumn alloc] initWithIdentifier:@"Description"];
    [[theColumn headerCell] setStringValue:@"Description"];
    [theColumn setWidth:300];
    [table addTableColumn:theColumn];

    theColumn = [[NSTableColumn alloc] initWithIdentifier:@"Date"];
    [[theColumn headerCell] setStringValue:@"Date"];
    [theColumn setWidth:80];
    [table addTableColumn:theColumn];

 //   prototypeCell = [NSImageCell new];
    
    [table setDoubleAction:@selector(openUrl:)];
    [table setTarget:self];
    [table setDataSource:self];

 //   [theColumn setDataCell:prototypeCell];

	URL = [NSImage imageNamed:@"URL"];

	scrollView = [[NSScrollView alloc] initWithFrame:scrollViewRect];
	[scrollView setHasHorizontalScroller:YES];
	[scrollView setHasVerticalScroller:YES];
	[scrollView setDocumentView:table];
	[[window contentView] addSubview:scrollView];
    
    [self sortData];
//	[scrollView display];
	[[window contentView] display];
	[window makeKeyAndOrderFront:nil];
}

- (id) tableView:(NSTableView *)aTableView
	   objectValueForTableColumn:(NSTableColumn *)aTableColumn 
	   row:(int)row
{
	NSMutableDictionary *theRecord;
	NSString *columnIdentifier = [aTableColumn identifier];

    NSParameterAssert(row >= 0 && row < [tableData count]);

    if ([columnIdentifier isEqual:@"URL"])
        return URL;

    theRecord = [tableData objectAtIndex:row];

    return [theRecord objectForKey:columnIdentifier];
}

- (void) tableView:(NSTableView *)tableView 
		 setObjectValue:(id)anObject 
		 forTableColumn:(NSTableColumn *)aTableColumn 
		 row:(int)row
{
	NSMutableDictionary *theRecord;

    NSParameterAssert(row >= 0 && row < [tableData count]);

    theRecord = [tableData objectAtIndex:row];
    [theRecord setObject:[anObject retain] forKey:[aTableColumn identifier]];
}

- (int) numberOfRowsInTableView:(NSTableView *)aTableView
{
    return [tableData count];
}

- (void) tableViewColumnDidMove:(NSNotification *)aNotification
{
    [self sortData];
}

- (void) sortData
{
	NSMutableArray *columnOrdering;
	NSArray *columns;
	NSTableColumn *eachColumn;
	NSEnumerator *columnEnumerator;

    columnOrdering = [NSMutableArray array];
    columns = [table tableColumns];
    columnEnumerator = [columns objectEnumerator];
/*
    while (eachColumn = [columnEnumerator nextObject])
      {
        EOSortOrdering *tempOrder;

        tempOrder=[EOSortOrdering sortOrderingWithKey:[eachColumn identifier] selector:EOCompareAscending];
        [columnOrdering addObject:tempOrder];
      }
    [self setDataArray:[tableData 	
			sortedArrayUsingKeyOrderArray:columnOrdering]];
*/

    [table reloadData];
}

- (void) dealloc;
{
    [table release];
    [tableData release];
    [super dealloc];
}

- (id) openUrl:sender;
{
	if ([table selectedRow] > -1)
		{
		NSMutableDictionary *r = [tableData objectAtIndex:[table selectedRow]];
		NSString *urlString = [r objectForKey:@"URL"];

//        [self performSelector: @selector(performOpenUrl:) 
//			  withObject: urlString 
//			  afterDelay: 0.0];
		}

	return self;
}

- (id) performOpenUrl:(NSString *)urlName;
{
	NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
	NSString *service = [standardUserDefaults stringForKey:@"URLService"];
	NSPasteboard *pb = [NSPasteboard pasteboardWithName:@"URLServicePasteboard"];
	NSArray *urlPboardTypes = [NSArray arrayWithObjects:NSStringPboardType, nil];

    [pb declareTypes:urlPboardTypes owner:nil];
    [pb setString:urlName forType:NSStringPboardType];

    if(service == nil)
        service = @"OmniWeb/Open URL";
    NSPerformService(service, pb);

    return self;
}

@end
