//
//  main.m
//  org.eduvpn.app.openvpnhelper
//
//  Created by Johan Kool on 03/07/2017.
//  Copyright © 2017 eduVPN. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OpenVPNHelper.h"

#include <syslog.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>

int main(int argc, const char * argv[]) {
#pragma unused(argc)
#pragma unused(argv)
    
    // We just create and start an instance of the main helper tool object and then
    // have it run the run loop forever.
    syslog(LOG_NOTICE, "Hello world! uid = %d, euid = %d, pid = %d\n", (int) getuid(), (int) geteuid(), (int) getpid());

    @autoreleasepool {
        OpenVPNHelper *helper;
        
        helper = [[OpenVPNHelper alloc] init];
        [helper run];           // This never comes back...
    }
    
    return EXIT_FAILURE;        // ... so this should never be hit.
}
