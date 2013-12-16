//
//  CaptureWindowController.h
//  iLikeMusic
//
//  Created by Garrett Davidson on 12/13/13.
//  Copyright (c) 2013 Garrett Davidson. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@interface CaptureWindowController : NSWindowController <NSWindowDelegate>
@property (weak) IBOutlet WebView *mainWebView;

- (void)saveSong:(NSData *)data;
- (void)playPause;
- (void)skip;
- (void)thumbUp;
- (void)setUp;
+ (CaptureWindowController *)mainWindow;

@end
