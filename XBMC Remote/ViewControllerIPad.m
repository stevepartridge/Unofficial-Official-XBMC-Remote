//
//  ViewControllerIPad.m
//  XBMC Remote
//
//  Created by Giovanni Messina on 29/4/12.
//  Copyright (c) 2012 joethefox inc. All rights reserved.
//

#import "ViewControllerIPad.h"
#import "StackScrollViewController.h"
#import "MenuViewController.h"
#import "NowPlaying.h"
#import "mainMenu.h"
#import "GlobalData.h"
#import "AppDelegate.h"
#import "HostManagementViewController.h"
#import "AppInfoViewController.h"
#import "XBMCVirtualKeyboard.h"
#import "ClearCacheView.h"

#define CONNECTION_TIMEOUT 240.0f
#define SERVER_TIMEOUT 2.0f

@interface ViewControllerIPad (){
    NSMutableArray *mainMenu;
}
@end

@interface UIViewExt : UIView {} 
@end


@implementation UIViewExt
- (UIView *) hitTest: (CGPoint) pt withEvent: (UIEvent *) event {   
	
	UIView* viewToReturn=nil;
	CGPoint pointToReturn;
	
	UIView* uiRightView = (UIView*)[[self subviews] objectAtIndex:1];
	
	if ([[uiRightView subviews] objectAtIndex:0]) {
		
		UIView* uiStackScrollView = [[uiRightView subviews] objectAtIndex:0];	
		
		if ([[uiStackScrollView subviews] objectAtIndex:1]) {	 
			
			UIView* uiSlideView = [[uiStackScrollView subviews] objectAtIndex:1];	
			
			for (UIView* subView in [uiSlideView subviews]) {
				CGPoint point  = [subView convertPoint:pt fromView:self];
				if ([subView pointInside:point withEvent:event]) {
					viewToReturn = subView;
					pointToReturn = point;
				}
				
			}
		}
		
	}
	
	if(viewToReturn != nil) {
		return [viewToReturn hitTest:pointToReturn withEvent:event];		
	}
	
	return [super hitTest:pt withEvent:event];	
	
}
@end



@implementation ViewControllerIPad

@synthesize mainMenu;
@synthesize menuViewController, stackScrollViewController;
@synthesize nowPlayingController;
@synthesize serverPickerPopover = _serverPickerPopover;
@synthesize hostPickerViewController = _hostPickerViewController;
@synthesize appInfoView = _appInfoView;
@synthesize appInfoPopover = _appInfoPopover;
@synthesize tcpJSONRPCconnection;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

#pragma mark - ServerManagement

-(void)selectServerAtIndexPath:(NSIndexPath *)indexPath{
    storeServerSelection = indexPath;
    NSDictionary *item = [[AppDelegate instance].arrayServerList objectAtIndex:indexPath.row];
    [AppDelegate instance].obj.serverDescription = [item objectForKey:@"serverDescription"];
    [AppDelegate instance].obj.serverUser = [item objectForKey:@"serverUser"];
    [AppDelegate instance].obj.serverPass = [item objectForKey:@"serverPass"];
    [AppDelegate instance].obj.serverIP = [item objectForKey:@"serverIP"];
    [AppDelegate instance].obj.serverPort = [item objectForKey:@"serverPort"];
    [AppDelegate instance].obj.tcpPort = [[item objectForKey:@"tcpPort"] intValue];
}

-(void)wakeUp:(NSString *)macAddress{
    [[AppDelegate instance] wake:macAddress];
}

