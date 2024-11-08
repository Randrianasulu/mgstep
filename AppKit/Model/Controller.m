#import "Controller.h"


@implementation Controller

- (void) awakeFromNib;
{
	[_copyright setStringValue: @"Copy Left or Right"];
	[_copyright display];
}

- (void) buttonPressed:(id)sender
{
	NSString *text;

	text = [NSString stringWithFormat:@"\"%@\" button pressed",[sender title]];

	[textField setStringValue:text];
}

- (NSWindow *) window				{ return [textField window]; }

@end


@implementation MyView

- (void) drawRect:(NSRect)rect
{
	[[NSColor greenColor] set];
	NSRectFill (rect);
}

@end
