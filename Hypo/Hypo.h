// Hypo.h semver:3.0b1
//   Copyright (c) 2010-2014 Jonathan 'Wolf' Rentzsch: http://rentzsch.com
//   Some rights reserved: http://opensource.org/licenses/mit
//   http://github.com/rentzsch/hypo

#import <Foundation/Foundation.h>

typedef void (^HypoBlock)(id instance);

@interface NSObject (hypo_new)
+ (instancetype)hypo_new;
+ (instancetype)hypo_new:(HypoBlock)block;

// For when you can't call +hypo_new directly (f.x., instantiation from nibs):
- (void)hypo_setup;
@end

@interface HypoClass : NSObject
- (id)hypo_new;
- (id)hypo_new:(HypoBlock)block;
@end

@interface NSObject (hypo_awakeFromNew)
// Overriders should call [super hypo_awakeFromNew].
- (void)hypo_awakeFromNew;
@end