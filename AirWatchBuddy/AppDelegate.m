//
//  AppDelegate.m
//  AirWatchBuddy
//
//  Created by Baker, Jeremiah (NIH/NIMH) [C] on 7/1/17.
//  Copyright © 2017 Baker, Jeremiah (NIH/NIMH) [C]. All rights reserved.
//

#import "AppDelegate.h"
#import "Device.h"
#import <Security/Security.h>

static NSString *const kServerURIUser = @"/api/mdm/devices/search";
static NSString *const kServerURIDevices = @"/api/mdm/devices";

@interface AppDelegate ()
@property (weak) IBOutlet NSTableView *deviceTableView;
@property (weak) IBOutlet NSWindow *window;
@property NSArray *devicesArray;
@property NSArray *deviceTableArray;
@property (weak) IBOutlet NSTextField *searchValue;
@property (weak) IBOutlet NSPopUpButtonCell *searchParamater;
@property (weak) IBOutlet NSPopUpButton *maxDeviceSearch;
@property (weak) IBOutlet NSWindow *credsWindow;
- (IBAction)creds:(id)sender;
@property (weak) IBOutlet NSTextFieldCell *serverURL;
@property (weak) IBOutlet NSTextFieldCell *awTenantCode;
@property (weak) IBOutlet NSTextFieldCell *userName;
@property (weak) IBOutlet NSSecureTextFieldCell *password;
- (IBAction)closeCredsSheet:(id)sender;
- (IBAction)refreshDeviceDetails:(id)sender;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    NSString *storedUsername = [[NSUserDefaults standardUserDefaults] valueForKey:@"Username"];
    NSString *storedServerURL = [[NSUserDefaults standardUserDefaults] valueForKey:@"ServerURL"];
    NSArray *creds = [self getCredsFromKeychainWithUserName:storedUsername serverURL:storedServerURL];
    if (storedServerURL) {
        self.serverURL.stringValue = storedServerURL;
    }
    if (storedUsername) {
        self.userName.stringValue = storedUsername;
    }
    if (creds.count == 2) {
        self.password.stringValue = creds.firstObject;
        self.awTenantCode.stringValue = creds.lastObject;
    } else {
        [self creds:self];
    }
}

- (void)setCredsToKeychainWithUserName:(NSString *)userName serverURL:(NSString *)serverURL password:(NSString *)password awTenantCode:(NSString *)awTenantCode {
    NSString *creds = [[password stringByAppendingString:@"\n"] stringByAppendingString:awTenantCode];
    
    OSStatus ret = SecKeychainAddGenericPassword(NULL, (UInt32)serverURL.length, serverURL.UTF8String, (UInt32)userName.length, userName.UTF8String, (UInt32)creds.length, (void *)creds.UTF8String, NULL);
    NSLog(@"The return code from trying to add the keychain entry: %d", ret);
    if (ret == errSecDuplicateItem) {
    } else if (ret != errSecSuccess) {
        // Should show an NSAlert here about how it couldn't set a keychain
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:@"Could not save info to Keychain!"];
        [alert setInformativeText:@"Please ensure your default keychain is unlocked and available and try again."];
        [alert setAlertStyle:NSAlertStyleWarning];
        [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
            return;
        }];
    }
    
    [[NSUserDefaults standardUserDefaults] setValue:userName forKey:@"Username"];
    [[NSUserDefaults standardUserDefaults] setValue:serverURL forKey:@"ServerURL"];
}

// This method will try to retrieve the username and password from the Keychain entry corresponding to the AirWatch hsotname
-(NSArray *)getCredsFromKeychainWithUserName:(NSString *)userName serverURL:(NSString *)serverURL {
    void *passwordAndAPIKey = NULL;
    UInt32 passwordandAPIKeyLength = 0;
    
    OSStatus ret = SecKeychainFindGenericPassword(NULL, (UInt32)serverURL.length, serverURL.UTF8String, (UInt32)userName.length, userName.UTF8String, &passwordandAPIKeyLength, &passwordAndAPIKey, NULL);

    if (ret != errSecSuccess) {
        return nil;
    }
    NSString *creds = [[NSString alloc] initWithBytes:passwordAndAPIKey length:passwordandAPIKeyLength encoding:NSUTF8StringEncoding];
    return [creds componentsSeparatedByString:@"\n"];
}

