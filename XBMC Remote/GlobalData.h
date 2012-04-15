//
//  GlobalData.h
//  XBMC Remote
//
//  Created by Giovanni Messina on 27/3/12.
//  Copyright (c) 2012 Korec s.r.l. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GlobalData : NSObject{    
    NSString *serverDescription; 
    NSString *serverUser; 
    NSString *serverPass; 
    NSString *serverIP; 
    NSString *serverPort; 

    
}    
@property(nonatomic,retain)NSString *serverDescription;    
@property(nonatomic,retain)NSString *serverUser;    
@property(nonatomic,retain)NSString *serverPass;    
@property(nonatomic,retain)NSString *serverIP;    
@property(nonatomic,retain)NSString *serverPort;    
+(GlobalData*)getInstance;    
@end  