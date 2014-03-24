Hypo helps Cocoa coders write loosely-coupled classes. That is, classes that use the services of other classes but try to minimize assumptions.

By minimizing assumptions we write software that is easier to change and test.

Instead of `#import`ing (or now `@import`-ing) classes and instantiating them directly, Hypo allows you to work at a slightly higher level of abstraction and indicate declaratively object instances your class needs to collaborate with to get its work done.

Let's make this concrete by rewriting a traditional class that finds a Mac app's Application Support folder and rewrite it to use Hypo.

Here's the traditional code:

    //
    // AppSupportFolder.h
    //

    @interface AppSupportFolder : NSObject
    - (NSURL*)calculatedURL;
    @end
    
    //
    // AppSupportFolder.m
    //

    #import "AppSupportFolder.h"

    @implementation AppSupportFolder
    - (NSURL*)calculatedURL {
        NSArray *urls = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory
                                                               inDomains:NSUserDomainMask];
        
        NSURL *baseURL = ([urls count] > 0)
            ? [urls objectAtIndex:0]
            : [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES];
        
        NSString *appName = [[[NSBundle mainBundle] infoDictionary] objectForKey:(id)kCFBundleNameKey];
        return [baseURL URLByAppendingPathComponent:appName isDirectory:YES];
    }
    @end

And you'd use `AppSupportFolder` like so:

    NSLog(@"%@", [[AppSupportFolder new] calculatedURL]);

As it stands now `AppSupportFolder` relies upon `NSFileManager` and `NSBundle` to figure out the correct path to the application's support folder. Let's declare those collaborations:

    //
    // AppSupportFolder.h
    //

    @import Foundation;

    @interface AppSupportFolder : NSObject
    @property(nonatomic, strong)  NSFileManager  *fileManager_hypo;
    @property(nonatomic, strong)  NSBundle       *mainBundle_hypo;

    - (NSURL*)calculatedURL;
    @end

Objective-C doesn't have anything like Java or C#'s annotations, so we use the `_hypo` suffix naming convention hack to "annotate" properties requiring instantiation.

Here's the updated implementation code:

    //
    // AppSupportFolder.m
    //

    #import "AppSupportFolder.h"
    #import "Hypo.h"

    @implementation AppSupportFolder

    - (void)hypo_awakeFromNew {
        if (!self.mainBundle_hypo) {
            self.mainBundle_hypo = [NSBundle mainBundle];
        }
    }

    - (NSURL*)calculatedURL {
        NSArray *urls = [self.fileManager_hypo URLsForDirectory:NSApplicationSupportDirectory
                                                               inDomains:NSUserDomainMask];
        
        NSURL *baseURL = ([urls count] > 0)
            ? [urls objectAtIndex:0]
            : [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES];
        
        NSString *appName = [[self.mainBundle_hypo infoDictionary] objectForKey:(id)kCFBundleNameKey];
        return [baseURL URLByAppendingPathComponent:appName isDirectory:YES];
    }
    @end

As you can see instead of instantiating `NSFileManager` directly, we rely upon Hypo's default behavior of creating a new instance.

`NSBundle` is a special case, however, since it's singleton. We could ask every client provide us with that singleton, but since that's common case we leverage `-hypo_awakeFromNew` to supply that default if it's not otherwise supplied.

You instantiate Hypo-participating classes a little differently:

    NSLog(@"%@", [[AppSupportFolder hypo_new] calculatedURL]);

`+hypo_new` is the bottleneck that allows Hypo to examine the new instance at runtime and figure out what properties need to be filled out.

Now our little class is testable:

    //
    // AppSupportFolderTest.m
    //

    #import <XCTest/XCTest.h>
    #import "AppSupportFolder.h"
    #import "Hypo.h"
    #import "OCMock.h"

    @interface AppSupportFolderTest : XCTestCase
    @end

    @implementation AppSupportFolderTest

    - (void)testCalculatedURL {
        NSURL *userAppSupportFolder = [NSURL fileURLWithPath:@"/Users/wolf/Library/Application Support" isDirectory:YES];
        
        AppSupportFolder *asf = [AppSupportFolder hypo_new:^(AppSupportFolder *instance) {
            {{
                OCMockObject *fileManagerMock = [OCMockObject mockForClass:[NSFileManager class]];
                [[[fileManagerMock stub] andReturn:@[userAppSupportFolder]] URLsForDirectory:NSApplicationSupportDirectory
                                                                                   inDomains:NSUserDomainMask];
                
                instance.fileManager_hypo = (NSFileManager*)fileManagerMock;
            }}
            {{
                OCMockObject *mainBundleMock = [OCMockObject mockForClass:[NSBundle class]];
                [[[mainBundleMock stub] andReturn:@{(id)kCFBundleNameKey: @"MyAppName"}] infoDictionary];
                instance.mainBundle_hypo = (NSBundle*)mainBundleMock;
            }}
        }];
        
        NSURL *expectedURL = [userAppSupportFolder URLByAppendingPathComponent:@"MyAppName"
                                                                   isDirectory:YES];
        NSURL *actualURL = [asf calculatedURL];
        XCTAssertEqualObjects(expectedURL, actualURL, @"");
    }

    @end

Our test class takes advantage of the other version of `+hypo_new`, `+hypo_new:` which takes a block. The block is passed the instance that's being filled out. Any property that isn't filled out when the block returns will be filled out with Hypo's default behavior of creating a new instance.

## TODO

- Document HypoClass.