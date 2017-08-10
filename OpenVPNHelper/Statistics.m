//
//  Statistics.m
//  eduVPN
//
//  Created by Johan Kool on 09/08/2017.
//  Copyright © 2017 EduVPN. All rights reserved.
//

#import "Statistics.h"

@implementation Statistics

- (instancetype)initWithDuration:(NSDateComponents *)duration tunTapReadBytes:(NSInteger)tunTapReadBytes tunTapWriteBytes:(NSInteger)tunTapWriteBytes tcpUdpReadBytes:(NSInteger)tcpUdpReadBytes tcpUdpWriteBytes:(NSInteger)tcpUdpWriteBytes authReadBytes:(NSInteger)authReadBytes precompressBytes:(NSInteger)precompressBytes postcompressBytes:(NSInteger)postcompressBytes predecompressBytes:(NSInteger)predecompressBytes postdecompressBytes:(NSInteger)postdecompressBytes {
    self = [super init];
    if (self) {
        _duration = duration;
        _tunTapReadBytes = tunTapReadBytes;
        _tunTapWriteBytes = tunTapWriteBytes;
        _tcpUdpReadBytes = tcpUdpReadBytes;
        _tcpUdpWriteBytes = tcpUdpWriteBytes;
        _authReadBytes = authReadBytes;
        _precompressBytes = precompressBytes;
        _postcompressBytes = postcompressBytes;
        _predecompressBytes = predecompressBytes;
        _postdecompressBytes = postdecompressBytes;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self) {
        _duration = [aDecoder decodeObjectOfClass:[NSDateComponents class] forKey:@"duration"];
        _tunTapReadBytes = [aDecoder decodeIntegerForKey:@"tunTapReadBytes"];
        _tunTapWriteBytes = [aDecoder decodeIntegerForKey:@"tunTapWriteBytes"];
        _tcpUdpReadBytes = [aDecoder decodeIntegerForKey:@"tcpUdpReadBytes"];
        _tcpUdpWriteBytes = [aDecoder decodeIntegerForKey:@"tcpUdpWriteBytes"];
        _authReadBytes = [aDecoder decodeIntegerForKey:@"authReadBytes"];
        _precompressBytes = [aDecoder decodeIntegerForKey:@"precompressBytes"];
        _postcompressBytes = [aDecoder decodeIntegerForKey:@"postcompressBytes"];
        _predecompressBytes = [aDecoder decodeIntegerForKey:@"predecompressBytes"];
        _postdecompressBytes = [aDecoder decodeIntegerForKey:@"postdecompressBytes"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeInteger:1 forKey:@"version"];
    [aCoder encodeObject:self.duration forKey:@"duration"];
    [aCoder encodeInteger:self.tunTapReadBytes forKey:@"tunTapReadBytes"];
    [aCoder encodeInteger:self.tunTapWriteBytes forKey:@"tunTapWriteBytes"];
    [aCoder encodeInteger:self.tcpUdpReadBytes forKey:@"tcpUdpReadBytes"];
    [aCoder encodeInteger:self.tcpUdpWriteBytes forKey:@"tcpUdpWriteBytes"];
    [aCoder encodeInteger:self.authReadBytes forKey:@"authReadBytes"];
    [aCoder encodeInteger:self.precompressBytes forKey:@"precompressBytes"];
    [aCoder encodeInteger:self.postcompressBytes forKey:@"postcompressBytes"];
    [aCoder encodeInteger:self.predecompressBytes forKey:@"predecompressBytes"];
    [aCoder encodeInteger:self.postdecompressBytes forKey:@"postdecompressBytes"];
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

@end
