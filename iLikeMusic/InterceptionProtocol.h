//
//  InterceptionProtocol.h
//  iLikeMusic
//
//  Created by Garrett Davidson on 12/14/13.
//  Copyright (c) 2013 Garrett Davidson. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface InterceptionProtocol : NSURLProtocol
{
    id _delegate;
    NSURLConnection* _connection;
    NSMutableData* _data;
}

@end
