//
//  ViewController.h
//  LuaDemoProject
//
//  Created by stuliu's iMac on 14-10-20.
//  Copyright (c) 2014年 stuliu's iMac. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol ViewControllerDelegate

@optional
- (void)xixi:(NSObject*)obj;
- (void)xixi1:(CGSize)range;

- (NSInteger)callback:(id)param1 param2:(int)param2;

@end

@interface ViewController : UIViewController

@property   (nonatomic, retain)     id<ViewControllerDelegate> delegate;


@end