-(void)changeServerStatus:(BOOL)status infoText:(NSString *)infoText{
    if (status==YES){
        [self.tcpJSONRPCconnection startNetworkCommunicationWithServer:[AppDelegate instance].obj.serverIP serverPort:[AppDelegate instance].obj.tcpPort];
        [[NSNotificationCenter defaultCenter] postNotificationName: @"XBMCServerConnectionSuccess" object: nil];
        [AppDelegate instance].serverOnLine=YES;
        [AppDelegate instance].serverName = infoText;

        [volumeSliderView startTimer];
        UITableViewCell *cell = [menuViewController.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
        UIImageView *icon = (UIImageView*) [cell viewWithTag:1];
        [icon setImage:[UIImage imageNamed:@"connection_on"]];
        [xbmcInfo setTitle:infoText forState:UIControlStateNormal];
        int n = [menuViewController.tableView numberOfRowsInSection:0];
        for (int i=1;i<n;i++){
            UITableViewCell *cell = [menuViewController.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0]];
            if (cell!=nil){
                cell.selectionStyle=UITableViewCellSelectionStyleBlue;
                [UIView beginAnimations:nil context:nil];
                [UIView setAnimationDuration:0.3];
                [(UIImageView*) [cell viewWithTag:1] setAlpha:1.0];
                [(UIImageView*) [cell viewWithTag:2] setAlpha:1.0];
                [(UIImageView*) [cell viewWithTag:3] setAlpha:1.0];
                [UIView commitAnimations];
            }
        }
    }
    else{
        [self.tcpJSONRPCconnection stopNetworkCommunication];
        [[NSNotificationCenter defaultCenter] postNotificationName: @"XBMCServerConnectionFailed" object:nil userInfo:nil];
        [AppDelegate instance].serverOnLine=NO;
        [AppDelegate instance].serverName = infoText;

        UITableViewCell *cell = [menuViewController.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
        UIImageView *icon = (UIImageView*) [cell viewWithTag:1];
        [icon setImage:[UIImage imageNamed:@"connection_off"]];
        [xbmcInfo setTitle:infoText forState:UIControlStateNormal];
        int n = [menuViewController.tableView numberOfRowsInSection:0];
        for (int i=1;i<n;i++){
            UITableViewCell *cell = [menuViewController.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0]];
            if (cell!=nil){
                cell.selectionStyle=UITableViewCellSelectionStyleGray;
                [UIView beginAnimations:nil context:nil];
                [UIView setAnimationDuration:0.3];
                
                [(UIImageView*) [cell viewWithTag:1] setAlpha:0.3];
                [(UIImageView*) [cell viewWithTag:2] setAlpha:0.3];
                [(UIImageView*) [cell viewWithTag:3] setAlpha:0.3];
                [UIView commitAnimations];
            }
        }
        if (![extraTimer isValid])
            extraTimer = [NSTimer scheduledTimerWithTimeInterval:CONNECTION_TIMEOUT target:self selector:@selector(offStackView) userInfo:nil repeats:NO];
    }
}

-(void) offStackView{
    if (![AppDelegate instance].serverOnLine){
        [[AppDelegate instance].windowController.stackScrollViewController offView];
        NSIndexPath *selection=[menuViewController.tableView indexPathForSelectedRow];
        if (selection){
            [menuViewController.tableView deselectRowAtIndexPath:selection animated:YES];
            [menuViewController setLastSelected:-1];
        }
    }
    [extraTimer invalidate];
    extraTimer = nil;
}

# pragma mark - toolbar management

-(void)toggleViewToolBar:(UIView*)view AnimDuration:(float)seconds Alpha:(float)alphavalue YPos:(int)Y forceHide:(BOOL)hide {
	[UIView beginAnimations:nil context:nil];
    [UIView setAnimationCurve:UIViewAnimationCurveEaseOut];
	[UIView setAnimationDuration:seconds];
    int actualPosY=view.frame.origin.y;
    CGRect frame;
	frame = [view frame];
    if (actualPosY<667 || hide){
        Y=self.view.frame.size.height;
    }
    view.alpha = alphavalue;
	frame.origin.y = Y;
    view.frame = frame;
    [UIView commitAnimations];
}

- (void)toggleVolume{
    [self toggleViewToolBar:volumeSliderView AnimDuration:0.3 Alpha:1.0 YPos:volumeSliderView.frame.origin.y - volumeSliderView.frame.size.height - 42 forceHide:FALSE];
}

