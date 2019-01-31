//
//  OpenVPNStatus.h
//  eduVPN
//
//  Created by Johan Kool on 30/01/2019.
//  Copyright © 2019 EduVPN. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface OpenVPNStatus : NSObject

+ (instancetype)successStatus;
+ (instancetype)errorStatus:(NSString *_Nonnull)errorTitle;
+ (instancetype)errorStatus:(NSString *_Nonnull)errorTitle dangerousCommands:(NSArray <NSString *>*_Nonnull)dangerousCommands;

@property (nonatomic, assign, readonly) BOOL success;
@property (nonatomic, copy, readonly) NSString *errorTitle;
@property (nonatomic, copy, readonly) NSArray <NSString *>*dangerousCommands;

@end
