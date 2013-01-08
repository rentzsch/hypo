// Hypo.m semver:1.0
//   Copyright (c) 2010-2013 Jonathan 'Wolf' Rentzsch: http://rentzsch.com
//   Some rights reserved: http://opensource.org/licenses/mit
//   http://github.com/rentzsch/hypo

#import "Hypo.h"
#import <objc/runtime.h>
#import "JRLog.h"

@interface HypoClass ()
- (id)initWithClass:(Class)class_ bin:(HypoContainer*)bin_;
@end

@interface HypoContainer ()
- (id)consumeInstanceOfClass:(Class)class_ optional:(BOOL)optional_ instance:(id)instance_ key:(NSString*)key_;
- (void)resolveDependancies:(id)instance_;
@end

//-----------------------------------------------------------------------------------------

@implementation HypoContainer

- (id)init {
    self = [super init];
    if (self) {
        instancesByClass = [[NSMutableDictionary alloc] init];
        singletonByClass = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)dealloc {
    [instancesByClass release];
    [singletonByClass release];
    [super dealloc];
}

- (id)addInstance:(id)instance_ {
    NSParameterAssert(instance_);
    
    if ([instance_ isKindOfClass:[NSString class]]) {
        // Allow passing NSStrings as shorthand for "create an instance of this class".
        instance_ = [self create:NSClassFromString(instance_)];
    }
    
    JRLogDebug(@"adding instance %@<%p>", [instance_ className], instance_);
    Class instanceClass = [instance_ class];
    NSMutableArray *instances = [instancesByClass objectForKey:instanceClass];
    if (instances) {
        [instances addObject:instance_];
    } else {
        instances = [NSMutableArray arrayWithObject:instance_];
        [instancesByClass setObject:instances forKey:instanceClass];
    }
    return instance_;
}

- (void)addInstances:(NSArray*)instances_ {
    for (id instance in instances_) {
        [self addInstance:instance];
    }
}

- (void)addSingleton:(id)singleton_ {
    NSParameterAssert(singleton_);
    JRLogDebug(@"adding singleton %@<%p>", [singleton_ className], singleton_);
    [singletonByClass setObject:singleton_ forKey:[singleton_ class]];
}

- (id)create:(Class)class_ {
    NSParameterAssert(class_);
    JRLogDebug(@"creating instance of %@", [class_ className]);
    id allocedInstance = [class_ alloc];
    [self resolveDependancies:allocedInstance];
    id initedInstance = [[allocedInstance init] autorelease];
    if (initedInstance && initedInstance != allocedInstance) {
        [self resolveDependancies:initedInstance];
    }
    if ([initedInstance respondsToSelector:@selector(didCreateInstanceInHypoContainer:)]) {
        [initedInstance didCreateInstanceInHypoContainer:self];
    }
    return initedInstance;
}

- (id)create:(Class)class_ withDependancies:(id)firstInstance_, ... {
    NSParameterAssert(class_);
    
    if (firstInstance_) {
        [self addInstance:firstInstance_];
        
        va_list args;
        va_start(args, firstInstance_);
        id instance;
        while ((instance = va_arg(args, id))) {
            [self addInstance:instance];
        }
        va_end(args);
    }
    
    return [self create:class_];
}

- (id)singletonOfClass:(Class)class_ {
    return [singletonByClass objectForKey:class_];
}

- (id)createAndAddInstanceOfClass:(Class)class_ {
    NSParameterAssert(class_);
    id result = [self create:class_];
    [self addInstance:result];
    return result;
}

- (id)createAndAddInstanceOfClass:(Class)class_ withDependancies:(id)firstInstance_, ... {
    NSParameterAssert(class_);
    NSParameterAssert(firstInstance_);
    
    [self addInstance:firstInstance_];
    
    va_list args;
    va_start(args, firstInstance_);
    id instance;
    while ((instance = va_arg(args, id))) {
        [self addInstance:instance];
    }
    va_end(args);
    return [self createAndAddInstanceOfClass:class_];
}

- (void)createAndAddInstancesOfClasses:(NSArray*)classes_ {
    NSParameterAssert(classes_);
    //NSMutableArray *instances = [NSMutableArray arrayWithCapacity:[classes_ count]];
    for (id cls in classes_) {
        unsigned instanceCount = 1;
        if ([cls isKindOfClass:[NSString class]]) {
            NSRange countModifierRange = [cls rangeOfString:@" x"]; // support for @"MyClass x4"
            if (countModifierRange.location != NSNotFound) {
                instanceCount = [[cls substringFromIndex:countModifierRange.location+countModifierRange.length] integerValue];
                cls = [cls substringToIndex:countModifierRange.location]; // lop off the " x\d"
            }
            Class tmp = NSClassFromString(cls);
            NSAssert1(tmp, @"Hypo: couldn't load class %@", cls);
            cls = tmp;
        }
        id instance = [self create:cls];
        while (instanceCount--) {
            [self addInstance:instance];
        }
    }
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

- (void)resolveDependancies:(id)instance_ {
    NSParameterAssert(instance_);
    
    Class currentClass = [instance_ class];
    do {
        unsigned propertyCount;
        objc_property_t *properties = class_copyPropertyList(currentClass, &propertyCount);
        for (unsigned propertyIndex = 0; propertyIndex < propertyCount; propertyIndex++) {
            objc_property_t property = properties[propertyIndex];
            NSString *propertyName = [NSString stringWithUTF8String:property_getName(property)];
            NSString *propertyClassName = classNameFromPropertyAttributes(property_getAttributes(property));
            if (!propertyClassName) continue;
            
            if ([propertyClassName isEqualToString:@"HypoContainer"]) {
                // Container injection request.
                [instance_ setValue:self forKey:propertyName];
            } else if ([propertyName hasSuffix:@"_hypo"]) {
                // Instance injection request.
                if (![instance_ valueForKey:propertyName]) {
                    Class propertyClass = NSClassFromString(propertyClassName);
                    NSAssert1(propertyClass, @"Hypo: couldn't find class named \"%@\"", propertyClassName);
                    
                    BOOL optional = [propertyName hasSuffix:@"_opt_hypo"];
                    id propertyValue = [self consumeInstanceOfClass:propertyClass
                                                           optional:optional
                                                           instance:instance_
                                                                key:propertyName];
                    if (propertyValue) {
                        [instance_ setValue:propertyValue forKey:propertyName];
                    }
                }
            } else if ([propertyClassName isEqualToString:@"HypoClass"]) {
                //  Class injection request.
                Class propertyClass;
                if ([propertyName hasSuffix:@"_hypo"]) {
                    propertyClass = NSClassFromString([propertyName substringToIndex:[propertyName length]-5]);
                } else {
                    propertyClass = NSClassFromString(propertyName);
                }
                NSAssert1(propertyClass, @"Hypo: couldn't find class named \"%@\"", propertyName);
                
                HypoClass *ivar = [[[HypoClass alloc] initWithClass:propertyClass bin:self] autorelease];
                [instance_ setValue:ivar forKey:propertyName];
            }
        }
        free(properties);
        currentClass = class_getSuperclass(currentClass);
    } while (currentClass && currentClass != [NSObject class]);
}

- (id)consumeInstanceOfClass:(Class)class_ optional:(BOOL)optional_ instance:(id)instance_ key:(NSString*)key_ {
    id result = nil;
    NSMutableArray *instances = [instancesByClass objectForKey:class_];
    if (instances && [instances count]) {
        result = [instances objectAtIndex:0];
        [instances removeObjectAtIndex:0];
        JRLogDebug(@"%@<%p>.%@ := instance %@<%p>",
                   [instance_ className],
                   instance_,
                   key_,
                   [result className],
                   result);
    } else {
        result = [singletonByClass objectForKey:class_];
        if (result) {
            JRLogDebug(@"%@<%p>.%@ := singleton %@<%p>",
                       [instance_ className],
                       instance_,
                       key_,
                       [result className],
                       result);
        } else if(!optional_) {
            NSString *reasonDetail;
            if (!instances) {
                reasonDetail = @"no instances registered for class";
            } else {
                reasonDetail = @"instances exhausted for class";
            }
            NSString *reason = [NSString stringWithFormat:@"Can't populate %@<%p>.%@: %@ %@",
                                [instance_ className],
                                instance_,
                                key_,
                                reasonDetail,
                                [class_ className]];
            [[NSException exceptionWithName:@"HypoDependencyInjectionException"
                                     reason:reason
                                   userInfo:nil] raise];
        }
    }
    if (result) {
        [self resolveDependancies:result];
    }
    return result;
}

@end

//-----------------------------------------------------------------------------------------

@implementation HypoClass
- (id)initWithClass:(Class)class_ bin:(HypoContainer*)bin_ {
    NSParameterAssert(class_);
    self = [super init];
    if (self) {
        cls = [class_ retain];
        container = [bin_ retain];
    }
    return self;
}

- (void)dealloc {
    [cls release];
    [container release];
    [super dealloc];
}

- (id)create {
    id allocedInstance = [cls alloc];
    [container resolveDependancies:allocedInstance];
    id initedInstance = [[allocedInstance init] autorelease];
    if (initedInstance != allocedInstance) {
        [container resolveDependancies:initedInstance];
    }
    if ([initedInstance respondsToSelector:@selector(didCreateInstanceInHypoContainer:)]) {
        [initedInstance didCreateInstanceInHypoContainer:container];
    }
    return initedInstance;
}

- (id)createWithDependancies:(id)firstInstance_,... {
    NSParameterAssert(firstInstance_);
    
    [container addInstance:firstInstance_];
    
    va_list args;
    va_start(args, firstInstance_);
    id instance;
    while ((instance = va_arg(args, id))) {
        [container addInstance:instance];
    }
    va_end(args);
    
    return [self create];
}
@end

//-----------------------------------------------------------------------------------------

@implementation NSObject (jr_new)
+ (id)jr_new {
    return [[[self alloc] init] autorelease];
}
@end