- (void)toggleSetup {
    if (_hostPickerViewController == nil) {
        
        self.hostPickerViewController = [[HostManagementViewController alloc] initWithNibName:@"HostManagementViewController" bundle:nil];
        [AppDelegate instance].navigationController = [[UINavigationController alloc] initWithRootViewController:_hostPickerViewController];
        self.serverPickerPopover = [[UIPopoverController alloc] 
                                    initWithContentViewController:[AppDelegate instance].navigationController];
        self.serverPickerPopover.delegate = self;
        [self.serverPickerPopover setPopoverContentSize:CGSizeMake(320, 436)];
    }
    [self.serverPickerPopover presentPopoverFromRect:xbmcInfo.frame inView:self.view permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
}

-(void) showSetup:(BOOL)show{
    firstRun = NO;
    if ([self.serverPickerPopover isPopoverVisible]) {
        if (show==NO)
            [self.serverPickerPopover dismissPopoverAnimated:YES];
    }
    else{
        if (show==YES){
            [self toggleSetup];
        }
    }
}

- (void)toggleInfoView {
    if (_appInfoView == nil) {
        self.appInfoView = [[AppInfoViewController alloc] initWithNibName:@"AppInfoViewController" bundle:nil];
        self.appInfoPopover = [[UIPopoverController alloc] 
                                    initWithContentViewController:_appInfoView];
        self.appInfoPopover.delegate = self;
        [self.appInfoPopover setPopoverContentSize:CGSizeMake(320, 460)];

    }
    [self.appInfoPopover presentPopoverFromRect:xbmcLogo.frame inView:self.view permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
}
#pragma mark - power control action sheet

-(void)powerControl{
    if ([[AppDelegate instance].obj.serverIP length]==0){
        [self toggleSetup];
        return;
    }
    NSString *title=[NSString stringWithFormat:@"%@\n%@", [AppDelegate instance].obj.serverDescription, [AppDelegate instance].obj.serverIP];
    NSString *destructive = nil;
    NSArray *sheetActions = nil;
    if (![AppDelegate instance].serverOnLine){
        sheetActions=[NSArray arrayWithObjects:NSLocalizedString(@"Wake On Lan", nil), nil];
    }
    else{
        destructive = NSLocalizedString(@"Power off System", nil);
        sheetActions=[NSArray arrayWithObjects: NSLocalizedString(@"Hibernate", nil), NSLocalizedString(@"Suspend", nil), NSLocalizedString(@"Reboot", nil), NSLocalizedString(@"Quit XBMC application", nil), NSLocalizedString(@"Update Audio Library", nil), NSLocalizedString(@"Update Video Library", nil), nil];
    }
    int numActions=[sheetActions count];
    if (numActions){
        actionSheetPower = [[UIActionSheet alloc] initWithTitle:title
                                                            delegate:self
                                                   cancelButtonTitle:nil
                                              destructiveButtonTitle:destructive
                                                   otherButtonTitles:nil];
        actionSheetPower.actionSheetStyle = UIActionSheetStyleBlackTranslucent;
        for (int i = 0; i < numActions; i++) {
            [actionSheetPower addButtonWithTitle:[sheetActions objectAtIndex:i]];
        }
        actionSheetPower.cancelButtonIndex = [actionSheetPower addButtonWithTitle:@"Cancel"];
       [actionSheetPower showFromRect:CGRectMake(powerButton.frame.origin.x + powerButton.frame.size.width/2, powerButton.frame.origin.y, 1, 1) inView:self.view animated:YES];
    }
}

-(void)powerAction:(NSString *)action params:(NSDictionary *)params{
    jsonRPC = nil;
    GlobalData *obj=[GlobalData getInstance]; 
    NSString *userPassword=[obj.serverPass isEqualToString:@""] ? @"" : [NSString stringWithFormat:@":%@", obj.serverPass];
    NSString *serverJSON=[NSString stringWithFormat:@"http://%@%@@%@:%@/jsonrpc", obj.serverUser, userPassword, obj.serverIP, obj.serverPort];
    jsonRPC = [[DSJSONRPC alloc] initWithServiceEndpoint:[NSURL URLWithString:serverJSON]];
    [jsonRPC callMethod:action withParameters:params onCompletion:^(NSString *methodName, NSInteger callId, id methodResult, DSJSONRPCError *methodError, NSError* error) {
        if (methodError==nil && error == nil){
            UIAlertView * alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Command executed", nil) message:nil delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
            [alertView show];
        }
        else{
            UIAlertView * alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Cannot do that", nil) message:nil delegate:nil cancelButtonTitle:nil otherButtonTitles:NSLocalizedString(@"OK", nil), nil];
            [alertView show];
        }
    }];
}

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex{
    if (buttonIndex!=actionSheet.cancelButtonIndex){
        if ([[actionSheet buttonTitleAtIndex:buttonIndex] isEqualToString:NSLocalizedString(@"Wake On Lan", nil)]){
            if ([AppDelegate instance].obj.serverHWAddr != nil){
                [self wakeUp:[AppDelegate instance].obj.serverHWAddr];
                UIAlertView * alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Command executed", nil) message:nil delegate:nil cancelButtonTitle:nil otherButtonTitles:NSLocalizedString(@"OK", nil), nil];
                [alertView show];
            }
            else{
                UIAlertView * alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Warning", nil) message:NSLocalizedString(@"No server MAC address defined", nil) delegate:nil cancelButtonTitle:nil otherButtonTitles:NSLocalizedString(@"OK", nil), nil];
                [alertView show];
            }
        }
        else if ([[actionSheet buttonTitleAtIndex:buttonIndex] isEqualToString:NSLocalizedString(@"Power off System", nil)]){
            [self powerAction:@"System.Shutdown" params:[NSDictionary dictionaryWithObjectsAndKeys:nil]];
        }
        else if ([[actionSheet buttonTitleAtIndex:buttonIndex] isEqualToString:NSLocalizedString(@"Quit XBMC application", nil)]){
            [self powerAction:@"Application.Quit" params:[NSDictionary dictionaryWithObjectsAndKeys:nil]];
        }
        else if ([[actionSheet buttonTitleAtIndex:buttonIndex] isEqualToString:NSLocalizedString(@"Hibernate", nil)]){
            [self powerAction:@"System.Hibernate" params:[NSDictionary dictionaryWithObjectsAndKeys:nil]];
        }
        else if ([[actionSheet buttonTitleAtIndex:buttonIndex] isEqualToString:NSLocalizedString(@"Suspend", nil)]){
            [self powerAction:@"System.Suspend" params:[NSDictionary dictionaryWithObjectsAndKeys:nil]];
        }
        else if ([[actionSheet buttonTitleAtIndex:buttonIndex] isEqualToString:NSLocalizedString(@"Reboot", nil)]){
            [self powerAction:@"System.Reboot" params:[NSDictionary dictionaryWithObjectsAndKeys:nil]];
        }
        else if ([[actionSheet buttonTitleAtIndex:buttonIndex] isEqualToString:NSLocalizedString(@"Update Audio Library", nil)]){
            [self powerAction:@"AudioLibrary.Scan" params:[NSDictionary dictionaryWithObjectsAndKeys:nil]];
        }
        else if ([[actionSheet buttonTitleAtIndex:buttonIndex] isEqualToString:NSLocalizedString(@"Update Video Library", nil)]){
            [self powerAction:@"VideoLibrary.Scan" params:[NSDictionary dictionaryWithObjectsAndKeys:nil]];
        }
    }
}

#pragma mark - Touch Events

- (void) touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    CGPoint locationPoint = [[touches anyObject] locationInView:self.view];
    CGPoint viewPoint = [self.nowPlayingController.jewelView convertPoint:locationPoint fromView:self.view];
    CGPoint viewPoint2 = [self.nowPlayingController.shuffleButton convertPoint:locationPoint fromView:self.view];
    CGPoint viewPoint3 = [self.nowPlayingController.repeatButton convertPoint:locationPoint fromView:self.view];
    
    if ([self.nowPlayingController.shuffleButton pointInside:viewPoint2 withEvent:event] && self.nowPlayingController.songDetailsView.alpha > 0 && !self.nowPlayingController.shuffleButton.hidden) {
        [self.nowPlayingController changeShuffle:nil];
    }
    else if ([self.nowPlayingController.repeatButton pointInside:viewPoint3 withEvent:event]  && self.nowPlayingController.songDetailsView.alpha > 0 && !self.nowPlayingController.repeatButton.hidden) {
        [self.nowPlayingController changeRepeat:nil];
    }
    else if ([self.nowPlayingController.jewelView pointInside:viewPoint withEvent:event]) {
        [self.nowPlayingController toggleSongDetails];
    }
}

#pragma mark - App clear disk cache methods

-(void)startClearAppDiskCache:(ClearCacheView *)clearView{
    [[AppDelegate instance] clearAppDiskCache];
    [self performSelectorOnMainThread:@selector(clearAppDiskCacheFinished:) withObject:clearView waitUntilDone:YES];
}

-(void)clearAppDiskCacheFinished:(ClearCacheView *)clearView{
    [UIView animateWithDuration:0.3
                     animations:^{
                         [clearView stopActivityIndicator];
                         clearView.alpha = 0;
                     }
                     completion:^(BOOL finished){
                         [clearView stopActivityIndicator];
                         [clearView removeFromSuperview];
                         NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
                         [userDefaults synchronize];
                         [userDefaults removeObjectForKey:@"clearcache_preference"];
                     }];
}

#pragma mark - Lifecycle

- (void)viewDidLoad{
    [super viewDidLoad];
    self.tcpJSONRPCconnection = [[tcpJSONRPC alloc] init];
    XBMCVirtualKeyboard *virtualKeyboard = [[XBMCVirtualKeyboard alloc] initWithFrame:CGRectMake(0, 0, 1, 1)];
    [self.view addSubview:virtualKeyboard];
    firstRun=YES;
    [AppDelegate instance].obj=[GlobalData getInstance]; 

    int cellHeight = 56;
    int infoHeight = 22;
    int tableHeight = ([(NSMutableArray *)mainMenu count] - 1) * cellHeight + infoHeight;
    int tableWidth = 300;
    int headerHeight=0;
   
    rootView = [[UIViewExt alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height)];
	rootView.autoresizingMask = UIViewAutoresizingFlexibleWidth + UIViewAutoresizingFlexibleHeight;
	[rootView setBackgroundColor:[UIColor clearColor]];
	
	leftMenuView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableWidth, self.view.frame.size.height)];
	leftMenuView.autoresizingMask = UIViewAutoresizingFlexibleHeight;	
    
	menuViewController = [[MenuViewController alloc] initWithFrame:CGRectMake(0, headerHeight, leftMenuView.frame.size.width, leftMenuView.frame.size.height) mainMenu:mainMenu];
	[menuViewController.view setBackgroundColor:[UIColor clearColor]];
	[menuViewController viewWillAppear:FALSE];
	[menuViewController viewDidAppear:FALSE];
	[leftMenuView addSubview:menuViewController.view];
    int separator = 2;
    
