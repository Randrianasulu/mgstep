#import <AppKit/AppKit.h>


@interface Controller : NSObject
{
    id textField;
	id delegate;

	IBOutlet NSPanel *_aboutPanel;
	IBOutlet NSTextField *_credits;
	IBOutlet NSTextField *_applicationName;
//	NSImageView *_applicationImage;
	IBOutlet NSTextField *_version;
	IBOutlet NSTextField *_copyright;
	IBOutlet NSTextField *_applicationVersion;
}

- (void) buttonPressed:(id)sender;
- (NSWindow *) window;

@end


@interface MyView : NSView
@end
