//
//  RMPageViewController.h
//  Chives
//
//  Created by Rich Schonthal on 8/16/16.
//  Copyright © 2016 Resignation Media. All rights reserved.
//

#import <UIKit/UIKit.h>

@class RMPageViewController;

@protocol RMPageViewControllerClient
@optional
- (void)pageViewControllerActivated:(RMPageViewController *)pageViewController previouslyActiveViewController:(UIViewController *)previouslyActiveViewController;
- (void)pageViewControllerDeactived:(RMPageViewController *)pageViewController activeViewController:(UIViewController *)activeViewController;
@end


@protocol RMPageViewControllerDataSource
@optional
- (UIViewController *)pageViewController:(RMPageViewController *)pageViewController viewControllerForIndex:(NSInteger)viewControllerForIndex;
- (NSInteger)pageViewControllerPageCount:(RMPageViewController *)pageViewController;
@end


@protocol RMPageViewControllerDelegate
@optional
- (void)pageViewController:(RMPageViewController *)pageViewController presentedViewController:(UIViewController *)presentedViewController index:(NSInteger)index;
- (void)pageViewController:(RMPageViewController *)pageViewController createdViewController:(UIViewController *)createdViewController;
@end

@interface RMPageViewController : UIViewController

@property (nonatomic, readonly) NSInteger currentPage;

@end