//    CGRect seamBackground = CGRectMake(0.0f, tableHeight + headerHeight - 2, tableWidth, separator);
//    UIImageView *seam = [[UIImageView alloc] initWithFrame:seamBackground];
//    [seam setImage:[UIImage imageNamed:@"denim_single_seam.png"]];
//    seam.opaque = YES;
//    [leftMenuView addSubview:seam];
    
    UIView* horizontalLineView1 = [[UIView alloc] initWithFrame:CGRectMake(0.0f, tableHeight + separator - 2, tableWidth, 1)];
//    [horizontalLineView1 setAutoresizingMask:UIViewAutoresizingFlexibleHeight];
    [horizontalLineView1 setBackgroundColor:[UIColor colorWithRed:0.3f green:0.3f blue:0.3f alpha:.2]];
    [leftMenuView addSubview:horizontalLineView1];

    nowPlayingController = [[NowPlaying alloc] initWithNibName:@"NowPlaying" bundle:nil];
    CGRect frame=nowPlayingController.view.frame;
    YPOS=-(tableHeight + separator + headerHeight);
    frame.origin.y=tableHeight + separator + headerHeight;
    frame.size.width=tableWidth;
    frame.size.height=self.view.frame.size.height - tableHeight - separator - headerHeight;
    nowPlayingController.view.autoresizingMask=UIViewAutoresizingFlexibleHeight;
    nowPlayingController.view.frame=frame;
    
    [nowPlayingController setToolbarWidth:768 height:610 YPOS:YPOS playBarWidth:426 portrait:TRUE];
    
    [leftMenuView addSubview:nowPlayingController.view];

	rightSlideView = [[UIView alloc] initWithFrame:CGRectMake(leftMenuView.frame.size.width, 0, rootView.frame.size.width - leftMenuView.frame.size.width, rootView.frame.size.height-44)];
	rightSlideView.autoresizingMask = UIViewAutoresizingFlexibleWidth + UIViewAutoresizingFlexibleHeight;
    
	stackScrollViewController = [[StackScrollViewController alloc] init];	
	[stackScrollViewController.view setFrame:CGRectMake(0, 0, rightSlideView.frame.size.width, rightSlideView.frame.size.height)];
	[stackScrollViewController.view setAutoresizingMask:UIViewAutoresizingFlexibleWidth + UIViewAutoresizingFlexibleHeight];
	[stackScrollViewController viewWillAppear:FALSE];
	[stackScrollViewController viewDidAppear:FALSE];
	[rightSlideView addSubview:stackScrollViewController.view];
	
	[rootView addSubview:leftMenuView];
	[rootView addSubview:rightSlideView];
    
