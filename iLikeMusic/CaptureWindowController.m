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
        grooveshark,
        rdio,
        eighttracks
    };

    bool playing;
    NSArray *previousSongs;
    NSUserNotification *loadingNotification;
    NSMutableURLRequest *lastSongRequest;
    NSMutableURLRequest *currentSongRequest;

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
    [NSURLProtocol registerClass:[InterceptionProtocol class]];
    
    NSButton *button = (NSButton *)sender;

    //this must come before the request is sent
    //for the predicate arrays to work
    site = (int)button.tag;

    //reset in the case the user changed from rdio
    self.mainWebView.customUserAgent = nil;

    NSURLRequest *req;
    switch (button.tag) {
        case pandora:
            req = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://www.pandora.com/"]];
            break;

        case lastfm:
            req = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://last.fm/listen/"]];
            break;

        case grooveshark:
            req = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://grooveshark.com"]];
            break;
 
        case rdio:
            //rdio loads strangley if you don't change the user agent
            //i.e. the songs the are harder to intercept
            self.mainWebView.customUserAgent = @"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/32.0.1664.3 Safari/537.36";
            req = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://rdio.com/"]];
            break;

        case eighttracks:
            req = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://8tracks.com/"]];
            break;

    }

    [self.mainWebView.mainFrame loadRequest:req];


}


- (void)saveSong:(NSData *)data
{


    //album is last because it terminates the array if it is nil
    NSArray *songInfo = [previousSongs lastObject];
    NSString *name = songInfo[1];
    NSString *artist = songInfo[2];
    NSData *imageData = songInfo[3];
    NSString *extension = songInfo[4];

    NSString *album;
    if (songInfo.count == 6) album = songInfo[5];

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
    NSString *picturePath = [NSString stringWithFormat:@"%@pic.jpg", NSTemporaryDirectory()];
    [imageData writeToFile:picturePath atomically:YES];
    [data writeToFile:songPath atomically:YES];
    [NSThread sleepForTimeInterval:.01];

    NSFileManager *manager = [NSFileManager defaultManager];

    iTunesTrack *newSong;
    newSong = [iTunes add:[NSArray arrayWithObject:[NSURL fileURLWithPath:songPath]] to:library];
    if (!newSong && site == eighttracks)
    {
        //8tracks could have either .mp3 or .m4a
        ///.mp3 is much more common though
        [manager removeItemAtPath:songPath error:nil];
        songPath = [songPath stringByDeletingPathExtension];
        songPath = [songPath stringByAppendingString:@".m4a"];
        [data writeToFile:songPath atomically:YES];
        newSong = [iTunes add:[NSArray arrayWithObject:[NSURL fileURLWithPath:songPath]] to:library];

    }

    bool overwrote = false;


    NSLog(@"Saved song %@", name);

    //IF THERE WAS AN ERROR
    //DON'T ADD TO ITUNES



    switch (site) {
        case grooveshark:
            //Grooveshark already tags most of their media
            //just check to make sure though
            if (!newSong.name) newSong.name = name;
            if (!newSong.artist) newSong.artist = artist;
            if (!newSong.album) newSong.album = album;
            if (!newSong.artworks.count) [[[newSong artworks] objectAtIndex:0] setData:(NSData*)[[NSImage alloc] initWithData:imageData]];
            break;

        case pandora:
        case rdio:
        case lastfm:
        {
            newSong.name = name;
            newSong.artist = artist;
            newSong.album = album;

            //I have no idea why
            //but this part must be done like this
            //otherwise it won't work
            [[[newSong artworks] objectAtIndex:0] setData:(NSData*)[[NSImage alloc] initWithData:imageData]];

            break;
        }

        case eighttracks:
        {
            newSong.name = name;
            newSong.artist = artist;
            break;
        }

    }

    [manager removeItemAtPath:songPath error:nil];
    [manager removeItemAtPath:picturePath error:nil];
    num++;

    bool artwork = false;
    if (duplicate)
    {
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
            if (!duplicateSong.artworks.count)
            {
                [[[newSong artworks] objectAtIndex:0] setData:(NSData*)[[NSImage alloc] initWithData:imageData]];
                artwork = true;
            }
            overwrote = false;
        }
    }

    //album is last because it terminates the array if it is nil
    NSArray *songArray = [NSArray arrayWithObjects:!duplicate ? @"Added" : overwrote ? @"Overwrote" : artwork ? @"Added artwork": @"Duplicate", name, artist, imageData, extension, album, nil];

    [self.tableView removeRowsAtIndexes:[[NSIndexSet alloc] initWithIndex:0] withAnimation:NSTableViewAnimationSlideRight];
    //Replace the last ("loading") object in the array
    if (previousSongs.count < 1) previousSongs = [previousSongs subarrayWithRange:NSMakeRange(0, previousSongs.count-1)];
    else previousSongs = [NSArray array];
    previousSongs = [previousSongs arrayByAddingObject:songArray];

    //Update table
    [self.tableView insertRowsAtIndexes:[[NSIndexSet alloc] initWithIndex:0] withAnimation:NSTableViewAnimationSlideDown];

    //Show notification
    NSUserNotification *notification = [[NSUserNotification alloc] init];
    notification.title = !duplicate ? @"Added" : overwrote ? @"Overwrote" : @"Duplicate";
    notification.informativeText = [NSString stringWithFormat:@"%@ – %@", name, artist];
    notification.soundName = NSUserNotificationDefaultSoundName;

    [[NSUserNotificationCenter defaultUserNotificationCenter] removeDeliveredNotification:loadingNotification];
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];

}

