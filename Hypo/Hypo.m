// Hypo.m semver:2.0b1
//   Copyright (c) 2010-2013 Jonathan 'Wolf' Rentzsch: http://rentzsch.com
//   Some rights reserved: http://opensource.org/licenses/mit
//   http://github.com/rentzsch/hypo

#import "Hypo.h"
#import <objc/runtime.h>

#if __has_feature(objc_arc)
    #define autorelease self
#endif

@implementation NSObject (hypo_new)

+ (instancetype)hypo_new {
    return [self hypo_new:@{}];
}

static NSString *classNameFromPropertyAttributes(const char *attributesCStr) {
    //  T@"NSString",C,Vstr1 => NSString
    NSString *attributes = [NSString stringWithUTF8String:attributesCStr];
    
    NSRange openingQuote = [attributes rangeOfString:@"\""];
    NSRange closingQuote = [attributes rangeOfString:@"\","];
    if (NSNotFound == openingQuote.location || NSNotFound == closingQuote.location) {
        return nil;
    }
    
    NSRange classNameRange = NSMakeRange(openingQuote.location + 1,
                                         closingQuote.location - openingQuote.location - 1);
    NSString *result = [attributes substringWithRange:classNameRange];
    NSCAssert(result && [result length] >= 3, nil);
    return result;
}

+ (instancetype)hypo_new:(NSDictionary*)opts {
    id instance = [[self alloc] init];
    
    Class currentClass = [instance class];
    do {
        unsigned propertyCount;
        objc_property_t *properties = class_copyPropertyList(currentClass, &propertyCount);
        for (unsigned propertyIndex = 0; propertyIndex < propertyCount; propertyIndex++) {
            objc_property_t property = properties[propertyIndex];
            NSString *propertyName = [NSString stringWithUTF8String:property_getName(property)];
            NSString *propertyClassName = classNameFromPropertyAttributes(property_getAttributes(property));
            if (!propertyClassName) continue;
            
            if ([propertyName hasSuffix:@"_hypo"]) {
                // Instance injection request.
                if (![instance valueForKey:propertyName]) {
                    Class propertyClass = NSClassFromString(propertyClassName);
                    NSAssert1(propertyClass, @"Hypo: couldn't find class named \"%@\"", propertyClassName);
                    
                    // First try assigning an existing instance.
                    id propertyValue = opts[propertyName];
                    
                    // If that failed second try the callback mechanism.
                    if (!propertyValue) {
                        HypoCallbackBlock callback = opts[HypoCallback];
                        if (callback) {
                            propertyValue = callback(instance,
                                                     propertyName,
                                                     propertyClassName,
                                                     opts);
                        }
                    }
                    
                    // Finally if all those failed just create a new instance ourself.
                    if (!propertyValue) {
                        NSString *keypathPrefix = [propertyName stringByAppendingString:@"."];
                        NSMutableDictionary *subOpts = [NSMutableDictionary dictionary];
                        for (NSString *key in opts) {
                            if ([key hasPrefix:keypathPrefix]) {
                                NSString *subkeypath = [key substringFromIndex:[keypathPrefix length]];
                                subOpts[subkeypath] = opts[key];
                            } else {
                                subOpts[key] = opts[key];
                            }
                        }
                        propertyValue = [propertyClass hypo_new:subOpts];
                    }
                    
                    [instance setValue:propertyValue forKey:propertyName];
                }
            } else if ([propertyClassName isEqualToString:@"HypoClass"]) {
                //  Class injection request.
                Class propertyClass = NSClassFromString(propertyName);
                [instance setValue:propertyClass forKey:propertyName];
            }
        }
        free(properties);
        currentClass = class_getSuperclass(currentClass);
    } while (currentClass && currentClass != [NSObject class]);
    
    return [instance autorelease];
}

@end

@implementation HypoClass
// These are never actually called:
- (id)hypo_new { return nil; }
- (id)hypo_new:(NSDictionary*)opts { return nil; }
@end

NSString const * HypoCallback = @":HypoCallback";