//
//  tcpJSONRPC.m
//  XBMC Remote
//
//  Created by Giovanni Messina on 22/11/12.
//  Copyright (c) 2012 joethefox inc. All rights reserved.
//

#import "tcpJSONRPC.h"
#import "AppDelegate.h"

#define SERVER_TIMEOUT 2.0f

NSInputStream	*inStream;
NSOutputStream	*outStream;
//	CFWriteStreamRef writeStream;

@implementation tcpJSONRPC

-(id)init{
    if ((self = [super init])){
        heartbeatTimer = [NSTimer scheduledTimerWithTimeInterval:SERVER_TIMEOUT target:self selector:@selector(checkServer) userInfo:nil repeats:YES];
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(handleSystemOnSleep:)
                                                     name: @"System.OnSleep"
                                                   object: nil];
    }
    return self;
}

-(void)handleSystemOnSleep:(NSNotification *)sender{
    [AppDelegate instance].serverTCPConnectionOpen = NO;
}

- (void)startNetworkCommunicationWithServer:(NSString *)server serverPort:(int)port{
    if (port == 0){
        port = 9090;
    }
    CFReadStreamRef readStream;
	CFStreamCreatePairWithSocketToHost(NULL, (CFStringRef)CFBridgingRetain(server), port, &readStream, NULL);
	inStream = (NSInputStream *)CFBridgingRelease(readStream);
//	outStream = (__bridge NSOutputStream *)writeStream;
	[inStream setDelegate:self];
//	[outStream setDelegate:self];
	[inStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
//	[outStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
	[inStream open];
//	[outStream open];
}

-(NSStreamStatus)currentSocketInStatus{
    return [inStream streamStatus];
}

-(void)stopNetworkCommunication{
    [AppDelegate instance].serverTCPConnectionOpen = NO;
    NSStreamStatus current_status =[inStream streamStatus];
    if (current_status == NSStreamStatusOpen){
        [inStream close];
        [inStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [inStream setDelegate:nil];
        inStream = nil;
    }
}

- (void)stream:(NSStream *)theStream handleEvent:(NSStreamEvent)streamEvent {

	switch (streamEvent) {
    
		case NSStreamEventOpenCompleted:
            [AppDelegate instance].serverTCPConnectionOpen = YES;
            [[NSNotificationCenter defaultCenter] postNotificationName:@"tcpJSONRPCConnectionOpened" object:nil userInfo:nil];
			break;
            
		case NSStreamEventHasBytesAvailable:
			if (theStream == inStream) {
				uint8_t buffer[1024];
				int len;
				while ([inStream hasBytesAvailable]) {
					len = [inStream read:buffer maxLength:sizeof(buffer)];
					if (len > 0) {
						NSData *output = [[NSData alloc] initWithBytes:buffer length:len];
						if (nil != output) {
                            NSError *parseError = nil;
                            NSDictionary *notification = [NSJSONSerialization JSONObjectWithData:output options:kNilOptions error:&parseError];
                            if (parseError == nil){
                                NSString *method = @"";
                                NSString *params = @"";
                                NSDictionary *paramsDict;
                                if (((NSNull *)[notification objectForKey:@"method"] != [NSNull null])){
                                        method = [notification objectForKey:@"method"];
                                    if (((NSNull *)[notification objectForKey:@"params"] != [NSNull null])){
                                        params = [notification objectForKey:@"params"];
                                        paramsDict = [NSDictionary dictionaryWithObject:[notification objectForKey:@"params"] forKey:@"params"];
                                    }
                                    [[NSNotificationCenter defaultCenter] postNotificationName:method object:nil userInfo:paramsDict];
                                }
                            }
						}
					}
				}
			}
			break;
            
		case NSStreamEventErrorOccurred:
            [AppDelegate instance].serverTCPConnectionOpen = NO;
            inCheck = NO;
            [[NSNotificationCenter defaultCenter] postNotificationName:@"tcpJSONRPCConnectionError" object:nil userInfo:nil];
			break;
			
		case NSStreamEventEndEncountered:
            [AppDelegate instance].serverTCPConnectionOpen = NO;
            inCheck = NO;
            [theStream close];
            [theStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
            [theStream setDelegate:nil];
            theStream = nil;
            [[NSNotificationCenter defaultCenter] postNotificationName:@"tcpJSONRPCConnectionClosed" object:nil userInfo:nil];

            break;
		default:
            break;
	}    
}


-(void)noConnectionNotifications{
    NSString *infoText = NSLocalizedString(@"No connection", nil);
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            [NSNumber numberWithBool:NO], @"status",
                            infoText, @"message",
                            nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"TcpJSONRPCChangeServerStatus" object:nil userInfo:params];
}

-(void)checkServer{
    if (inCheck) return;
    jsonRPC=nil;
    if ([[AppDelegate instance].obj.serverIP length] == 0){
        NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], @"showSetup", nil];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"TcpJSONRPCShowSetup" object:nil userInfo:params];
        if ([AppDelegate instance].serverOnLine){
            [self noConnectionNotifications];
        }
        return;
    }
    if ([AppDelegate instance].serverTCPConnectionOpen == YES){
        return;
    }
    inCheck = TRUE;
    NSString *userPassword = [[AppDelegate instance].obj.serverPass isEqualToString:@""] ? @"" : [NSString stringWithFormat:@":%@", [AppDelegate instance].obj.serverPass];
    NSString *serverJSON = [NSString stringWithFormat:@"http://%@%@@%@:%@/jsonrpc", [AppDelegate instance].obj.serverUser, userPassword, [AppDelegate instance].obj.serverIP, [AppDelegate instance].obj.serverPort];
    jsonRPC = [[DSJSONRPC alloc] initWithServiceEndpoint:[NSURL URLWithString:serverJSON]];
    NSString *checkServerParams = [NSDictionary dictionaryWithObjectsAndKeys: [[NSArray alloc] initWithObjects:@"version", @"volume", nil], @"properties", nil];
    [jsonRPC
     callMethod:@"Application.GetProperties"
     withParameters:checkServerParams
     withTimeout: SERVER_TIMEOUT
     onCompletion:^(NSString *methodName, NSInteger callId, id methodResult, DSJSONRPCError *methodError, NSError* error) {
         inCheck = FALSE;
         if (error==nil && methodError==nil){
             [AppDelegate instance].serverVolume = [[methodResult objectForKey:@"volume"] intValue];
             if (![AppDelegate instance].serverOnLine){
                 if( [NSJSONSerialization isValidJSONObject:methodResult]){
                     NSDictionary *serverInfo=[methodResult objectForKey:@"version"];
                     [AppDelegate instance].serverVersion = [[serverInfo objectForKey:@"major"] intValue];
                     [AppDelegate instance].serverMinorVersion = [[serverInfo objectForKey:@"minor"] intValue];
                     NSString *infoTitle=[NSString stringWithFormat:@"%@ v%@.%@ %@",
                                          [AppDelegate instance].obj.serverDescription,
                                          [serverInfo objectForKey:@"major"],
                                          [serverInfo objectForKey:@"minor"],
                                          [serverInfo objectForKey:@"tag"]];//, [serverInfo objectForKey:@"revision"]
                     NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                                             [NSNumber numberWithBool:YES], @"status",
                                             infoTitle, @"message",
                                             nil];
                     [[NSNotificationCenter defaultCenter] postNotificationName:@"TcpJSONRPCChangeServerStatus" object:nil userInfo:params];
                     params = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:NO], @"showSetup", nil];
                     [[NSNotificationCenter defaultCenter] postNotificationName:@"TcpJSONRPCShowSetup" object:nil userInfo:params];
                 }
                 else{
                     if ([AppDelegate instance].serverOnLine){
                         [self noConnectionNotifications];            
                     }
                     NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], @"showSetup", nil];
                     [[NSNotificationCenter defaultCenter] postNotificationName:@"TcpJSONRPCShowSetup" object:nil userInfo:params];
                 }
             }
         }
         else {
             [AppDelegate instance].serverVolume = -1;
             if ([AppDelegate instance].serverOnLine){
                 [self noConnectionNotifications];
             }
             NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], @"showSetup", nil];
             [[NSNotificationCenter defaultCenter] postNotificationName:@"TcpJSONRPCShowSetup" object:nil userInfo:params];
         }
     }];
    jsonRPC=nil;
}


- (void)dealloc{
    inStream = nil;
    [[NSNotificationCenter defaultCenter] removeObserver: self];
//    outStream = nil;
}

@end