#import "HypoTests.h"
#import "Hypo.h"

#if __has_feature(objc_arc)
    #define autorelease self
#endif

@interface ClassWithoutDependancies : NSObject
@property(strong)  NSObject  *anObject;
@end

@interface ClassWithADependancy : NSObject
@property(strong)  ClassWithoutDependancies  *leaf_hypo;
@end

@interface ClassWithADependancyOnAClassWithADependancy : NSObject
@property(strong)  ClassWithADependancy  *branch_hypo;
@end

@interface ClassWithHypoClass : NSObject
@property(strong)  HypoClass  *NSString;
@end

@implementation HypoTests

- (void)testNonparticipatingClass {
    NSMutableData *a = [NSMutableData hypo_new];
    STAssertNotNil(a, nil);
    STAssertTrue([a isKindOfClass:[NSMutableData class]], nil);
}

- (void)testCustomClassSansDependancies {
    ClassWithoutDependancies *a = [ClassWithoutDependancies hypo_new];
    STAssertNil(a.anObject, nil);
}

- (void)testClassWithAutoDependancy {
    ClassWithADependancy *a = [ClassWithADependancy hypo_new];
    STAssertNotNil(a.leaf_hypo, nil);
    STAssertNil(a.leaf_hypo.anObject, nil);
}

- (void)testClassWithExplicitDependancy {
    ClassWithoutDependancies *a = [ClassWithoutDependancies hypo_new];
    ClassWithADependancy *b = [ClassWithADependancy hypo_new:^(ClassWithADependancy *instance) {
        instance.leaf_hypo = a;
    }];
    STAssertNotNil(b.leaf_hypo, nil);
    STAssertEqualObjects(a, b.leaf_hypo, nil);
    STAssertNil(b.leaf_hypo.anObject, nil);
}

- (void)testClassesWithAutoDependancy {
    ClassWithADependancyOnAClassWithADependancy *a = [ClassWithADependancyOnAClassWithADependancy hypo_new];
    STAssertNotNil(a.branch_hypo, nil);
    STAssertNotNil(a.branch_hypo.leaf_hypo, nil);
    STAssertNil(a.branch_hypo.leaf_hypo.anObject, nil);
}

- (void)testClassesWithExplicitDependancy {
    ClassWithoutDependancies *a = [ClassWithoutDependancies hypo_new];
    ClassWithADependancyOnAClassWithADependancy *b = [ClassWithADependancyOnAClassWithADependancy hypo_new:^(ClassWithADependancyOnAClassWithADependancy *instance) {
        instance.branch_hypo = [ClassWithADependancy hypo_new:^(ClassWithADependancy *instance) {
            instance.leaf_hypo = a;
        }];
    }];
    STAssertNotNil(b.branch_hypo, nil);
    STAssertNotNil(b.branch_hypo.leaf_hypo, nil);
    STAssertEqualObjects(a, b.branch_hypo.leaf_hypo, nil);
    STAssertNil(b.branch_hypo.leaf_hypo.anObject, nil);
}

- (void)testHypoClass {
    ClassWithHypoClass *a = [ClassWithHypoClass hypo_new];
    NSString *s = [a.NSString hypo_new];
    STAssertNotNil(s, nil);
    STAssertTrue([s isKindOfClass:[NSString class]], nil);
}

@end

//-----------------------------------------------------------------------------------------

@implementation ClassWithoutDependancies
@end

@implementation ClassWithADependancy
@end

@implementation ClassWithADependancyOnAClassWithADependancy
@end

@implementation ClassWithHypoClass
@end