// Hypo.m semver:3.0b1
//   Copyright (c) 2010-2014 Jonathan 'Wolf' Rentzsch: http://rentzsch.com
//   Some rights reserved: http://opensource.org/licenses/mit
//   http://github.com/rentzsch/hypo

#import "Hypo.h"
#import <objc/runtime.h>

@implementation NSObject (hypo_new)

+ (instancetype)hypo_new {
    return [self hypo_new:NULL];
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
    NSCAssert1(result && [result length] >= 3,
               @"Hypo: couldn't extract class name from property attribute string '%s'",
               attributesCStr);
    return result;
}

+ (instancetype)hypo_new:(HypoBlock)block {
    id instance = [[self alloc] init];
    
    if (block) {
        block(self);
    }
    
    [instance hypo_setup];
    
#if !__has_feature(objc_arc)
    [instance autorelease];
#endif
    return instance;
}

- (void)hypo_setup {
    Class currentClass = [self class];
    do {
        unsigned propertyCount;
        objc_property_t *properties = class_copyPropertyList(currentClass, &propertyCount);
        for (unsigned propertyIndex = 0; propertyIndex < propertyCount; propertyIndex++) {
            objc_property_t property = properties[propertyIndex];
            NSString *propertyName = [NSString stringWithUTF8String:property_getName(property)];
            
            if ([self valueForKey:propertyName] == nil) {
                NSString *propertyClassName = classNameFromPropertyAttributes(property_getAttributes(property));
                
                Class propertyClass = NSClassFromString(propertyClassName);
                NSAssert1(propertyClass, @"Hypo: couldn't find class named \"%@\"", propertyClassName);
                
                if ([propertyName hasSuffix:@"_hypo"]) {
                    // Unfulfilled instance injection request.
                    [self setValue:[propertyClass hypo_new] forKey:propertyName];
                } else if ([propertyClassName isEqualToString:@"HypoClass"]) {
                    //  Unfulfilled class injection request.
                    [self setValue:propertyClass forKey:propertyName];
                }
            }
        }
        free(properties);
        currentClass = class_getSuperclass(currentClass);
    } while (currentClass && currentClass != [NSObject class]);
    
    [self hypo_awakeFromNew];
}

@end

@implementation HypoClass
// These are never actually called and only exist to satisfy the linker:
- (id)hypo_new { assert(0); return nil; }
- (id)hypo_new:(HypoBlock)block { assert(0); return nil; }
@end

@implementation NSObject (hypo_awakeFromNew)
- (void)hypo_awakeFromNew {} // Default do-nothing implementation. 
@end