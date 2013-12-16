//
//  CaptureWindowController.m
//  iLikeMusic
//
//  Created by Garrett Davidson on 12/13/13.
//  Copyright (c) 2013 Garrett Davidson. All rights reserved.
//

#import "CaptureWindowController.h"
#import "InterceptionProtocol.h"
#import "iTunes.h"
#import <Scripting/Scripting.h>
#import <AVFoundation/AVFoundation.h>

@interface CaptureWindowController ()
{
    id imageIdentifier;
    int num;

    enum sites
    {
        pandora = 1,
        lastfm,
        grooveshark
    };

    bool playing;
    NSArray *previousSongs;

    int site;
}
@property (weak) IBOutlet NSTableView *tableView;

@end

@implementation CaptureWindowController

static CaptureWindowController *sharedSingleton = nil;

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        // Initialization code here.
        num = 0;
        previousSongs = [NSArray array];
        sharedSingleton = self;
        playing = true;
    }
    return self;
}

#define kPandoraMinWidth 820

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

- (void)windowWillLoad
{
    [super windowWillLoad];
}


- (IBAction)loadSite:(id)sender {
    self.mainWebView.resourceLoadDelegate = self;
    NSButton *button = (NSButton *)sender;
    NSURLRequest *req;
    switch (button.tag) {
        case pandora:
            req = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://www.pandora.com"]];
            break;

        case grooveshark:
            req = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://grooveshark.com/"]];
            break;

    }

    [self.mainWebView.mainFrame loadRequest:req];

    site = (int)button.tag;
}


