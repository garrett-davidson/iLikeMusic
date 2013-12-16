//
//  MediaKeyApplication.m
//  iLikeMusic
//
//  Created by Garrett Davidson on 12/15/13.
//  Copyright (c) 2013 Garrett Davidson. All rights reserved.
//

#import "MediaKeyApplication.h"
#import <IOKit/hidsystem/ev_keymap.h>
#import "iTunes.h"
#import "CaptureWindowController.h"

@implementation MediaKeyApplication


- (void)sendEvent: (NSEvent*)event
{
	if( [event type] == NSSystemDefined && [event subtype] == 8 )
	{
		int keyCode = (([event data1] & 0xFFFF0000) >> 16);
		int keyFlags = ([event data1] & 0x0000FFFF);
		int keyState = (((keyFlags & 0xFF00) >> 8)) == 0xA;
		int keyRepeat = (keyFlags & 0x1);

		[self mediaKeyEvent: keyCode state: keyState repeat: keyRepeat];
	}

	else [super sendEvent: event];
}

- (void)mediaKeyEvent: (int)key state: (BOOL)state repeat: (BOOL)repeat
{
    //Can't cancel the keys being sent to iTunes
    //So just undo their effects
    iTunesApplication *iTunes = [SBApplication applicationWithBundleIdentifier:@"com.apple.iTunes"];
    CaptureWindowController *mainWindow = [CaptureWindowController mainWindow];

	switch( key )
	{
		case NX_KEYTYPE_PLAY:
			if( state == 0 )
            {
                [iTunes playpause];
                [mainWindow playPause];
            }
            break;

		case NX_KEYTYPE_FAST:
			if( state == 0 )
            {
                [iTunes rewind];
                [mainWindow skip];
            }
            break;

		case NX_KEYTYPE_REWIND:
			if( state == 0 )
            {
                [mainWindow thumbUp];
            }

            break;
	}
}

@end
