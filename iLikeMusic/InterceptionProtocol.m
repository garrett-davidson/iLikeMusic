//
//  InterceptionProtocol.m
//  iLikeMusic
//
//  Created by Garrett Davidson on 12/14/13.
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

#import "InterceptionProtocol.h"
#import "CaptureWindowController.h"

@implementation InterceptionProtocol

+ (BOOL) canInitWithRequest:(NSURLRequest*)request
{
    id delegate = [NSURLProtocol propertyForKey:@"MyApp" inRequest:request];

    //Temp
    if (delegate) NSLog(@"Can init: %@", request);
    const NSPredicate *rdioPredicate = [NSPredicate predicateWithFormat:@"SELF like \"m.cdn?.rd*io*\""];
    if([rdioPredicate evaluateWithObject:request.URL.host]) NSLog(@"Intercept");

    return (delegate != nil);
}

- (id) initWithRequest:(NSURLRequest*)theRequest
        cachedResponse:(NSCachedURLResponse*)cachedResponse
                client:(id<NSURLProtocolClient>)client
{
    // Move the delegate from the request to this instance
    NSMutableURLRequest* req = (NSMutableURLRequest*)theRequest;
    _delegate = [NSURLProtocol propertyForKey:@"MyApp" inRequest:req];
    [NSURLProtocol removePropertyForKey:@"MyApp" inRequest:req];


    // Complete my setup
    self = [super initWithRequest:req cachedResponse:cachedResponse client:client];
    if (self) {
        _data = [NSMutableData data];
        [NSURLProtocol setProperty:self forKey:@"protocol" inRequest:(NSMutableURLRequest *)self.request];
    }
    return self;
}

- (void) startLoading
{
    _connection = [NSURLConnection connectionWithRequest:[self request] delegate:self];
}

- (void) stopLoading
{
    [_connection cancel];
}

- (void)connection:(NSURLConnection*)conn didReceiveResponse:(NSURLResponse*)response
{
    [[self client] URLProtocol:self didReceiveResponse:response cacheStoragePolicy:[[self request] cachePolicy]];
    [_data setLength:0];
}

- (void)connection:(NSURLConnection*)connection didReceiveData:(NSData*)data
{
    [[self client] URLProtocol:self didLoadData:data];
    [_data appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection*)conn
{
    [[self client] URLProtocolDidFinishLoading:self];

    // Forward the response to your delegate however you like
    if (_delegate && [_delegate respondsToSelector:@selector(saveSong:)]) {
        [_delegate saveSong:_data];
    }
}

- (NSURLRequest*)connection:(NSURLConnection*)connection willSendRequest:(NSURLRequest*)theRequest redirectResponse:(NSURLResponse*)redirectResponse
{
    return theRequest;
}

- (void)connection:(NSURLConnection*)conn didFailWithError:(NSError*)error
{
    [[self client] URLProtocol:self didFailWithError:error];
}

@end