- (void)saveSong:(NSData *)data
{
    //if this doesn't run on the main thread
    //the Javascript throws excpetions

    dispatch_async(dispatch_get_main_queue(), ^{

        NSString *name;
        NSString *artist;
        NSString *album;
        NSString *pictureURLString;
        NSData *imageData;
        NSString *extension;
        NSString *picturePath;

        switch (site) {
            case pandora:
            {
                name = [self.mainWebView stringByEvaluatingJavaScriptFromString:@"document.getElementsByClassName('songTitle')[0].innerText;"];
                artist = [self.mainWebView stringByEvaluatingJavaScriptFromString:@"document.getElementsByClassName('artistSummary')[0].innerText"];
                album = [self.mainWebView stringByEvaluatingJavaScriptFromString:@"document.getElementsByClassName('albumTitle')[0].innerText"];
                pictureURLString = [self.mainWebView stringByEvaluatingJavaScriptFromString:@"document.getElementsByClassName('playerBarArt')[0].src"];
                WebResource *res = [self.mainWebView.mainFrame.dataSource subresourceForURL:[NSURL URLWithString:pictureURLString]];
                imageData = res.data;
                extension = @".m4a";
            }
                break;

            case grooveshark:
            {
                //if grooveshark fully buffered the next song
                //then this will call before the UI finishes changing
                //causing the previous info to be called twice

                NSString *previousName;
                NSString *previousArtist;

                name = [self.mainWebView stringByEvaluatingJavaScriptFromString:@"document.getElementsByClassName('now-playing-link song no-title-tooltip song-link show-song-tooltip')[0].title"];
                artist = [self.mainWebView stringByEvaluatingJavaScriptFromString:@"document.getElementsByClassName('now-playing-link artist no-title-tooltip show-artist-tooltip')[0].title"];
                pictureURLString = [self.mainWebView stringByEvaluatingJavaScriptFromString:@"document.getElementById('now-playing-image').src"];

                if (previousSongs.count)
                {
                    previousName = [[previousSongs objectAtIndex:(previousSongs.count - 1)] objectAtIndex:1];
                    previousArtist = [[previousSongs objectAtIndex:(previousSongs.count - 1)] objectAtIndex:2];


                    if ([name isEqualToString:previousName] && [artist isEqualToString:previousArtist])
                    {
                        name = [self.mainWebView stringByEvaluatingJavaScriptFromString:@"document.getElementsByClassName('module module-cell queue-item grid-item queue-item-active')[0].nextSibling.getElementsByClassName('queue-song-name song song-link tooltip-for-full-text ellipsis')[0].innerText"];
                        artist = [self.mainWebView stringByEvaluatingJavaScriptFromString:@"document.getElementsByClassName('module module-cell queue-item grid-item queue-item-active')[0].nextSibling.getElementsByClassName('queue-song-artist artist ellipsis')[0].innerText"];
                        pictureURLString = [self.mainWebView stringByEvaluatingJavaScriptFromString:@"document.getElementsByClassName('module module-cell queue-item grid-item queue-item-active')[0].nextSibling.getElementsByClassName('img')[0].src"];
                    }
                }


                imageData = [self.mainWebView.mainFrame.dataSource subresourceForURL:[NSURL URLWithString:pictureURLString]].data;
                extension = @".mp3";
                break;
            }
        }



        iTunesApplication *iTunes = [SBApplication applicationWithBundleIdentifier:@"com.apple.iTunes"];
        SBElementArray *sources = [iTunes sources];
        iTunesSource *librarySource = [sources objectWithName:@"Library"];
        iTunesPlaylist *library = [[librarySource libraryPlaylists] objectWithName:@"Library"];

        SBElementArray *tracks = [library tracks];


        //simple check for duplicates
        iTunesFileTrack *duplicateSong = [[tracks objectWithName:name] get];

        //duplicate verification (make sure it is a duplicate)
        //some songs have same name but are from different albums, or by different artists, etc.
        bool duplicate = false;
        if (duplicateSong)
        {
            if (!album | [duplicateSong.album isEqualToString:album])
            {
                if ([duplicateSong.artist isEqualToString:artist])
                {
                    duplicate = true;
                }
            }
        }

        //advanced duplicate checking
        //in case of multiple different songs with same name
        if (duplicateSong && !duplicate)
        {
            for (iTunesFileTrack *track in tracks)
            {
                if ([track.name isEqualToString:name])
                {
                    if (!album | [track.album isEqualToString:album])
                    {
                        if ([track.artist isEqualToString:artist])
                        {
                            duplicate = true;
                            break;
                        }
                    }
                }
            }
        }



        NSString *songPath = [NSString stringWithFormat:@"%@a%d%@", NSTemporaryDirectory(), num, extension];
        picturePath = [NSString stringWithFormat:@"%@pic.jpg", NSTemporaryDirectory()];
        [imageData writeToFile:picturePath atomically:YES];
        [data writeToFile:songPath atomically:YES];
        [NSThread sleepForTimeInterval:.01];


        bool overwrote = false;

        if (!duplicate)
        {
            NSLog(@"Saved song %@", name);

            //IF THERE WAS AN ERROR
            //DON'T ADD TO ITUNES

            switch (site) {
                case pandora:
                {
                    NSAppleScript *script = [[NSAppleScript alloc] initWithSource:[NSString stringWithFormat:@"with timeout of 600 seconds \n"
                       "tell application \"iTunes\"\n"

                       "set newFile to add \"%@\" as POSIX file to playlist \"Library\"\n"
                       "tell newFile\n"
                       "set name to \"%@\" as string\n"
                       "set artist to \"%@\" as string\n"
                       "set album to \"%@\" as string\n"

                       "end tell\n"

                       "set image to POSIX file \"%@\"\n"
                       
                       "set data of artwork 1 of newFile to (read image as picture)\n"
                       "end tell\n"
                       "end timeout", songPath, name, artist, album, picturePath]];
                    NSDictionary *errors;
                    [script executeAndReturnError:&errors];
                    if (errors)
                        NSLog(@"%@", errors);
                    break;
                }
                    
                case grooveshark:
                    //Grooveshark already tags all of their media
                    [iTunes add:[NSArray arrayWithObject:[NSURL fileURLWithPath:songPath]] to:library];
                    break;
            }

            NSFileManager *manager = [NSFileManager defaultManager];
            [manager removeItemAtPath:songPath error:nil];
            [manager removeItemAtPath:picturePath error:nil];
            num++;


        }

        else
        {

            iTunesTrack *newSong = [iTunes add:[NSArray arrayWithObject:[NSURL fileURLWithPath:songPath]] to:library];
            if (duplicateSong.bitRate < newSong.bitRate)
            {
                newSong.playedCount = duplicateSong.playedCount;
                [duplicateSong delete];
                NSLog(@"Overwrote %@", name);
                overwrote = true;
            }

            else
            {
                NSLog(@"Duplicate %@", name);
                [newSong delete];
                overwrote = false;
            }
        }

        //album is last because it terminates the array if it is nil
        NSArray *songArray = [NSArray arrayWithObjects:!duplicate ? @"Added" : overwrote ? @"Overwrote" : @"Duplicate", name, artist, imageData, album, nil];

        previousSongs = [previousSongs arrayByAddingObject:songArray];

        //Update table
        [self.tableView insertRowsAtIndexes:[[NSIndexSet alloc] initWithIndex:0] withAnimation:NSTableViewAnimationSlideDown];

        //Show notification
        NSUserNotification *notification = [[NSUserNotification alloc] init];
        notification.title = duplicate ? @"Duplicate" : @"Added";
        notification.informativeText = [NSString stringWithFormat:@"%@ – %@", name, artist];
        notification.soundName = NSUserNotificationDefaultSoundName;

        [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
    });
}

- (NSURLRequest *)webView:(WebView *)sender resource:(id)identifier willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse fromDataSource:(WebDataSource *)dataSource
{
    [NSURLProtocol registerClass:[InterceptionProtocol class]];
    const NSPredicate *pandoraSongPredicate = [NSPredicate predicateWithFormat:@"SELF like \"audio-*.pandora.com\""];
    const NSPredicate *grooveSharkPredicate = [NSPredicate predicateWithFormat:@"SELF like \"stream*.grooveshark.com\""];

    switch (site) {
        case pandora:
            if ([pandoraSongPredicate evaluateWithObject:request.URL.host])
            {
                NSMutableURLRequest* newRequest = [request mutableCopy];
                [InterceptionProtocol setProperty:self forKey:@"MyApp" inRequest:newRequest];
                return newRequest;
            }

            break;

        case grooveshark:
            if ([grooveSharkPredicate evaluateWithObject:request.URL.host])
            {
                NSMutableURLRequest* newRequest = [request mutableCopy];
                [InterceptionProtocol setProperty:self forKey:@"MyApp" inRequest:newRequest];
                return newRequest;
            }
            break;
    }




    return request;
}



#pragma mark Table View
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return previousSongs.count;
}

