//
//  RMPageViewController.m
//  Chives
//
//  Created by Rich Schonthal on 8/16/16.
//  Copyright © 2016 Resignation Media. All rights reserved.
//

#import "RMPageViewController.h"


@interface RMAgnosticDuple : NSObject

@property (nonatomic, readwrite) CGFloat relevant;
@property (nonatomic, readwrite) CGFloat other;

+(instancetype)dupleWithRelevant:(CGFloat)relevant other:(CGFloat)other;

@end

@implementation RMAgnosticDuple

+(instancetype)dupleWithRelevant:(CGFloat)relevant other:(CGFloat)other {

	RMAgnosticDuple *noob = [RMAgnosticDuple new];
	noob->_relevant = relevant;
	noob->_other = other;
	return noob;
}

-(id)copyWithZone:(NSZone *)zone {

	RMAgnosticDuple *duple = [[[self class] allocWithZone:zone]init];
	duple.relevant = self.relevant;
	duple.other = self.other;
	return duple;
}

@end

@interface RMAgnosticRect : NSObject

@property (nonatomic, readonly) RMAgnosticDuple *origin;
@property (nonatomic, readonly) RMAgnosticDuple *size;

+(instancetype)rectWithOrigin:(RMAgnosticDuple *)origin size:(RMAgnosticDuple *)size;
+(CGRect)offscreen;

-(CGRect)rect;

@end

@implementation RMAgnosticRect

+(instancetype)rectWithOrigin:(RMAgnosticDuple *)origin size:(RMAgnosticDuple *)size {

	RMAgnosticRect *noob = [RMAgnosticRect new];
	noob->_origin = origin;
	noob->_size = size;
	return noob;
}

+(CGRect)offscreen {
	return CGRectZero;
}

-(CGRect)rect {
	return CGRectZero;
}

-(id)copyWithZone:(NSZone *)zone {

	RMAgnosticRect *rect = [[[self class] allocWithZone:zone]init];
	rect->_origin = self.origin.copy;
	rect->_size = self.size.copy;
	return rect;
}
@end

@interface HorizontalAgnosticRect : RMAgnosticRect
@end

@implementation HorizontalAgnosticRect

+(CGRect)offscreen {
	return CGRectMake(-999999, 0, 1, 1);
}

-(CGRect)rect {
	return CGRectMake(self.origin.relevant, self.origin.other, self.size.relevant, self.size.other);
}

@end

@interface RMPageViewController ()

@property (nonatomic, readonly) NSMutableDictionary<NSNumber *, UIViewController *> *viewControllersByPage;
@property (nonatomic, readonly) NSArray *containerViews;
@property (nonatomic, readwrite) NSInteger currentPage;
@property (nonatomic, readwrite) NSInteger previousPage;
@property (nonatomic, readonly, weak) Class rectClass;
@property (nonatomic, readonly) UIScrollView *scrollView;

@end

@implementation RMPageViewController

-(instancetype)init {
	self = [super init];
	_viewControllersByPage = [NSMutableDictionary dictionaryWithCapacity:4];
	_containerViews = @[[UIView new], [UIView new]];
	_previousPage = -1;
	_rectClass = [HorizontalAgnosticRect class];
	_scrollView = [self createScrollView];
	return  self;
}

-(void)setCurrentPage:(NSInteger)currentPage {
	_previousPage = _currentPage;
	_currentPage = currentPage;
}

-(UIScrollView *)createScrollView {

	return [UIScrollView new];
}

-(UIView *)offscreenView {

	for (UIView *current in self.containerViews) {
		if (!CGRectIntersectsRect(self.scrollView.bounds, current.frame)) {
			return current;
		}
	}
	return nil;
}

-(UIView *)attachView:(UIView *)view {

	UIView *container = [self offscreenView];
	if (!container) {
		return nil;
	}
	[container addSubview:view];
	view.frame = CGRectMake(0, 0, CGRectGetWidth(container.frame), CGRectGetHeight(container.frame));
	return container;
}

-(void)attachViewController:(UIViewController *)viewController page:(NSInteger)page {

	if(self.viewControllersByPage[@(page)] == viewController && [self.containerViews containsObject:viewController.view.superview]) {
		return;
	}
	UIViewController *previouslyUsedViewController = self.viewControllersByPage[@(page)];
	if (previouslyUsedViewController) {
		UIView *container = [self attachView:previouslyUsedViewController.view];
		
	}
	if let  = , let container = attachView(previouslyUsedViewController.view) {
		container.frame = frameForPage(page)
	} else {
		viewControllersByPage[page] = viewController
		if let container = attachView(viewController.view) {
			addChildViewController(viewController)
			container.frame = frameForPage(page)
			viewController.didMoveToParentViewController(self)
		}
	}

}

private func detachViewController(viewController: UIViewController) {

	if let view = viewController.view {
		view.superview?.frame = HorizontalAgnosticRect.offscreen
		viewController.willMoveToParentViewController(nil)
		view.removeFromSuperview()
		viewController.removeFromParentViewController()
	}
}

@end