//    self.view.backgroundColor = [UIColor colorWithWhite:.14 alpha:1];
//    self.view.backgroundColor = [[UIColor scrollViewTexturedBackgroundColor] colorWithAlphaComponent:0.5];
//	[self.view setBackgroundColor:[UIColor colorWithPatternImage: [UIImage imageNamed:@"backgroundImage_repeat.png"]]];
    [self.view addSubview:rootView];
    
    xbmcLogo = [[UIButton alloc] initWithFrame:CGRectMake(671, 967, 87, 30)];
    [xbmcLogo setImage:[UIImage imageNamed:@"bottom_logo_up"] forState:UIControlStateNormal];
    [xbmcLogo setImage:[UIImage imageNamed:@"bottom_logo_up"] forState:UIControlStateHighlighted];
    xbmcLogo.showsTouchWhenHighlighted = NO;
    [xbmcLogo addTarget:self action:@selector(toggleInfoView) forControlEvents:UIControlEventTouchUpInside];
    xbmcLogo.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;
    xbmcLogo.alpha = .9f;
    [self.view addSubview:xbmcLogo];
    
    UIButton  *volumeButton = [[UIButton alloc] initWithFrame:CGRectMake(341, 964, 36, 37)];
    [volumeButton setImage:[UIImage imageNamed:@"volume@2x.png"] forState:UIControlStateNormal];
    [volumeButton setImage:[UIImage imageNamed:@"volume@2x.png"] forState:UIControlStateHighlighted];
    [volumeButton setImage:[UIImage imageNamed:@"volume@2x.png"] forState:UIControlStateSelected];
    volumeButton.alpha = 0.1;
    volumeButton.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin;
    volumeButton.contentMode = UIViewContentModeScaleAspectFit;
    [self.view addSubview:volumeButton];
    
    volumeSliderView = [[VolumeSliderView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 62.0f, 296.0f)];
    volumeSliderView.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin;
    frame=volumeSliderView.frame;
    frame.origin.x=408;
    frame.origin.y=self.view.frame.size.height - 170;
    volumeSliderView.frame=frame;
    CGAffineTransform trans = CGAffineTransformMakeRotation(M_PI * 0.5);
    volumeSliderView.transform = trans;
    [self.view addSubview:volumeSliderView];
    
    xbmcInfo = [[UIButton alloc] initWithFrame:CGRectMake(428, 966, 190, 33)]; //225
    [xbmcInfo setTitle:NSLocalizedString(@"No connection", nil) forState:UIControlStateNormal];
    xbmcInfo.titleLabel.font = [UIFont systemFontOfSize:11];
    xbmcInfo.titleLabel.minimumFontSize=6.0f;
    xbmcInfo.titleLabel.numberOfLines=2;
    xbmcInfo.titleLabel.textAlignment=UITextAlignmentCenter;
    xbmcInfo.titleEdgeInsets=UIEdgeInsetsMake(0, 3, 0, 3);
    xbmcInfo.titleLabel.shadowColor = [UIColor blackColor];
    xbmcInfo.titleLabel.shadowOffset    = CGSizeMake (1.0, 1.0);
    [xbmcInfo setBackgroundImage:[[UIImage imageNamed: @"now_playing_empty_up"] resizableImageWithCapInsets:UIEdgeInsetsMake(0, 6, 0, 6)] forState:UIControlStateNormal];
    xbmcInfo.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;
    [xbmcInfo addTarget:self action:@selector(toggleSetup) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:xbmcInfo];
    
    powerButton = [[UIButton alloc] initWithFrame:CGRectMake(620, 966, 42, 33)]; //225
    [powerButton setBackgroundImage:[[UIImage imageNamed: @"now_playing_empty_up"] resizableImageWithCapInsets:UIEdgeInsetsMake(0, 6, 0, 6)] forState:UIControlStateNormal];
    [powerButton setImage:[UIImage imageNamed: @"icon_power_up"] forState:UIControlStateNormal];
    [powerButton setImage:[UIImage imageNamed: @"icon_power_up"] forState:UIControlStateHighlighted];
    powerButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;
    [powerButton addTarget:self action:@selector(powerControl) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:powerButton];
    
    [self.view insertSubview:self.nowPlayingController.ProgressSlider aboveSubview:rootView];
    frame = self.nowPlayingController.ProgressSlider.frame;
    frame.origin.x = self.nowPlayingController.ProgressSlider.frame.origin.x + 300;
    self.nowPlayingController.ProgressSlider.frame=frame;
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults synchronize];
    BOOL clearCache=[[userDefaults objectForKey:@"clearcache_preference"] boolValue];
    if (clearCache==YES){
        ClearCacheView *clearView = [[ClearCacheView alloc] initWithFrame:self.view.frame];
        [clearView startActivityIndicator];
        [self.view addSubview:clearView];
        [NSThread detachNewThreadSelector:@selector(startClearAppDiskCache:) toTarget:self withObject:clearView];
    }
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(handleXBMCServerHasChanged:)
                                                 name: @"XBMCServerHasChanged"
                                               object: nil];
    
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(handleStackScrollOnScreen:)
                                                 name: @"StackScrollOnScreen"
                                               object: nil];
    
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(handleStackScrollOffScreen:)
                                                 name: @"StackScrollOffScreen"
                                               object: nil];
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(handleWillResignActive:)
                                                 name: @"UIApplicationWillResignActiveNotification"
                                               object: nil];
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(handleDidEnterBackground:)
                                                 name: @"UIApplicationDidEnterBackgroundNotification"
                                               object: nil];
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(handleEnterForeground:)
                                                 name: @"UIApplicationWillEnterForegroundNotification"
                                               object: nil];
    
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(handleTcpJSONRPCShowSetup:)
                                                 name: @"TcpJSONRPCShowSetup"
                                               object: nil];
    
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(handleTcpJSONRPCChangeServerStatus:)
                                                 name: @"TcpJSONRPCChangeServerStatus"
                                               object: nil];
    
    self.hostPickerViewController = [[HostManagementViewController alloc] initWithNibName:@"HostManagementViewController" bundle:nil];
    [AppDelegate instance].navigationController = [[UINavigationController alloc] initWithRootViewController:_hostPickerViewController];
    self.serverPickerPopover = [[UIPopoverController alloc]
                                initWithContentViewController:[AppDelegate instance].navigationController];
    self.serverPickerPopover.delegate = self;
    [self.serverPickerPopover setPopoverContentSize:CGSizeMake(320, 436)];

}

