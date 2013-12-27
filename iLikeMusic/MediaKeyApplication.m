//
//  MediaKeyApplication.m
//  iLikeMusic
//
//  Created by Garrett Davidson on 12/15/13.
//  Copyright (c) 2013 Garrett Davidson. All rights reserved.
//

//This file is part of iLikeMusic.
//
//iLikeMusic is free software: you can redistribute it and/or modify
//it under the terms of the GNU General Public License as published by
//the Free Software Foundation, either version 3 of the License, or
//(at your option) any later version.
//
//iLikeMusic is distributed in the hope that it will be useful,
//but WITHOUT ANY WARRANTY; without even the implied warranty of
//MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//GNU General Public License for more details.
//
//You should have received a copy of the GNU General Public License
//along with iLikeMusic.  If not, see <http://www.gnu.org/licenses/>.

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
