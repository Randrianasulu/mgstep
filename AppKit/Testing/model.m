/*
   model.m

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#import <AppKit/AppKit.h>


typedef enum
{
	IMNoHandle,
	IMBottomRightHandle,
	IMBottomMiddleHandle,
	IMBottomLeftHandle,
	IMTopRightHandle,
	IMTopMiddleHandle,
	IMTopLeftHandle,
	IMRightMiddleHandle,
	IMLeftMiddleHandle

} IMHandleType;


@interface Controller : NSObject
{
	NSPanel *_simulatorPanel;
	
	NSTextField *textfield;
	BOOL testInterface;
 									
	NSMutableArray *user_models;	// List of user model files (the documents)
}

- (void) showSimulatorPanel:(id)sender;

- (void) method:menuCell;							// temp for sake of menu
- (void) setTestInterface:(id)sender;
- (BOOL) testInterface;

@end


@interface IMModelView : NSView

- (id) hitTestForHandle:(IMHandleType *)handle atPoint:(NSPoint)p;

@end


@interface IMModelWindow : NSWindow
{
	NSMutableSet *selection;
}

- (NSMutableSet *) selectedElements;

@end


@implementation IMModelWindow

- (id) initWithContentRect:(NSRect)contentRect
				 styleMask:(unsigned int)aStyle
				 backing:(NSBackingStoreType)bufferingType
				 defer:(BOOL)flag
				 screen:aScreen
{
	selection = [[NSMutableSet alloc] init];

	return [super initWithContentRect: contentRect
				  styleMask: aStyle
				  backing: bufferingType
				  defer: flag
				  screen: aScreen];
}

- (NSMutableSet *) selectedElements
{
	return selection;
}

- (void) sendEvent:(NSEvent *)event
{
	NSRect h = {{0,0},{8,8}};
	NSRect oh = {{-999,0},{8,8}};
	NSRect oldRect = {{0,0},{0,0}};	
										// intercept NSWindow's sendEvent: so
										// that controls within this window do
    									// not behave like controls while in
										// modelling mode
	if([(Controller *)[NSApp delegate] testInterface])
		{
		[super sendEvent:event];						// user has selected
		return;											// test interface mode
		}
										// intercept NSWindow's sendEvent: so
	switch ([event type])				// that controls within this window
    	{								// do not behave like controls
    	case NSLeftMouseDown:				
			{												// Left mouse down
			IMHandleType handle;
			NSPoint p = [event locationInWindow];
			NSView *v = [_contentView hitTestForHandle: &handle atPoint: p];

			if (v)									// if a handle was grabbed
	  			{									// do size tracking
				NSEvent *e = event;
				NSRect newf, old_frame = [v frame];
				NSPoint newp, diff, newd;
				NSSize old_size;
				unsigned int event_mask = NSLeftMouseDownMask | 
										NSLeftMouseUpMask | NSMouseMovedMask | 
										NSLeftMouseDraggedMask | 
										NSRightMouseDraggedMask;

				newf = old_frame;
				diff.x = old_frame.origin.x - p.x;
				diff.y = old_frame.origin.y - p.y;	
				[[self contentView] lockFocus];
													// begin a modal loop in
			for (;;)								// order to track the mouse
				{
				newp = [e locationInWindow];

				switch (handle)
					{								// x origin is fixed
					case IMBottomRightHandle:		
						newd.x = newp.x - p.x;
						newd.y = newp.y - p.y;
						newf.origin.y = old_frame.origin.y + newd.y;
						newf.size.width = old_frame.size.width + newd.x;
						newf.size.height = old_frame.size.height - newd.y;

						h.origin = newf.origin;		// calc handle origin
						h.origin.x += newf.size.width;
						h.origin.y -= 6;
						break;

					case IMBottomMiddleHandle:			// width is fixed
						newd.y = newp.y - p.y;
						newf.origin.y = old_frame.origin.y + newd.y;
						newf.size.height = old_frame.size.height - newd.y;

						h.origin = newf.origin;		// calc handle origin
						h.origin.x += ((newf.size.width/2) - 2);
						h.origin.y -= 6;
						break;

					case IMBottomLeftHandle:
						newd.x = newp.x - p.x;
						newd.y = newp.y - p.y;
						newf.origin.x = old_frame.origin.x + newd.x;
						newf.origin.y = old_frame.origin.y + newd.y;
						newf.size.width = old_frame.size.width - newd.x;
						newf.size.height = old_frame.size.height - newd.y;

						h.origin = newf.origin;		// calc handle origin
						h.origin.x -= 6;
						h.origin.y -= 6;
						break;
													// origin is fixed
					case IMTopRightHandle:
						newf.size.width = newp.x - newf.origin.x;
						newf.size.height = newp.y - newf.origin.y;

						h.origin = newf.origin;		// calc handle origin
						h.origin.x += newf.size.width;
						h.origin.y += newf.size.height;
						break;

					case IMTopMiddleHandle:
						newd.y = newp.y - p.y;
						newf.size.height = old_frame.size.height + newd.y;

						h.origin = newf.origin;		// calc handle origin
						h.origin.x += ((newf.size.width/2) - 2);
						h.origin.y += newf.size.height;
						break;

					case IMTopLeftHandle:
						newd.x = newp.x - p.x;
						newd.y = newp.y - p.y;
						newf.origin.x = old_frame.origin.x + newd.x;
						newf.size.width = old_frame.size.width - newd.x;
						newf.size.height = old_frame.size.height + newd.y;

						h.origin = newf.origin;		// calc handle origin
						h.origin.x -= 6;
						h.origin.y += newf.size.height;
						break;

					case IMRightMiddleHandle:
						newd.x = newp.x - p.x;
						newf.size.width = old_frame.size.width + newd.x;

						h.origin = newf.origin;		// calc handle origin
						h.origin.x += newf.size.width;
						h.origin.y += ((newf.size.height/2) - 3);
						break;

					case IMLeftMiddleHandle:
						newd.x = newp.x - p.x;
						newf.origin.x = old_frame.origin.x + newd.x;
						newf.size.width = old_frame.size.width - newd.x;

						h.origin = newf.origin;		// calc handle origin
						h.origin.x -= 6;
						h.origin.y += ((newf.size.height/2) - 3);
						break;

					default:
					   NSLog(@"IMWindow internal error: unknown handle\n");
					}
													// highlight the handle 
													// which was grabbed
			[[NSColor darkGrayColor] set];
			if(oh.origin.x != -999)		
				NSRectFillUsingOperation(oh, NSCompositeXOR);
			NSRectFillUsingOperation(h, NSCompositeXOR);
			oh = h;										// save old rect
			[[NSColor lightGrayColor] set];

			if (newf.size.width < 0)
				newf.size.width = 0;
			if (newf.size.height < 0)
				newf.size.height = 0;
			[v setFrame: newf];

			if(oldRect.size.width != 0)
				NSFrameRectWithWidthUsingOperation(oldRect,1., NSCompositeXOR);
								
			NSFrameRectWithWidthUsingOperation(newf,1., NSCompositeXOR);
			oldRect = newf;
			[self flushWindow];

			e = [NSApp nextEventMatchingMask:event_mask 
					   untilDate:[NSDate distantFuture]
					   inMode:NSEventTrackingRunLoopMode 
					   dequeue:YES];

			if ([e type] == NSLeftMouseUp)			// If mouse went up
				break;								// then we are done
			}

	    [[self contentView] unlockFocus];

	    [self display];
	    [v display];
	    break;
		}

	if (!v)
		v = [_contentView hitTest: p];

	if (v && v != _contentView)							// Do movement tracking
		{
	    BOOL done;
	    NSEvent *e;
	    NSRect new_frame, old_frame = [v frame];
	    NSPoint new_point, diff;
	    unsigned int event_mask = NSLeftMouseDownMask | NSLeftMouseUpMask |
	      							NSMouseMovedMask | NSLeftMouseDraggedMask 
	      							| NSRightMouseDraggedMask;

						// Determine the distance between the view's frame
						// and the mouse location, this will be used to 
						// determine the new view's frame when moving the mouse
	    diff.x = old_frame.origin.x - p.x;
	    diff.y = old_frame.origin.y - p.y;

	    [selection addObject: v];						// change the selection

	    done = NO;
	    new_frame = old_frame;
	    while (!done)
			{
			e = [NSApp nextEventMatchingMask:event_mask 
					   untilDate:[NSDate distantFuture]
					   inMode:NSEventTrackingRunLoopMode 
					   dequeue:YES];
		
			if ([e type] == NSLeftMouseUp)					// If mouse went up
		  		done = YES;									// we are done
			else
		  		{
				new_point = [e locationInWindow];
				new_frame.origin.x = new_point.x + diff.x;
				new_frame.origin.y = new_point.y + diff.y;
				[v setFrame: new_frame];
				[v display];
		  		}
			}

	    [[self contentView] display];
		}
	else
		fprintf(stderr, " IMModelWindow no v :\n");

			break;
			}					// catch but don't handle these in model mode
		case NSLeftMouseUp:								// Left mouse up
		case NSRightMouseDown:							// Right mouse down
		case NSRightMouseUp:							// Right mouse up
		case NSMouseMoved:								// Mouse moved
		case NSLeftMouseDragged:						// Left mouse dragged
		case NSRightMouseDragged:						// Right mouse dragged
		case NSMouseEntered:							// Mouse entered
		case NSMouseExited:								// Mouse exited
		case NSKeyDown:									// Key down
		case NSKeyUp:									// Key up
		case NSFlagsChanged:							// Flags changed
		case NSPeriodic:
			break;
		}
}

@end


@implementation Controller

- (void) applicationDidFinishLaunching:(NSNotification *)aNotification
{
	NSRect wf0 = {{100, 100}, {600, 600}};
	NSRect wcf0 = {{0, 0}, {600, 600}};
	NSRect bf0 = {{10, 10}, {200, 50}};
	NSRect bf1 = {{100, 100}, {200, 50}};
	NSButton *b0, *b1;
	NSMenu *m = [NSApp mainMenu];
	NSMenu *tools = [[NSMenu alloc] initWithTitle:@"Tools"];;

	NSView *contentView = [[IMModelView alloc] initWithFrame:wcf0];
	IMModelWindow *iw = [[IMModelWindow alloc] initWithContentRect:wf0
											   styleMask:_NSCommonWindowMask
											   backing:NSBackingStoreBuffered
											   defer:NO];;
	[iw setContentView: contentView];

	[tools addItemWithTitle:@"Inspector" action:0 keyEquivalent:@""];
	[tools addItemWithTitle:@"Simulator" action:@selector(showSimulatorPanel:)
		   keyEquivalent:@""];
	[m setSubmenu:tools forItem:[m itemWithTitle:@"Tools"]];

	user_models = [[NSMutableArray alloc] initWithCapacity: 2];

	b0 = [[NSButton alloc] initWithFrame: bf0];			// create test controls
	b1 = [[NSButton alloc] initWithFrame: bf1];
	[[iw contentView] addSubview: b0];
	[[iw contentView] addSubview: b1];
	[b0 display];

	[iw setTitle:@"mGSTEP model"];
	[iw setFrame:wf0 display:YES];
	[iw display];
	[iw orderFront:nil];
}

- (void) dealloc
{
	[user_models release];
	[super dealloc];
}

- (id) createSimulatorPanel
{
	NSRect pf = {{680, 510}, {270, 245}};
	NSRect tf = {{10, 10}, {100, 32}};
	NSRect bf = {{10, 52}, {100, 32}};
	NSButton *b;

	_simulatorPanel = [[NSPanel alloc] init];
	[_simulatorPanel setTitle:@"Simulator"];

	b = [[NSButton alloc] initWithFrame: bf];
    [b setButtonType: NSOnOffButton];
    [b setTitle: @"Test Interface"];
    [b setTarget:self];
    [b setAction:@selector(setTestInterface:)];
	testInterface = NO;

	textfield = [[NSTextField alloc] initWithFrame: tf];
    [textfield setStringValue:@"model"];
	[[_simulatorPanel contentView] addSubview: b];
	[[_simulatorPanel contentView] addSubview: textfield];

	[_simulatorPanel setFrame: pf display: NO];
	
	return _simulatorPanel;
}

- (void) showSimulatorPanel:(id)sender
{
	if (!_simulatorPanel)									// create palette if 
		_simulatorPanel = [self createSimulatorPanel];		// it doesn't exist

    [_simulatorPanel display];
	[_simulatorPanel makeKeyAndOrderFront: sender];
}

- (void) method:menuCell							// temp for sake of menu
{
  	NSLog (@"method invoked from cell with title '%@'", [menuCell title]);
}

- (void) setTestInterface:(id)sender				// toggle between model and
{													// test interface modes
	NSLog (@"testInterface:");
	[textfield setStringValue:[sender intValue] ? @"test" : @"model"];
	[textfield display];
	testInterface = [sender intValue];
}

- (BOOL) testInterface
{													// return mode IM's mode
	return testInterface;							// YES == test mode
}													// NO  == model mode

@end


@implementation IMModelView

- (void) drawRect:(NSRect)r
{
	id e = [[(IMModelWindow *)_window selectedElements] objectEnumerator];
	NSView *o;
	NSColor *c = [NSColor blackColor];

	fprintf(stderr, " IMModelView display\n");

	[[NSColor lightGrayColor] set];
	NSRectFill(r);

	while ((o = (NSView *)[e nextObject]))
		{
		NSRect r = [o frame];
		NSRect h = {{0,0},{6,6}};
		float mid;

		[c set];								// Display handles on corners

		h.origin.x = r.origin.x - 6;						// Bottom left
		h.origin.y = r.origin.y - 6;
		NSRectFill(h);

		h.origin.y += r.size.height + 6;					// Top left
		NSRectFill(h);

		h.origin.x += r.size.width + 7;						// Top right
		NSRectFill(h);

		h.origin.y -= r.size.height + 6;					// Bottom right
		NSRectFill(h);

		mid = r.size.width / 2;								// Bottom middle
		h.origin.x -= mid + 3;
		NSRectFill(h);

		h.origin.y += r.size.height + 6;					// Top middle
		NSRectFill(h);

		mid = r.size.height / 2;							// Left middle
		h.origin.x = r.origin.x - 6;
		h.origin.y = r.origin.y + mid - 3;
		NSRectFill(h);

		h.origin.x += r.size.width + 7;						// Right middle
		NSRectFill(h);
		}
}

- (id) hitTestForHandle:(IMHandleType *)handle atPoint:(NSPoint)p
{
	id e = [[(IMModelWindow *)_window selectedElements] objectEnumerator];
	NSView *o;
											// Loop through selected elements
	while ((o = (NSView *)[e nextObject]))	// which will have handles attached
		{
		NSRect r = [o frame];
		NSRect h = {{0,0},{4,4}};
		float mid;							// Determine if mouse point is 
											// within a handle
		h.origin.x = r.origin.x - 6;							// Bottom left
		h.origin.y = r.origin.y - 6;
		if ([self mouse: p inRect: h])
			{
			*handle = IMBottomLeftHandle;
			return o;
			}

		h.origin.y += r.size.height + 6;
		if ([self mouse: p inRect: h])							// Top left
			{
			*handle = IMTopLeftHandle;
			return o;
			}

		h.origin.x += r.size.width + 7;							// Top right
		if ([self mouse: p inRect: h])
			{
			*handle = IMTopRightHandle;
			return o;
			}

		h.origin.y -= r.size.height + 6;						// Bottom right
		if ([self mouse: p inRect: h])
			{
			*handle = IMBottomRightHandle;
			return o;
			}

		mid = r.size.width / 2;									// Bottom middl
		h.origin.x -= mid + 3;
		if ([self mouse: p inRect: h])
			{
			*handle = IMBottomMiddleHandle;
			return o;
			}

		h.origin.y += r.size.height + 6;						// Top middle
		if ([self mouse: p inRect: h])
			{
			*handle = IMTopMiddleHandle;
			return o;
			}

		mid = r.size.height / 2;								// Left middle
		h.origin.x = r.origin.x - 6;
		h.origin.y = r.origin.y + mid - 3;
		if ([self mouse: p inRect: h])
			{
			*handle = IMLeftMiddleHandle;
			return o;
			}

		h.origin.x += r.size.width + 7;							// Right middle
		if ([self mouse: p inRect: h])
			{
			*handle = IMRightMiddleHandle;
			return o;
		}	}

	*handle = IMNoHandle;

	return nil;
}

@end