-(void)handleTcpJSONRPCShowSetup:(NSNotification *)sender{
    BOOL showValue = [[[sender userInfo] valueForKey:@"showSetup"] boolValue];
    if ((showValue && firstRun) || !showValue){
        [self showSetup:showValue];
    }
}

-(void)handleTcpJSONRPCChangeServerStatus:(NSNotification*) sender{
    BOOL statusValue = [[[sender userInfo] valueForKey:@"status"] boolValue];
    NSString *message = [[sender userInfo] valueForKey:@"message"];
    [self changeServerStatus:statusValue infoText:message];
}

- (void)handleStackScrollOnScreen: (NSNotification*) sender{
    [self.view insertSubview:self.nowPlayingController.ProgressSlider belowSubview:rootView];    
}

- (void)handleStackScrollOffScreen: (NSNotification*) sender{
    [self.view insertSubview:self.nowPlayingController.ProgressSlider aboveSubview:rootView];
}

- (void) handleXBMCServerHasChanged: (NSNotification*) sender{
    int thumbWidth = 477;
    int tvshowHeight = 91;
    if ([AppDelegate instance].obj.preferTVPosters==YES){
        thumbWidth = 53;
        tvshowHeight = 76;
    }
    mainMenu *menuItem=[self.mainMenu objectAtIndex:3];
    menuItem.thumbWidth=thumbWidth;
    menuItem.rowHeight=tvshowHeight;
    [[AppDelegate instance].windowController.stackScrollViewController offView];
    NSIndexPath *selection=[menuViewController.tableView indexPathForSelectedRow];
    if (selection){
        [menuViewController.tableView deselectRowAtIndexPath:selection animated:YES];
        [menuViewController setLastSelected:-1];
    }
    [self changeServerStatus:NO infoText:NSLocalizedString(@"No connection", nil)];
    [[NSNotificationCenter defaultCenter] postNotificationName: @"XBMCPlaylistHasChanged" object: nil];
}