- (NSView *)tableView:(NSTableView *)tableView
   viewForTableColumn:(NSTableColumn *)tableColumn
                  row:(NSInteger)row {


    NSTableCellView *result = [tableView makeViewWithIdentifier:@"songCell" owner:self];

    

    NSArray *song = [previousSongs objectAtIndex:previousSongs.count - 1 - row];

    NSString *string;

    switch (site) {
        case pandora:
            string = [NSString stringWithFormat:@"%@\n%@\n%@\n%@", song[0], song[1], song[2], song[4]];
            break;

        case grooveshark:
            string = [NSString stringWithFormat:@"%@\n%@\n%@", song[0], song[1], song[2]];
            break;
    }


    result.textField.stringValue = string;

    result.imageView.image = [[NSImage alloc] initWithData:song[3]];

    // return the result.
    return result;
    
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
    switch ([previousSongs[previousSongs.count - 1 - row] count]) {
        case 5:
            return 68;
            break;

        case 4:
            return 51;
            break;

        default:
            return 51;
    }
}

- (void)playPause
{
    switch (site) {
        case pandora:
        {
            if (playing)
            {
                [self.mainWebView stringByEvaluatingJavaScriptFromString:@"document.getElementsByClassName('pauseButton')[0].click()"];
            }

            else
            {
                [self.mainWebView stringByEvaluatingJavaScriptFromString:@"document.getElementsByClassName('playButton')[0].click()"];
            }

            break;
        }

        case grooveshark:
        {
            [self.mainWebView stringByEvaluatingJavaScriptFromString:@"document.getElementById('play-pause').click()"];
        }
    }

    playing = !playing;
}
- (void)skip
{
    switch (site) {
        case pandora:
        {
            [self.mainWebView stringByEvaluatingJavaScriptFromString:@"document.getElementsByClassName('skipButton')[0].click()"];
            break;
        }

        case grooveshark:
        {
            [self.mainWebView stringByEvaluatingJavaScriptFromString:@"document.getElementById('play-next').click()"];
        }
    }
}
- (void)thumbUp
{
    switch (site) {
        case pandora:
        {
            [self.mainWebView stringByEvaluatingJavaScriptFromString:@"document.getElementsByClassName('thumbUpButton')[0].click()"];
            break;
        }

        case grooveshark:
        {
            [self.mainWebView stringByEvaluatingJavaScriptFromString:@"document.getElementById('play-prev').click()"];
        }
    }
}

- (void)setUp
{
    [[self.window standardWindowButton:NSWindowCloseButton] setAction:@selector(hideMe)];
    [[self.window standardWindowButton:NSWindowCloseButton] setTarget:self];
}

- (void)hideMe
{
    [self.window orderOut:self.window];
}


+ (CaptureWindowController *) mainWindow {
    return sharedSingleton;
}

@end