// This method below will be run if the 'UserName' field is selected as the search paramater
- (NSDictionary *)userDeviceDetails {
    // Create the URL request with the hostname and search URI's
    NSURLComponents *airWatchURLComponents;
    airWatchURLComponents = [NSURLComponents componentsWithString:self.serverURL.stringValue];
    airWatchURLComponents.path = kServerURIUser;
    NSURLQueryItem *userQuery = [NSURLQueryItem queryItemWithName:@"user" value:self.searchValue.stringValue ];
    NSURLQueryItem *pageSize = [NSURLQueryItem queryItemWithName:@"pagesize" value:self.maxDeviceSearch.selectedItem.title];
    airWatchURLComponents.queryItems = @[ userQuery, pageSize ];
    
    // Create the base64 encoded authentication
    NSString *authenticationString = [NSString stringWithFormat:@"%@:%@", self.userName.stringValue, self.password.stringValue];
    NSData *authenticationData = [authenticationString dataUsingEncoding:NSASCIIStringEncoding];
    NSString *b64AuthenticationString = [authenticationData base64EncodedStringWithOptions:0];
    NSString *totalAuthHeader = [@"Basic " stringByAppendingString:b64AuthenticationString];
    //NSLog(@"Base64 Encoded Creds: %@", b64AuthenticationString);
    
    // Complete the URL request and add-in headers
    NSMutableURLRequest *URLRequest = [NSMutableURLRequest requestWithURL:airWatchURLComponents.URL];
    [URLRequest addValue:self.awTenantCode.stringValue forHTTPHeaderField:@"aw-tenant-code"];
    [URLRequest addValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [URLRequest addValue:totalAuthHeader forHTTPHeaderField:@"Authorization"];
    URLRequest.HTTPMethod = @"GET";
    
    // Run the query using the URL request and return the JSON code
    NSURLSession *session = [NSURLSession sharedSession];
    [[session dataTaskWithRequest:URLRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (!data) return;
        NSDictionary *returnedJSON = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
        
        // Since we are running in a separate thread, we need to return the dict values to the main thread in order to update the GUI
        dispatch_async(dispatch_get_main_queue(), ^{
            NSMutableArray *devicesArray = [NSMutableArray array];
            //NSLog(@"%@", returnedJSON[@"Devices"]);
            self.deviceTableArray = returnedJSON[@"Devices"];
            for (NSDictionary *device in returnedJSON[@"Devices"]) {
                Device *d = [[Device alloc] init];
                d.deviceModel = device[@"Model"];
                d.customerEmailAddress = device[@"UserEmailAddress"];
                d.deviceSerialNumber = device[@"SerialNumber"];
                d.deviceMACAddress = device[@"MacAddress"];
                d.devicePlatform = device[@"Platform"];
                d.deviceOS = device[@"OperatingSystem"];
                d.deviceSupervisedBool = device[@"IsSupervised"];
                d.deviceIMEI = device[@"Imei"];
                d.devicePhoneNumber = device[@"PhoneNumber"];
                d.deviceVirtualMemory = device[@"VirtualMemory"];
                d.deviceACLineStatus = device[@"AcLineStatus"];
                d.deviceLastSeen = device[@"LastSeen"];
                d.deviceAssetNumber = device[@"AssetNumber"];
                d.deviceCompromisedStatus = device[@"CompromisedStatus"];
                d.deviceComplianceStatus = device[@"ComplianceStatus"];
                d.deviceLocationGroupName = device[@"LocationGroupName"];
                d.deviceEnrollmentStatus = device[@"EnrollmentStatus"];
                d.deviceUDID = device[@"Udid"];
                [devicesArray addObject:d];
            }
            self.devicesArray = devicesArray;
            [self.deviceTableView reloadData];
        });
    }] resume];
    return nil;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return [self.deviceTableArray count];
}


- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSLog(@"In the Table view function now.");
    NSDictionary *device = self.deviceTableArray[row];
    NSString *identifier = [tableColumn identifier];
    NSLog(@"%@", device);
    if ([identifier isEqualToString:@"serial_number_column"]) {
        NSTableCellView *cellView = [tableView makeViewWithIdentifier:@"serial_number_column" owner:self];
        [cellView.textField setStringValue:device[@"SerialNumber"]];
        return cellView;
    }
    if ([identifier isEqualToString:@"model_column"]) {
        NSTableCellView *cellView = [tableView makeViewWithIdentifier:@"model_column" owner:self];
        [cellView.textField setStringValue:device[@"Model"]];
        return cellView;
    }
    return nil;
}

- (NSDictionary *)deviceDetails {
    // Create the URL request with the hostname and search URI's
    NSURLComponents *airWatchURLComponents = [NSURLComponents componentsWithString:self.serverURL.stringValue];
    airWatchURLComponents.path = kServerURIDevices;
    NSURLQueryItem *userQuery = [NSURLQueryItem queryItemWithName:@"searchby" value:self.searchParamater.selectedItem.title];
    NSURLQueryItem *pageSize = [NSURLQueryItem queryItemWithName:@"id" value:self.searchValue.stringValue];
    airWatchURLComponents.queryItems = @[ userQuery, pageSize ];

    // Create the base64 encoded authentication
    NSString *authenticationString = [NSString stringWithFormat:@"%@:%@", self.userName.stringValue, self.password.stringValue];
    NSData *authenticationData = [authenticationString dataUsingEncoding:NSASCIIStringEncoding];
    NSString *b64AuthenticationString = [authenticationData base64EncodedStringWithOptions:0];
    NSString *totalAuthHeader = [@"Basic " stringByAppendingString:b64AuthenticationString];
    //NSLog(@"Base64 Encoded Creds: %@", b64AuthenticationString);
    
    // Complete the URL request and add-in headers
    NSMutableURLRequest *URLRequest = [NSMutableURLRequest requestWithURL:airWatchURLComponents.URL];
    [URLRequest addValue:self.awTenantCode.stringValue forHTTPHeaderField:@"aw-tenant-code"];
    [URLRequest addValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [URLRequest addValue:totalAuthHeader forHTTPHeaderField:@"Authorization"];
    URLRequest.HTTPMethod = @"GET";
    
    // Run the query using the URL request and return the JSON code
    NSURLSession *session = [NSURLSession sharedSession];
    [[session dataTaskWithRequest:URLRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        //NSLog(@"%@", data);
        if (!data) return;
        NSDictionary *returnedJSON = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
        
        // Since we are running in a separate thread, we need to return the dict values to the main thread in order to update the GUI
        dispatch_async(dispatch_get_main_queue(), ^{
            NSDictionary *device;
            NSMutableArray *devicesArray = [NSMutableArray array];
            NSMutableArray *deviceTableArray = [NSMutableArray arrayWithObject:returnedJSON];

            device = returnedJSON;
            Device *d = [[Device alloc] init];
            d.deviceModel = device[@"Model"];
            d.customerEmailAddress = device[@"UserEmailAddress"];
            d.deviceSerialNumber = device[@"SerialNumber"];
            d.deviceMACAddress = device[@"MacAddress"];
            d.devicePlatform = device[@"Platform"];
            d.deviceOS = device[@"OperatingSystem"];
            d.deviceSupervisedBool = device[@"IsSupervised"];
            d.deviceIMEI = device[@"Imei"];
            d.devicePhoneNumber = device[@"PhoneNumber"];
            d.deviceVirtualMemory = device[@"VirtualMemory"];
            d.deviceACLineStatus = device[@"AcLineStatus"];
            d.deviceLastSeen = device[@"LastSeen"];
            d.deviceAssetNumber = device[@"AssetNumber"];
            d.deviceCompromisedStatus = device[@"CompromisedStatus"];
            d.deviceComplianceStatus = device[@"ComplianceStatus"];
            d.deviceLocationGroupName = device[@"LocationGroupName"];
            d.deviceEnrollmentStatus = device[@"EnrollmentStatus"];
            d.deviceUDID = device[@"Udid"];
            [devicesArray addObject:d];
            self.devicesArray = devicesArray;
            self.deviceTableArray = deviceTableArray;
            [self.deviceTableView reloadData];
        });
    }] resume];
    return nil;
}