- (NSArray *)getSongInformation
{

    //if this doesn't run on the main thread
    //the Javascript throws excpetions

    __block NSData *imageData;
    __block NSString *name;
    __block NSString *artist;
    __block NSString *album;
    __block NSString *extension;
    __block NSArray *songArray;


    __block NSString *pictureURLString;
    //dispatch_sync(dispatch_get_main_queue(), ^{
    void (^infoBlock)(void) = ^{
/*
        NSString *name;
        NSString *artist;
        NSString *album;
        NSString *extension;
*/
        switch (site) {
            case pandora:
            {
                name = [self.mainWebView stringByEvaluatingJavaScriptFromString:@"document.getElementsByClassName('songTitle')[0].innerText;"];
                artist = [self.mainWebView stringByEvaluatingJavaScriptFromString:@"document.getElementsByClassName('artistSummary')[0].innerText"];
                album = [self.mainWebView stringByEvaluatingJavaScriptFromString:@"document.getElementsByClassName('albumTitle')[0].innerText"];
                pictureURLString = [self.mainWebView stringByEvaluatingJavaScriptFromString:@"document.getElementsByClassName('playerBarArt')[0].src"];
                extension = @".m4a";
                break;
            }

            case lastfm:
            {
                name = [self.mainWebView stringByEvaluatingJavaScriptFromString:@"document.getElementsByClassName('track')[0].childNodes[0].innerText"];
                artist = [self.mainWebView stringByEvaluatingJavaScriptFromString:@"document.getElementsByClassName('artist')[0].childNodes[0].innerText"];
                album = [self.mainWebView stringByEvaluatingJavaScriptFromString: @"document.getElementsByClassName('title')[0].childNodes[0].innerText"];
                pictureURLString = [self.mainWebView stringByEvaluatingJavaScriptFromString:@"document.getElementsByClassName('lfmradio:artistBio')[0].childNodes[1].childNodes[1].src"];
                pictureURLString = [pictureURLString stringByReplacingOccurrencesOfString:@"64s" withString:@"500"];
                extension = @".mp3";
                break;
            }

            case grooveshark:
            {


                NSString *previousName;
                NSString *previousArtist;

                name = [self.mainWebView stringByEvaluatingJavaScriptFromString:@"document.getElementsByClassName('now-playing-link song no-title-tooltip song-link show-song-tooltip')[0].title"];
                artist = [self.mainWebView stringByEvaluatingJavaScriptFromString:@"document.getElementsByClassName('now-playing-link artist no-title-tooltip show-artist-tooltip')[0].title"];
                pictureURLString = [self.mainWebView stringByEvaluatingJavaScriptFromString:@"document.getElementById('now-playing-image').src"];

                //if grooveshark fully buffered the next song
                //then this will call before the UI finishes changing
                //causing the previous info to be called twice
                //this part prevents that
                if (previousSongs.count)
                {
                    if (![[previousSongs.lastObject objectAtIndex:0] isEqualToString:@"Loading"])
                    {
                        previousName = [previousSongs.lastObject objectAtIndex:1];
                        previousArtist = [previousSongs.lastObject objectAtIndex:2];


                        if ([name isEqualToString:previousName] && [artist isEqualToString:previousArtist])
                        {
                            name = [self.mainWebView stringByEvaluatingJavaScriptFromString:@"document.getElementsByClassName('module module-cell queue-item grid-item queue-item-active')[0].nextSibling.getElementsByClassName('queue-song-name song song-link tooltip-for-full-text ellipsis')[0].innerText"];
                            artist = [self.mainWebView stringByEvaluatingJavaScriptFromString:@"document.getElementsByClassName('module module-cell queue-item grid-item queue-item-active')[0].nextSibling.getElementsByClassName('queue-song-artist artist ellipsis')[0].innerText"];
                            pictureURLString = [self.mainWebView stringByEvaluatingJavaScriptFromString:@"document.getElementsByClassName('module module-cell queue-item grid-item queue-item-active')[0].nextSibling.getElementsByClassName('img')[0].src"];
                        }
                    }
                }


                pictureURLString = [pictureURLString stringByReplacingOccurrencesOfString:@"40_" withString:@"120_"];
                extension = @".mp3";
                break;
            }

            case rdio:
            {
                name = [self.mainWebView stringByEvaluatingJavaScriptFromString:@"document.getElementsByClassName('song_title')[0].innerText"];

                //had to use the next siblings because there a lot of
                //'artist_title' class objects in the page
                artist = [self.mainWebView stringByEvaluatingJavaScriptFromString:@"document.getElementsByClassName('song_title')[0].nextSibling.nextSibling.innerText"];

                album = [self.mainWebView stringByEvaluatingJavaScriptFromString:@"document.getElementsByClassName('album truncated_line')[0].innerText"];

                pictureURLString = [self.mainWebView stringByEvaluatingJavaScriptFromString:@"document.getElementsByClassName('queue_art')[0].src"];
                //pictureURLString = [pictureURLString stringByReplacingOccurrencesOfString:@"400" withString:@"1200"];
                extension = @".mp3";
                break;
            }

            case eighttracks:
            {
                name = [self.mainWebView stringByEvaluatingJavaScriptFromString:@"document.getElementById('now_playing').getElementsByClassName('t')[0].innerText"];
                name = [name stringByReplacingOccurrencesOfString:@"\"" withString:@""];
                artist = [self.mainWebView stringByEvaluatingJavaScriptFromString:@"document.getElementById('now_playing').getElementsByClassName('a')[0].innerText"];
                pictureURLString = [self.mainWebView stringByEvaluatingJavaScriptFromString:@"document.getElementsByClassName('mix_art_wrapper')[0].children[0].href"];
                NSArray *pieces = [pictureURLString componentsSeparatedByString:@"?"];
                pictureURLString = pieces[0];
                extension = @".mp3";
                break;
            }
        }


         NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:pictureURLString] cachePolicy:NSURLRequestReturnCacheDataElseLoad timeoutInterval:60];
         urlRequest.HTTPMethod = @"GET";

        //Temp
        [urlRequest setValue:@"image/jpeg" forHTTPHeaderField:@"content-type"];


         NSURLResponse *response;
         NSError *error;

         // Make synchronous request
         //NSString *mydata = [[NSString alloc] initWithContentsOfURL:urlRequest.URL encoding:NSUTF32StringEncoding error:nil];
         imageData = [NSURLConnection sendSynchronousRequest:urlRequest returningResponse:&response error:&error];

        //album is last because it terminates the array if it is nil
        songArray = [NSArray arrayWithObjects: name, artist, imageData, extension, album, nil];
    };



    int counter = 0;
    while (songArray.count < 3 && counter < 30)
    {
        if ([NSThread isMainThread]) infoBlock();
        else dispatch_sync(dispatch_get_main_queue(), infoBlock);
        [NSThread sleepForTimeInterval:1];
        NSLog(@"%d", counter);
        counter++;
    }


    return songArray;
}

