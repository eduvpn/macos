//
//  Statistics.h
//  eduVPN
//
//  Created by Johan Kool on 09/08/2017.
//  Copyright © 2017 EduVPN. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 Statistics for current session
 */
@interface Statistics : NSObject <NSSecureCoding>

@property (nonatomic, readonly, strong) NSDateComponents *duration;
@property (nonatomic, readonly, assign) NSInteger tunTapReadBytes;
@property (nonatomic, readonly, assign) NSInteger tunTapWriteBytes;
@property (nonatomic, readonly, assign) NSInteger tcpUdpReadBytes;
@property (nonatomic, readonly, assign) NSInteger tcpUdpWriteBytes;
@property (nonatomic, readonly, assign) NSInteger authReadBytes;
@property (nonatomic, readonly, assign) NSInteger precompressBytes;
@property (nonatomic, readonly, assign) NSInteger postcompressBytes;
@property (nonatomic, readonly, assign) NSInteger predecompressBytes;
@property (nonatomic, readonly, assign) NSInteger postdecompressBytes;

- (instancetype)initWithDuration:(NSDateComponents *)duration tunTapReadBytes:(NSInteger)tunTapReadBytes tunTapWriteBytes:(NSInteger)tunTapWriteBytes tcpUdpReadBytes:(NSInteger)tcpUdpReadBytes tcpUdpWriteBytes:(NSInteger)tcpUdpWriteBytes authReadBytes:(NSInteger)authReadBytes precompressBytes:(NSInteger)precompressBytes postcompressBytes:(NSInteger)postcompressBytes predecompressBytes:(NSInteger)predecompressBytes postdecompressBytes:(NSInteger)postdecompressBytes;

@end
