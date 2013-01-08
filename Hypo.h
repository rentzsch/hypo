// Hypo.h semver:2.0b1
//   Copyright (c) 2010-2013 Jonathan 'Wolf' Rentzsch: http://rentzsch.com
//   Some rights reserved: http://opensource.org/licenses/mit
//   http://github.com/rentzsch/hypo

#import <Foundation/Foundation.h>

@interface NSObject (hypo_new)
+ (instancetype)hypo_new;
+ (instancetype)hypo_new:(NSDictionary*)opts;
@end

@interface HypoClass : NSObject
@property(strong)  Class  cls;

- (id)hypo_new;
- (id)hypo_new:(NSDictionary*)opts;
@end

@protocol HypoSingleton
@end

extern NSString const * HypoCallback;

typedef id (^HypoCallbackBlock)(
    id instance,
    NSString *propertyName,
    NSString *propertyClassName,
    NSDictionary *opts);