- (NSURLRequest *)webView:(WebView *)sender resource:(id)identifier willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse fromDataSource:(WebDataSource *)dataSource
{


    //song predicates
    const NSPredicate *pandoraPredicate = [NSPredicate predicateWithFormat:@"SELF like \"audio-*.pandora.com\""];
    const NSPredicate *lastfmPredicate = [NSPredicate predicateWithFormat:@"SELF like \"??.last.fm\""];
    const NSPredicate *grooveSharkPredicate = [NSPredicate predicateWithFormat:@"SELF like \"stream*.grooveshark.com\""];
    const NSPredicate *rdioPredicate = [NSPredicate predicateWithFormat:@"SELF like \"m.cdn?.rd*io*\""];
    const NSPredicate *eighttracksPredicate1 = [NSPredicate predicateWithFormat:@"SELF like \"ec-media.soundcloud.com\""];
    const NSPredicate *eighttracksPredicate2= [NSPredicate predicateWithFormat:@"SELF like \"cft.8tracks.com\""];


    //ad predicates
    const NSPredicate *doubleclickPredicate = [NSPredicate predicateWithFormat:@"SELF like \"ad.doubleclick.net\""];
    const NSPredicate *lastfmAdsPredicate = [NSPredicate predicateWithFormat:@"SELF contains \"ads.php\""];

    //predicate arrays
    const NSArray *songPredicates = [NSArray arrayWithObjects:pandoraPredicate, lastfmPredicate, grooveSharkPredicate, rdioPredicate, nil];
    const NSArray *adPredicates = [NSArray arrayWithObjects:doubleclickPredicate, lastfmAdsPredicate, nil];

    bool shouldintercept = false;
    if (site == eighttracks)
    {
        if ([eighttracksPredicate1 evaluateWithObject:request.URL.host] || [eighttracksPredicate2 evaluateWithObject:request.URL.host])
        {
            shouldintercept = true;
        }

    }
    else if ([[songPredicates objectAtIndex:site-1] evaluateWithObject:request.URL.host])
    {
        shouldintercept = true;
    }

    else if (site < grooveshark)
    {
        if ([[adPredicates objectAtIndex:site-1] evaluateWithObject:request.URL.absoluteString])
        {
            return nil;
        }
    }

    if (shouldintercept)
    {
        NSMutableURLRequest* newRequest = [request mutableCopy];
        [InterceptionProtocol setProperty:self forKey:@"MyApp" inRequest:newRequest];

        //Update the table
        dispatch_async( dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

            //Rdio only sends 206, never 200
            //So we have to manually decide when the request is done
            if (lastSongRequest)
                [self saveSong:[[InterceptionProtocol propertyForKey:@"protocol" inRequest:lastSongRequest] data]];

            NSArray *songInfo = [self getSongInformation];
            songInfo = [[NSArray arrayWithObject:@"Loading"] arrayByAddingObjectsFromArray:songInfo];

            previousSongs = [previousSongs arrayByAddingObject:songInfo];
            [self.tableView insertRowsAtIndexes:[[NSIndexSet alloc] initWithIndex:0] withAnimation:NSTableViewAnimationSlideDown];

            NSUserNotification *notification = [[NSUserNotification alloc] init];
            notification.title = @"Loading";
            notification.informativeText = [NSString stringWithFormat:@"%@ – %@", songInfo[1], songInfo[2]];
            notification.soundName = NSUserNotificationDefaultSoundName;

            [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];

            loadingNotification = notification;

            lastSongRequest = currentSongRequest;
        });


/*
        if (site == rdio)
        {
            currentSongRequest = newRequest;
        }
        else currentSongRequest = nil;
        */
        return newRequest;
    }


    return request;
}


