/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <UIKit/UIKit.h>

typedef void (^SKTapReceiver)(CGPoint touchPoint);

@protocol SKTapListener

@property(nonatomic, readonly) BOOL isMounted;

- (void)mountWithFrame:(CGRect)frame;

- (void)unmount;

- (void)listenForTapWithBlock:(SKTapReceiver)receiver;

@end
