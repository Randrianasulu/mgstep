/*
   Controller.m

   Generic App delegate

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#import <AppKit/AppKit.h>


@interface Controller : NSObject
@end

@implementation Controller (AppDelegate)

- (void) createMenu
{
	NSString *appName = [[NSProcessInfo processInfo] processName];
	NSMenu *menu = [[NSMenu alloc] initWithTitle:appName];
	NSMenu *info = [NSMenu new];
	NSMenu *file = [NSMenu new];
	NSMenu *edit = [NSMenu new];
	NSMenu *find = [NSMenu new];
	NSMenu *windows = [NSMenu new];
	SEL a = @selector(method:);

	[menu addItemWithTitle:appName action:a keyEquivalent:@""];
	[menu addItemWithTitle:@"File" action:0 keyEquivalent:@""];
	[menu addItemWithTitle:@"Edit" action:0 keyEquivalent:@""];
	[menu addItemWithTitle:@"Tools" action:0 keyEquivalent:@""];
	[menu addItemWithTitle:@"Windows" action:0 keyEquivalent:@""];
	[menu addItemWithTitle:@"Help" action:0 keyEquivalent:@"?"];

	[menu setSubmenu:info forItem:[menu itemWithTitle:appName]];
	[info addItemWithTitle:@"About" action:@selector(showInfo:) keyEquivalent:@""];
	[info addItemWithTitle:@"Preferences..."
		  action:@selector(showPreferences:) 
		  keyEquivalent:@""];
	[info addItemWithTitle:@"Services" action:a keyEquivalent:@""];
	[info addItemWithTitle:@"Hide" action:@selector(hide:) keyEquivalent:@"h"];
	[info addItemWithTitle:@"Quit" action:@selector(terminate:) keyEquivalent:@"q"];

	[file addItemWithTitle:@"Open..." action:@selector(open:)
		  keyEquivalent:@"o"];
	[file addItemWithTitle:@"New" action:a keyEquivalent:@"n"];
	[file addItemWithTitle:@"Save" action:@selector(save:) keyEquivalent:@"s"];
	[file addItemWithTitle:@"Save As..." action:@selector(saveAs:) 
		  keyEquivalent:@"S"];
	[file addItemWithTitle:@"Save All" action:a keyEquivalent:@""];
	[file addItemWithTitle:@"Revert to Saved" action:a keyEquivalent:@"u"];
	[file addItemWithTitle:@"Open Selection" action:a keyEquivalent:@"O"];
	[file addItemWithTitle:@"Open Folder..." action:a keyEquivalent:@"D"];
	[file addItemWithTitle:@"Close" action:a keyEquivalent:@""];
	[file addItemWithTitle:@"Print" action:a keyEquivalent:@"p"];
	[menu setSubmenu:file forItem:[menu itemWithTitle:@"File"]];

	[edit addItemWithTitle:@"Add" action:@selector(add:) keyEquivalent:@"+"];
	[edit addItemWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"x"];
	[edit addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
	[edit addItemWithTitle:@"Paste" 
		  action:@selector(paste:) 
		  keyEquivalent:@"v"];
	[menu setSubmenu:edit forItem:[menu itemWithTitle:@"Edit"]];
	[edit addItemWithTitle:@"Delete" action:@selector(delete:) keyEquivalent:@""];
	[edit addItemWithTitle:@"Select All" 
		  action:@selector(selectAll:) 
		  keyEquivalent:@"a"];
	[edit addItemWithTitle:@"Find" action:0 keyEquivalent:@""];
	[edit setSubmenu:find forItem:[edit itemWithTitle:@"Find"]];

	[find addItemWithTitle:@"Find Panel..." action:a keyEquivalent:@"f"];
	[find addItemWithTitle:@"Find Next" action:a keyEquivalent:@"g"];
	[find addItemWithTitle:@"Find Previous" action:a keyEquivalent:@"d"];
	[find addItemWithTitle:@"Enter Selection" action:a keyEquivalent:@"e"];
	[find addItemWithTitle:@"Jump to Selection" action:a keyEquivalent:@"j"];
	[find addItemWithTitle:@"Line Range..." action:a keyEquivalent:@"l"];

	[menu setSubmenu:windows forItem:[menu itemWithTitle:@"Windows"]];
	[windows addItemWithTitle:@"Arrange"
			 action:@selector(arrangeInFront:)
			 keyEquivalent:@""];
	[windows addItemWithTitle:@"Miniaturize"
			 action:@selector(performMiniaturize:)
			 keyEquivalent:@"m"];
	[windows addItemWithTitle:@"Close"
			 action:@selector(performClose:)
			 keyEquivalent:@"w"];

	[NSApp setMainMenu:menu];
	[NSApp setServicesMenu: nil];
}

- (id) init
{
	[[NSApplication sharedApplication] setDelegate: self];	
	[self createMenu];

	return self;
}

#ifdef __APPLE__
+ (NSApplication *) sharedApplication
{
	[Controller new];
	
	return [NSApplication sharedApplication];
}
#endif /* __APPLE__ */

@end


int
main(int argc, const char **argv, char** env)
{
    return NSApplicationMain(argc, argv);
}