- (IBAction)clearCache:(id)sender
{
    
}



#pragma mark Table View
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return previousSongs.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {


    NSTableCellView *result = [tableView makeViewWithIdentifier:@"songCell" owner:self];

    

    NSArray *song = [previousSongs objectAtIndex:previousSongs.count - 1 - row];

    NSString *string;

    switch (site) {
        case pandora:
        case rdio:
        case lastfm:
            string = [NSString stringWithFormat:@"%@\n%@\n%@\n%@", song[0], song[1], song[2], song[5]];
            break;

        case grooveshark:
        case eighttracks:
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
        case 6:
            return 68;
            break;

        case 5:
        case 3:
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

        case lastfm:
        {
            if (playing) [self.mainWebView stringByEvaluatingJavaScriptFromString:@"ocument.getElementsByClassName('radiocontrol')[4].click()"];
            else [self.mainWebView stringByEvaluatingJavaScriptFromString:@"document.getElementsByClassName('radiocontrol')[3].click()"];
            break;
        }

        case grooveshark:
        {
            [self.mainWebView stringByEvaluatingJavaScriptFromString:@"document.getElementById('play-pause').click()"];
            break;
        }

        case rdio:
        {
            if (playing) [self.mainWebView stringByEvaluatingJavaScriptFromString:@"document.getElementsByClassName('play_pause playing')[0].click()"];
            else [self.mainWebView stringByEvaluatingJavaScriptFromString:@"document.getElementsByClassName('play_pause')[0].click()"];
            break;
        }

        case eighttracks:
        {
            if (playing) [self.mainWebView stringByEvaluatingJavaScriptFromString:@"document.getElementById('player_pause_button').click()"];
            else [self.mainWebView stringByEvaluatingJavaScriptFromString:@"document.getElementById('player_play_button').click()"];
            break;
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

        case lastfm:
            [self.mainWebView stringByEvaluatingJavaScriptFromString:@"document.getElementsByClassName('radiocontrol')[5].click()"];
            break;

        case grooveshark:
        {
            [self.mainWebView stringByEvaluatingJavaScriptFromString:@"document.getElementById('play-next').click()"];
            break;
        }

        case rdio:
        {
            [self.mainWebView stringByEvaluatingJavaScriptFromString:@"document.getElementsByClassName('next')[0].click()"];
            break;
        }

        case eighttracks:
        {
            [self.mainWebView stringByEvaluatingJavaScriptFromString:@"document.getElementById('player_skip_button').click()"];
            break;
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

        case lastfm:
        {
            [self.mainWebView stringByEvaluatingJavaScriptFromString:@"document.getElementsByClassName('radiocontrol')[0].click()"];
            break;
        }

        case grooveshark:
        {
            [self.mainWebView stringByEvaluatingJavaScriptFromString:@"document.getElementById('play-prev').click()"];
            break;
        }

        case rdio:
        {
            [self.mainWebView stringByEvaluatingJavaScriptFromString:@"document.getElementsByClassName('prev')[0].click()"];
            break;
        }

        case eighttracks:
        {
            [self.mainWebView stringByEvaluatingJavaScriptFromString:@"document.getElementById('fav_8782970').click()"];
            break;
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