- (void) handleWillResignActive: (NSNotification*) sender{
    [self.tcpJSONRPCconnection stopNetworkCommunication];
}

- (void) handleDidEnterBackground: (NSNotification*) sender{
    [self.tcpJSONRPCconnection stopNetworkCommunication];
}

- (void) handleEnterForeground: (NSNotification*) sender{
    if ([AppDelegate instance].serverOnLine == YES){
        if (self.tcpJSONRPCconnection == nil){
            self.tcpJSONRPCconnection = [[tcpJSONRPC alloc] init];
        }
        [self.tcpJSONRPCconnection startNetworkCommunicationWithServer:[AppDelegate instance].obj.serverIP serverPort:[AppDelegate instance].obj.tcpPort];
    }
}

- (void)viewDidUnload{
    [super viewDidUnload];
    self.tcpJSONRPCconnection = nil;
    [[NSNotificationCenter defaultCenter] removeObserver: self];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

-(void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
	[menuViewController didRotateFromInterfaceOrientation:fromInterfaceOrientation];
	[stackScrollViewController didRotateFromInterfaceOrientation:fromInterfaceOrientation];
    if ([self.serverPickerPopover isPopoverVisible]) {
        [self.serverPickerPopover dismissPopoverAnimated:NO];
        [self toggleSetup];
    }
    if ([self.appInfoPopover isPopoverVisible]) {
        [self.appInfoPopover dismissPopoverAnimated:NO];
        [self toggleInfoView];
    }
    if (showActionPower){
        [actionSheetPower showFromRect:CGRectMake(powerButton.frame.origin.x + powerButton.frame.size.width/2, powerButton.frame.origin.y, 1, 1) inView:self.view animated:YES];
        showActionPower = NO;
    }
}

- (void)viewWillLayoutSubviews{
    UIInterfaceOrientation toInterfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    if (toInterfaceOrientation == UIInterfaceOrientationPortrait || toInterfaceOrientation == UIInterfaceOrientationPortraitUpsideDown) {
        CGRect frame = self.nowPlayingController.ProgressSlider.frame;
        frame.origin.y = 444;
        self.nowPlayingController.ProgressSlider.frame=frame;
        [nowPlayingController setToolbarWidth:768 height:610 YPOS:YPOS playBarWidth:426 portrait:TRUE];
	}
	else if (toInterfaceOrientation == UIInterfaceOrientationLandscapeLeft || toInterfaceOrientation == UIInterfaceOrientationLandscapeRight){
        CGRect frame = self.nowPlayingController.ProgressSlider.frame;
        frame.origin.y = 600;
        self.nowPlayingController.ProgressSlider.frame=frame;
        [nowPlayingController setToolbarWidth:1024 height:768 YPOS:YPOS playBarWidth:680 portrait:FALSE];
	}
}

-(void) willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration{
	[menuViewController willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
	[stackScrollViewController willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    showActionPower = NO;
    if (actionSheetPower.window != nil){
        showActionPower = YES;
        [actionSheetPower dismissWithClickedButtonIndex:actionSheetPower.cancelButtonIndex animated:YES];
    }
}	

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation{
	return YES;
}

@end
