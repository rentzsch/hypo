// Hypo.h semver:1.0
//   Copyright (c) 2010-2013 Jonathan 'Wolf' Rentzsch: http://rentzsch.com
//   Some rights reserved: http://opensource.org/licenses/mit
//   http://github.com/rentzsch/hypo

#import <Foundation/Foundation.h>

@interface HypoContainer : NSObject {
  @protected
    NSMutableDictionary *instancesByClass;
    NSMutableDictionary *singletonByClass;
}

- (id)addInstance:(id)instance_;
- (void)addInstances:(NSArray*)instances_;
- (void)addSingleton:(id)instance_;

- (id)create:(Class)class_;
- (id)create:(Class)class_ withDependancies:(id)firstInstance_, ... NS_REQUIRES_NIL_TERMINATION;

- (id)singletonOfClass:(Class)class_;

- (id)createAndAddInstanceOfClass:(Class)class_;
- (id)createAndAddInstanceOfClass:(Class)class_ withDependancies:(id)firstInstance_, ... NS_REQUIRES_NIL_TERMINATION;
- (void)createAndAddInstancesOfClasses:(NSArray*)classes_;
@end

//-----------------------------------------------------------------------------------------

@interface HypoClass : NSObject {
    Class   cls;
    HypoContainer *container;
}
- (id)create;
- (id)createWithDependancies:(id)firstInstance_, ... NS_REQUIRES_NIL_TERMINATION;
@end

//-----------------------------------------------------------------------------------------

@interface NSObject (didCreateInstanceInHypoContainer)
- (void)didCreateInstanceInHypoContainer:(HypoContainer*)container_;
@end

//-----------------------------------------------------------------------------------------

@interface NSObject (jr_new)
+ (id)jr_new; // same as [[[Class alloc] init] autorelease].
@end

//-----------------------------------------------------------------------------------------

@protocol HypoSingleton
@end
