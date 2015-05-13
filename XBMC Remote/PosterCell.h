//
//  PosterCell.h
//  XBMC Remote
//
//  Created by Giovanni Messina on 17/3/13.
//  Copyright (c) 2013 joethefox inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PosterLabel.h"

@interface PosterCell : UICollectionViewCell {
    UIImageView *overlayWatched;
}

-(void)setOverlayWatched:(BOOL)enable;

@property (nonatomic, readonly) UIImageView *posterThumbnail;
@property (nonatomic, readonly) PosterLabel *posterLabel;
@property (nonatomic, readonly) UIActivityIndicatorView *busyView;

@end