//- (void)tableViewSelectionDidChange:(NSNotification *)notification {
//    NSInteger tableIndex = [notification.object selectedRow];
//    dispatch_async(dispatch_get_main_queue(), ^{
//        self.deviceOS = self.devicesArray[tableIndex][@"OperatingSystem"];
//    });
//    
//}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

- (IBAction)searchButton:(id)sender {
    if ([self.searchParamater.selectedItem.title isEqualToString:@"UserName"]) {
        NSLog(@"UserName was chosen. Checking if username entered");
        NSLog(@"Search value given: %@", self.searchValue.stringValue);
        if (self.searchValue.stringValue.length == 0) {
            NSAlert *alert = [[NSAlert alloc] init];
            [alert addButtonWithTitle:@"OK"];
            [alert setMessageText:@"No username given!"];
            [alert setInformativeText:@"Please enter a username to search for."];
            [alert setAlertStyle:NSAlertStyleWarning];
            [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
                return;
            }];
        } else {
            [self userDeviceDetails];
        }
    } else {
        if (self.searchValue.stringValue.length == 0) {
            NSAlert *alert = [[NSAlert alloc] init];
            [alert addButtonWithTitle:@"OK"];
            [alert setMessageText:@"No device info given!"];
            [alert setInformativeText:@"Please enter a value to search on that corresponds to the search paramater chosen."];
            [alert setAlertStyle:NSAlertStyleWarning];
            [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
                return;
            }];
        } else {
            [self deviceDetails];
        }
    }
}
- (void)showCredsWindow {
    [self.window beginSheet:self.credsWindow completionHandler:^(NSModalResponse returnCode) {
        return;
    }];
}
- (IBAction)creds:(id)sender {
    [self.window beginSheet:self.credsWindow completionHandler:^(NSModalResponse returnCode) {
        return;
    }];
}
- (IBAction)closeCredsSheet:(id)sender {
    [self setCredsToKeychainWithUserName:self.userName.stringValue serverURL:self.serverURL.stringValue password:self.password.stringValue awTenantCode:self.awTenantCode.stringValue];
    [self.window endSheet:self.credsWindow];
}

- (IBAction)refreshDeviceDetails:(id)sender {
    NSInteger selectedRow = [self.deviceTableView selectedRow];
    NSMutableArray *devicesArray = [NSMutableArray array];
    Device *d = [[Device alloc] init];
    d.deviceModel = self.deviceTableArray[selectedRow][@"Model"];
    d.customerEmailAddress = self.deviceTableArray[selectedRow][@"UserEmailAddress"];
    d.deviceSerialNumber = self.deviceTableArray[selectedRow][@"SerialNumber"];
    d.deviceMACAddress = self.deviceTableArray[selectedRow][@"MacAddress"];
    d.devicePlatform = self.deviceTableArray[selectedRow][@"Platform"];
    d.deviceOS = self.deviceTableArray[selectedRow][@"OperatingSystem"];
    d.deviceSupervisedBool = self.deviceTableArray[selectedRow][@"IsSupervised"];
    d.deviceIMEI = self.deviceTableArray[selectedRow][@"Imei"];
    d.devicePhoneNumber = self.deviceTableArray[selectedRow][@"PhoneNumber"];
    d.deviceVirtualMemory = self.deviceTableArray[selectedRow][@"VirtualMemory"];
    d.deviceACLineStatus = self.deviceTableArray[selectedRow][@"AcLineStatus"];
    d.deviceLastSeen = self.deviceTableArray[selectedRow][@"LastSeen"];
    d.deviceAssetNumber = self.deviceTableArray[selectedRow][@"AssetNumber"];
    d.deviceCompromisedStatus = self.deviceTableArray[selectedRow][@"CompromisedStatus"];
    d.deviceComplianceStatus = self.deviceTableArray[selectedRow][@"ComplianceStatus"];
    d.deviceLocationGroupName = self.deviceTableArray[selectedRow][@"LocationGroupName"];
    d.deviceEnrollmentStatus = self.deviceTableArray[selectedRow][@"EnrollmentStatus"];
    d.deviceUDID = self.deviceTableArray[selectedRow][@"Udid"];
    [devicesArray addObject:d];
    self.devicesArray = devicesArray;
}
@end
