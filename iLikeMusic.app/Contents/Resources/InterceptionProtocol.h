//
//  InterceptionProtocol.h
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

#import <Foundation/Foundation.h>

@interface InterceptionProtocol : NSURLProtocol
{
    id _delegate;
    NSURLConnection* _connection;
    NSMutableData* _data;
}

@property (nonatomic) NSMutableData *data;

@end
