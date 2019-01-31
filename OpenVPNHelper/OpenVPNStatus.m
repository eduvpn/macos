//
//  OpenVPNStatus.m
//  eduVPN
//
//  Created by Johan Kool on 30/01/2019.
//  Copyright © 2019 EduVPN. All rights reserved.
//

#import "OpenVPNStatus.h"

@interface OpenVPNStatus ()

@property (nonatomic, assign, readwrite) BOOL success;
@property (nonatomic, copy, readwrite) NSString *errorTitle;
@property (nonatomic, copy, readwrite) NSArray <NSString *>*dangerousCommands;

@end

@implementation OpenVPNStatus

    + (instancetype)successStatus {
        OpenVPNStatus *status = [[OpenVPNStatus alloc] init];
        status.success = YES;
        return status;
    }
+ (instancetype)errorStatus:(NSString *_Nonnull)errorTitle {
    OpenVPNStatus *status = [[OpenVPNStatus alloc] init];
    status.success = NO;
    status.errorTitle = errorTitle;
    return status;
}

+ (instancetype)errorStatus:(NSString *_Nonnull)errorTitle dangerousCommands:(NSArray <NSString *>*_Nonnull)dangerousCommands {
    OpenVPNStatus *status = [[OpenVPNStatus alloc] init];
    status.success = YES;
    status.errorTitle = errorTitle;
    status.dangerousCommands = dangerousCommands;
    return status;
}
    
@end
