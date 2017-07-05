//
//  Device.h
//  AirWatchBuddy
//
//  Created by Baker, Jeremiah (NIH/NIMH) [C] on 7/1/17.
//  Copyright © 2017 Baker, Jeremiah (NIH/NIMH) [C]. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Device : NSObject
@property NSString *deviceModel;
@property NSString *customerEmailAddress;
@property NSString *deviceSerialNumber;
@property NSString *deviceMACAddress;
@property NSString *devicePlatform;
@property NSString *deviceOS;
@property NSString *deviceSupervisedBool;
@property NSString *deviceIMEI;
@property NSString *devicePhoneNumber;
@property NSString *deviceVirtualMemory;
@property NSString *deviceACLineStatus;
@property NSString *deviceLastSeen;
@property NSString *deviceAssetNumber;
@property NSString *deviceCompromisedStatus;
@property NSString *deviceComplianceStatus;
@property NSString *deviceLocationGroupName;
@property NSString *deviceEnrollmentStatus;
@property NSString *deviceUDID;
@end
