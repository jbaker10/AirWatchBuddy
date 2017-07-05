//
//  SerialValueTransformer.m
//  AirWatchBuddy
//
//  Created by Baker, Jeremiah (NIH/NIMH) [C] on 7/1/17.
//  Copyright © 2017 Baker, Jeremiah (NIH/NIMH) [C]. All rights reserved.
//

#import "SerialValueTransformer.h"

@implementation SerialValueTransformer
+ (Class)transformedValueClass {
    return [NSString class];
}

+ (BOOL)allowsReverseTransformation {
    return NO;
}

- (id)transformedValue:(id)value {
    NSDictionary *device = value;
    NSString *serialNumber = device[@"SerialNumber"];
    return serialNumber;
}
@end
