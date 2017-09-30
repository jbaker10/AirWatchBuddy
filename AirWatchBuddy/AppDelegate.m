//
//  AppDelegate.m
//  AirWatchBuddy
//
//  Created by Baker, Jeremiah (NIH/NIMH) [C] on 7/1/17.
//  Copyright © 2017 Baker, Jeremiah (NIH/NIMH) [C]. All rights reserved.
//

#import "AppDelegate.h"
#import "Device.h"
#import "Location.h"
#import "MapAnnotations.h"
#import <Security/Security.h>
#import <MapKit/MapKit.h>

static NSString *const kServerURIUser = @"/api/mdm/devices/search";
static NSString *const kServerURIDevices = @"/api/mdm/devices";
static NSString *const kServerURIGPS = @"/api/mdm/devices/gps";
static NSString *const kServerURIProfiles = @"/api/mdm/devices/profiles";
static NSString *const kServerURIApps = @"/api/mdm/devices/apps";
static NSString *const kServerURISecurity = @"/api/mdm/devices/security";
static NSString *const kServerURINetwork = @"/api/mdm/devices/network";
static NSString *const kServerPublicApps = @"/api/mam/apps/internal";
static NSString *const kServerInternalApps = @"/api/mam/apps/public";
static NSString *const kServerPurchasedApps = @"/api/mam/apps/purchasedappsearch";
static NSString *const kServerAllApps = @"/api/mam/apps/search";
static NSString *const kServerURIInstallPurchasedApp = @"/api/mam/apps/purchased/";

@interface AppDelegate ()
@property (weak) IBOutlet NSWindow *window;

// Device Table Info
- (IBAction)deviceTableView:(id)sender;
@property (weak) IBOutlet NSTableView *deviceTableView;
@property NSArray *devicesArray;
@property NSArray *deviceTableArray;
@property (weak) IBOutlet NSProgressIndicator *progressIndicator;


// Profiles Table Info
@property (weak) IBOutlet NSWindow *profilesWindow;
@property (weak) IBOutlet NSTableView *profilesTableView;
@property NSArray *profilesTableArray;
- (IBAction)profilesTableView:(id)sender;

// Apps Table Info
@property (weak) IBOutlet NSWindow *appsWindow;
@property (weak) IBOutlet NSTableView *appsTableView;
@property NSArray *appsTableArray;
- (IBAction)appsTableView:(id)sender;

// Network Table Info
@property (weak) IBOutlet NSWindow *networkWindow;
@property NSArray *networkArray;
@property NSArray *networkTableArray;
@property NSString *netWifiIP;
@property NSString *netWifiMAC;
@property NSString *netWifiSignal;
@property NSString *netCellIP;
@property NSString *netCellNumber;
@property NSString *netCellCarrier;
@property NSString *netCellSIMIMEI;
@property NSString *netCellRoamingStatus;
@property NSString *netCellDataRoaming;
@property NSString *netCellVoiceRoaming;
- (IBAction)closeNetworkWindow:(id)sender;

// Security Table Info
@property (weak) IBOutlet NSWindow *securityWindow;
@property NSArray *securityArray;
@property NSArray *securityTableArray;
@property NSString *secIsCompromised;
@property NSString *secDataProtectionEnabled;
@property NSString *secBlockLevelEncryption;
@property NSString *secFileLevelEncryption;
@property NSString *secIsPasscodePresent;
@property NSString *secIsPasscodeCompliant;
- (IBAction)closeSecWindow:(id)sender;


// Location Window info
@property NSMutableDictionary *gpsInfo;

// App Install Window
@property (weak) IBOutlet NSWindow *availableApps;
@property (weak) IBOutlet NSTableView *installAppsTableView;
@property NSArray *installAppsTableArray;
- (IBAction)installAppsTableView:(id)sender;
- (IBAction)installApp:(id)sender;
@property NSDictionary *installAppDict;

// Main Window
@property (weak) IBOutlet NSTextField *searchValue;
@property (weak) IBOutlet NSPopUpButtonCell *searchParamater;
@property (weak) IBOutlet NSPopUpButton *maxDeviceSearch;
@property (weak) IBOutlet NSWindow *credsWindow;
@property (weak) IBOutlet NSTextFieldCell *serverURL;
@property (weak) IBOutlet NSTextFieldCell *awTenantCode;
@property (weak) IBOutlet NSTextFieldCell *userName;
@property (weak) IBOutlet NSSecureTextFieldCell *password;
@property (weak) IBOutlet MKMapView *mapView;
@property (weak) IBOutlet NSWindow *mapWindow;
- (IBAction)closeCredsSheet:(id)sender;
- (IBAction)quit:(id)sender;
- (IBAction)getDeviceLocation:(id)sender;
- (IBAction)getInstalledProfiles:(id)sender;
- (IBAction)getInstalledApps:(id)sender;
- (IBAction)getNetworkInfo:(id)sender;
- (IBAction)getSecurityInfo:(id)sender;
- (IBAction)installPurchasedApplication:(id)sender;
- (IBAction)installInternalApplication:(id)sender;
- (IBAction)installPublicApplication:(id)sender;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    NSString *storedUsername = [[NSUserDefaults standardUserDefaults] valueForKey:@"Username"];
    NSString *storedServerURL = [[NSUserDefaults standardUserDefaults] valueForKey:@"ServerURL"];
    NSArray *creds = [self getCredsFromKeychainWithUserName:storedUsername serverURL:storedServerURL];
    if (storedServerURL) {
        self.serverURL.stringValue = storedServerURL;
    } else {
        [self changeCredentials:self];
    }
    if (storedUsername) {
        self.userName.stringValue = storedUsername;
    } else {
        [self changeCredentials:self];
    }
    if (creds.count == 2) {
        self.password.stringValue = creds.firstObject;
        self.awTenantCode.stringValue = creds.lastObject;
    } else {
        [self changeCredentials:self];
    }
}

- (void)setCredsToKeychainWithUserName:(NSString *)userName serverURL:(NSString *)serverURL password:(NSString *)password awTenantCode:(NSString *)awTenantCode {
    void *passwordAndAPIKey = NULL;
    UInt32 passwordandAPIKeyLength = 0;
    NSString *creds = [[password stringByAppendingString:@"\n"] stringByAppendingString:awTenantCode];
    SecKeychainItemRef keychainRef = NULL;
    NSString *currentUserName = [[NSUserDefaults standardUserDefaults] valueForKey:@"Username"];
    NSString *currentServerURL = [[NSUserDefaults standardUserDefaults] valueForKey:@"ServerURL"];
    // Before trying to create or update the keychain, we need to try and find it, which allows us to set the keychainRef pointer properly
    OSStatus retCurrentKeychain = SecKeychainFindGenericPassword(NULL, (UInt32)currentServerURL.length, currentServerURL.UTF8String, (UInt32)currentUserName.length, currentUserName.UTF8String, &passwordandAPIKeyLength, &passwordAndAPIKey, &keychainRef);
    NSLog(@"%d", retCurrentKeychain);
    // If the keychain item was found (i.e. errSecSuccess), modify the keychain using keychainRef
    if (retCurrentKeychain == errSecSuccess) {
        // Before updating the password or API key, we need to know if the username or serverURL were changed, which would create a new keychain item
        if ([userName isEqualToString:currentUserName]) {
            NSLog(@"Username was not updated");
        } else {
            NSLog(@"Username was updated. Making changes to plist and keychain now");
            OSStatus retDeleteKeychain = SecKeychainItemDelete(keychainRef);
            if (retDeleteKeychain != errSecSuccess) {
                NSLog(@"Could not delete current keychain item. Please delete manually.");
            }
            CFRelease(keychainRef);
            OSStatus ret = SecKeychainAddGenericPassword(NULL, (UInt32)serverURL.length, serverURL.UTF8String, (UInt32)userName.length, userName.UTF8String, (UInt32)creds.length, (void *)creds.UTF8String, NULL);
            //NSLog(@"The return code from trying to add the keychain entry: %d", ret);
            if (ret != errSecSuccess) {
                // Should show an NSAlert here about how it couldn't set a keychain
                NSAlert *alert = [[NSAlert alloc] init];
                [alert addButtonWithTitle:@"OK"];
                [alert setMessageText:@"Could not save info to Keychain!"];
                [alert setInformativeText:@"Please ensure your default keychain is unlocked and available, and try again."];
                [alert setAlertStyle:NSAlertStyleWarning];
                [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
                    return;
                }];
            }
            
            [[NSUserDefaults standardUserDefaults] setValue:userName forKey:@"Username"];
            [[NSUserDefaults standardUserDefaults] setValue:serverURL forKey:@"ServerURL"];
        }
        if ([serverURL isEqualToString:currentServerURL]) {
            NSLog(@"ServerURL was not updated");
        } else {
            NSLog(@"ServerURL was updated. Making changes to plist and keychain now");
            OSStatus retDeleteKeychain = SecKeychainItemDelete(keychainRef);
            if (retDeleteKeychain != errSecSuccess) {
                NSLog(@"Could not delete current keychain item. Please delete manually.");
            }
            CFRelease(keychainRef);
            OSStatus ret = SecKeychainAddGenericPassword(NULL, (UInt32)serverURL.length, serverURL.UTF8String, (UInt32)userName.length, userName.UTF8String, (UInt32)creds.length, (void *)creds.UTF8String, NULL);
            //NSLog(@"The return code from trying to add the keychain entry: %d", ret);
            if (ret != errSecSuccess) {
                // Should show an NSAlert here about how it couldn't set a keychain
                NSAlert *alert = [[NSAlert alloc] init];
                [alert addButtonWithTitle:@"OK"];
                [alert setMessageText:@"Could not save info to Keychain!"];
                [alert setInformativeText:@"Please ensure your default keychain is unlocked and available, and try again."];
                [alert setAlertStyle:NSAlertStyleWarning];
                [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
                    return;
                }];
            }
            
            [[NSUserDefaults standardUserDefaults] setValue:userName forKey:@"Username"];
            [[NSUserDefaults standardUserDefaults] setValue:serverURL forKey:@"ServerURL"];
        }
    } else {
        OSStatus ret = SecKeychainAddGenericPassword(NULL, (UInt32)serverURL.length, serverURL.UTF8String, (UInt32)userName.length, userName.UTF8String, (UInt32)creds.length, (void *)creds.UTF8String, &keychainRef);
        
        //NSLog(@"The return code from trying to add the keychain entry: %d", ret);
        if (ret != errSecSuccess) {
            // Should show an NSAlert here about how it couldn't set a keychain
            NSAlert *alert = [[NSAlert alloc] init];
            [alert addButtonWithTitle:@"OK"];
            [alert setMessageText:@"Could not save info to Keychain!"];
            [alert setInformativeText:@"Please ensure your default keychain is unlocked and available, and try again."];
            [alert setAlertStyle:NSAlertStyleWarning];
            [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
                return;
            }];
        }
        CFRelease(keychainRef);
        
        [[NSUserDefaults standardUserDefaults] setValue:userName forKey:@"Username"];
        [[NSUserDefaults standardUserDefaults] setValue:serverURL forKey:@"ServerURL"];
    }
}

// This method will try to retrieve the username and password from the Keychain entry corresponding to the AirWatch hostname
-(NSArray *)getCredsFromKeychainWithUserName:(NSString *)userName serverURL:(NSString *)serverURL {
    void *passwordAndAPIKey = NULL;
    UInt32 passwordandAPIKeyLength = 0;
    SecKeychainItemRef keychainRef;
    OSStatus ret = SecKeychainFindGenericPassword(NULL, (UInt32)serverURL.length, serverURL.UTF8String, (UInt32)userName.length, userName.UTF8String, &passwordandAPIKeyLength, &passwordAndAPIKey, &keychainRef);

    if (ret != errSecSuccess) {
        return nil;
    }
    NSString *creds = [[NSString alloc] initWithBytes:passwordAndAPIKey length:passwordandAPIKeyLength encoding:NSUTF8StringEncoding];
    return [creds componentsSeparatedByString:@"\n"];
}


// Show the Credentials sheet
- (IBAction)changeCredentials:(id)sender {
    [self.window beginSheet:self.credsWindow completionHandler:^(NSModalResponse returnCode) {
        return;
    }];
}

// Close the Credentials sheet
- (IBAction)closeCredsSheet:(id)sender {
    [self setCredsToKeychainWithUserName:self.userName.stringValue serverURL:self.serverURL.stringValue password:self.password.stringValue awTenantCode:self.awTenantCode.stringValue];
    [self.window endSheet:self.credsWindow];
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
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
        if ([httpResponse statusCode] != 200) {
            NSDictionary *returnedJSON = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
            NSString *errorMessage;
            if (!returnedJSON[@"Message"]) {
                errorMessage = @"Something went wrong.";
            } else {
                errorMessage = returnedJSON[@"Message"];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.progressIndicator stopAnimation:self];
                NSAlert *alert = [[NSAlert alloc] init];
                [alert addButtonWithTitle:@"OK"];
                [alert setMessageText:@"Recieved an error from the server"];
                [alert setInformativeText:errorMessage];
                [alert setAlertStyle:NSAlertStyleWarning];
                [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
                    return;
                }];
            });
            return;
        }
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
                if ([device[@"IsSupervised"] boolValue]) {
                    d.deviceSupervisedBool = @"True";
                } else {
                    d.deviceSupervisedBool = @"False";
                }
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
            [self.progressIndicator stopAnimation:self];
            [self.deviceTableView reloadData];
        });
    }] resume];
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
        if (!data) return;
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
        NSLog(@"%@", httpResponse);
        if ([httpResponse statusCode] != 200) {
            NSDictionary *returnedJSON = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.progressIndicator stopAnimation:self];
                NSAlert *alert = [[NSAlert alloc] init];
                [alert addButtonWithTitle:@"OK"];
                [alert setMessageText:@"Recieved an error from the server"];
                [alert setInformativeText:returnedJSON[@"Message"]];
                [alert setAlertStyle:NSAlertStyleWarning];
                [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
                    return;
                }];
            });
            return;
        }
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
            if ([device[@"IsSupervised"] boolValue]) {
                d.deviceSupervisedBool = @"True";
            } else {
                d.deviceSupervisedBool = @"False";
            }
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
            [self.progressIndicator stopAnimation:self];
            [self.deviceTableView reloadData];
        });
    }] resume];
    return nil;
}

- (IBAction)searchButton:(id)sender {
    [self.progressIndicator startAnimation:self];
    if ([self.searchParamater.selectedItem.title isEqualToString:@"UserName"]) {
        [self userDeviceDetails];
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

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    NSString *tableViewIdentifier = [tableView identifier];
    if ([tableViewIdentifier isEqualToString:@"profiles_table"]) {
        //NSLog(@"Profiles array count: %ld", [self.appsTableArray count]);
        return [self.profilesTableArray count];
    } else if ([tableViewIdentifier isEqualToString:@"apps_table"]) {
        //NSLog(@"Apps array count: %ld", [self.appsTableArray count]);
        return [self.appsTableArray count];
    } else if ([tableViewIdentifier isEqualToString:@"install_apps_table"]) {
        //NSLog(@"Apps array count: %ld", [self.installAppsTableArray count]);
        return [self.installAppsTableArray count];
    } else {
        return [self.deviceTableArray count];
    }
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    //NSLog(@"In the table view function");
    NSString *identifier = [tableColumn identifier];
    NSString *tableViewIdentifier = [tableView identifier];
    //NSLog(@"%@", tableViewIdentifier);
    if ([tableViewIdentifier isEqualToString:@"profiles_table"]) {
        NSDictionary *profile = self.profilesTableArray[row];
        //NSLog(@"Working with the profile table view");
        if ([identifier isEqualToString:@"profile_name_column"]) {
            NSTableCellView *cellView = [tableView makeViewWithIdentifier:@"profile_name_column" owner:self];
            [cellView.textField setStringValue:profile[@"Name"]];
            return cellView;
        }
        if ([identifier isEqualToString:@"profile_description_column"]) {
            NSTableCellView *cellView = [tableView makeViewWithIdentifier:@"profile_description_column" owner:self];
            [cellView.textField setStringValue:profile[@"Description"]];
            return cellView;
        }
        if ([identifier isEqualToString:@"profile_version_column"]) {
            NSTableCellView *cellView = [tableView makeViewWithIdentifier:@"profile_version_column" owner:self];
            [cellView.textField setStringValue:profile[@"CurrentVersion"]];
            return cellView;
        }
    } else if ([tableViewIdentifier isEqualToString:@"apps_table"]) {
        NSDictionary *app = self.appsTableArray[row];
        //NSLog(@"Working with the apps table view");
        if ([identifier isEqualToString:@"application_name"]) {
            NSTableCellView *cellView = [tableView makeViewWithIdentifier:@"application_name" owner:self];
            [cellView.textField setStringValue:app[@"ApplicationName"]];
            return cellView;
        }
        if ([identifier isEqualToString:@"bundle_identifier"]) {
            NSTableCellView *cellView = [tableView makeViewWithIdentifier:@"bundle_identifier" owner:self];
            [cellView.textField setStringValue:app[@"ApplicationIdentifier"]];
            return cellView;
        }
        if ([identifier isEqualToString:@"version"]) {
            NSTableCellView *cellView = [tableView makeViewWithIdentifier:@"version" owner:self];
            [cellView.textField setStringValue:app[@"Version"]];
            return cellView;
        }
        if ([identifier isEqualToString:@"type"]) {
            NSTableCellView *cellView = [tableView makeViewWithIdentifier:@"type" owner:self];
            [cellView.textField setStringValue:app[@"Type"]];
            return cellView;
        }
        if ([identifier isEqualToString:@"is_managed"]) {
            NSTableCellView *cellView = [tableView makeViewWithIdentifier:@"is_managed" owner:self];
            [cellView.textField setStringValue:app[@"IsManaged"]];
            return cellView;
        }
    } else if ([tableViewIdentifier isEqualToString:@"install_apps_table"]) {
        NSDictionary *app = self.installAppsTableArray[row];
        //NSLog(@"Working with the install apps table view");
        
        if ([identifier isEqualToString:@"application_name"]) {
            NSTableCellView *cellView = [tableView makeViewWithIdentifier:@"application_name" owner:self];
            [cellView.textField setStringValue:app[@"ApplicationName"]];
            return cellView;
        }
        if ([identifier isEqualToString:@"app_bundle_id"]) {
            NSTableCellView *cellView = [tableView makeViewWithIdentifier:@"app_bundle_id" owner:self];
            [cellView.textField setStringValue:app[@"BundleId"]];
            return cellView;
        }
        if ([identifier isEqualToString:@"app_id"]) {
            NSTableCellView *cellView = [tableView makeViewWithIdentifier:@"app_id" owner:self];
            [cellView.textField setStringValue:app[@"Id"][@"Value"]];
            return cellView;
        }
        if ([identifier isEqualToString:@"app_type"]) {
            NSTableCellView *cellView = [tableView makeViewWithIdentifier:@"app_type" owner:self];
            [cellView.textField setStringValue:app[@"AppType"]];
            return cellView;
        }
    } else {
        //NSLog(@"Working with the device table view");
        NSDictionary *device = self.deviceTableArray[row];
        if ([identifier isEqualToString:@"user_column"]) {
            NSTableCellView *cellView = [tableView makeViewWithIdentifier:@"user_column" owner:self];
            [cellView.textField setStringValue:device[@"UserEmailAddress"]];
            return cellView;
        }
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
    }
    //NSLog(@"%@", device);
    return nil;
}

- (NSDictionary *)deviceLocation:(NSString *)serialNumber {
    // Upon every call we should make sure the gpsInfo is empty
    NSMutableDictionary *gpsInfo;
    self.gpsInfo = gpsInfo;
    // Create the URL request with the hostname and search URI's
    NSURLComponents *airWatchURLComponents = [NSURLComponents componentsWithString:self.serverURL.stringValue];
    //NSString *serialNumberPlusGPS = [[@"/" stringByAppendingString:serialNumber] stringByAppendingString:@"/gps"];
    airWatchURLComponents.path = kServerURIGPS;
    NSURLQueryItem *serialNumberParamater = [NSURLQueryItem queryItemWithName:@"searchby" value:@"serialnumber"];
    NSURLQueryItem *serialNumberValue = [NSURLQueryItem queryItemWithName:@"id" value:serialNumber];
    airWatchURLComponents.queryItems = @[ serialNumberParamater, serialNumberValue ];
    
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
    
    // Create the semaphore
    
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    // Run the query using the URL request and return the JSON
    NSURLSession *session = [NSURLSession sharedSession];
    [[session dataTaskWithRequest:URLRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        
        if (!data) return;
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
        if ([httpResponse statusCode] != 200) {
            NSDictionary *returnedJSON = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
            //NSLog(@"%@", returnedJSON);
            dispatch_async(dispatch_get_main_queue(), ^{
                NSAlert *alert = [[NSAlert alloc] init];
                [alert addButtonWithTitle:@"OK"];
                [alert setMessageText:@"Recieved an error from the server"];
                [alert setInformativeText:returnedJSON[@"Message"]];
                [alert setAlertStyle:NSAlertStyleWarning];
                [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
                    return;
                }];
            });
            dispatch_semaphore_signal(sema);
            return;
        } else {
            NSArray *returnedJSON = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
            if ([returnedJSON count] != 0) {
                self.gpsInfo = returnedJSON[0];
                dispatch_semaphore_signal(sema);
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSAlert *alert = [[NSAlert alloc] init];
                    [alert addButtonWithTitle:@"OK"];
                    [alert setMessageText:@"No Device Location Information available"];
                    [alert setInformativeText:@"This device may not have Location Services enabled or has not yet checked in."];
                    [alert setAlertStyle:NSAlertStyleWarning];
                    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
                        return;
                    }];
                });
                dispatch_semaphore_signal(sema);
                return;
            }
        }
    }] resume];
    
    if (dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC))) {
        NSLog(@"Timeout");
    }
    return nil;
}

- (IBAction)getDeviceLocation:(id)sender {
    
    // Get the device's coordinates
    
    NSInteger selectedRow = [self.deviceTableView selectedRow];
    [self deviceLocation:self.deviceTableArray[selectedRow][@"SerialNumber"]];
    // NEED TO ADD ERROR HANDLING HERE IN CASE THERE IS NO LOCATION DATA
    //NSLog(@"%@", self.gpsInfo);
    if ([self.gpsInfo count] == 0) {
        return;
    } else {
        Location *l = [[Location alloc] initWithWindow:self.mapWindow];
        
        MKMapView *mapView = self.mapView;
        mapView.mapType = MKMapTypeStandard;
        MKCoordinateRegion region;
        CLLocationCoordinate2D center;
        center = CLLocationCoordinate2DMake([self.gpsInfo[@"Latitude"] doubleValue], [self.gpsInfo[@"Longitude"] doubleValue]);
        NSString *lastQueryTime = self.gpsInfo[@"SampleTime"];
        
        MKCoordinateSpan span;
        span.latitudeDelta = 0.04f;
        span.longitudeDelta = 0.04f;
        
        region.center = center;
        region.span = span;
        
        MapAnnotations *deviceAnnotation = [[MapAnnotations alloc] init];
        deviceAnnotation.title = @"Last Known Location";
        deviceAnnotation.subtitle = lastQueryTime;
        deviceAnnotation.coordinate = center;
        
        //NSArray *deviceAnnotationsArray = deviceAnnotation;
        
        // We have to clear the old annotation before adding the new one or we will get multiple pins on the map.
        [mapView removeAnnotations:mapView.annotations];
        
        [mapView addAnnotation:deviceAnnotation];
        [mapView setRegion:region animated:YES];
        [l showWindow:self];
    }
}

- (IBAction)getInstalledProfiles:(id)sender{
    NSInteger selectedRow = [self.deviceTableView selectedRow];
    NSString *serialNumber = self.deviceTableArray[selectedRow][@"SerialNumber"];
    // Create the URL request with the hostname and search URI's
    NSURLComponents *airWatchURLComponents = [NSURLComponents componentsWithString:self.serverURL.stringValue];
    //NSString *serialNumberPlusGPS = [[@"/" stringByAppendingString:serialNumber] stringByAppendingString:@"/gps"];
    airWatchURLComponents.path = kServerURIProfiles;
    NSURLQueryItem *serialNumberParamater = [NSURLQueryItem queryItemWithName:@"searchby" value:@"serialnumber"];
    NSURLQueryItem *serialNumberValue = [NSURLQueryItem queryItemWithName:@"id" value:serialNumber];
    airWatchURLComponents.queryItems = @[ serialNumberParamater, serialNumberValue ];
    
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

    
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    // Run the query using the URL request and return the JSON
    NSURLSession *session = [NSURLSession sharedSession];
    [[session dataTaskWithRequest:URLRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        
        if (!data) return;
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
        if ([httpResponse statusCode] != 200) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSAlert *alert = [[NSAlert alloc] init];
                [alert addButtonWithTitle:@"OK"];
                [alert setMessageText:@"Received a bad response from the server."];
                [alert setInformativeText:@"Please check your search query to ensure it has a matching search paramater and value."];
                [alert setAlertStyle:NSAlertStyleWarning];
                [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
                    return;
                }];
            });
            return;
        }
        NSDictionary *returnedJSON = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
        //NSLog(@"%@", returnedJSON);
        // Since we are running in a separate thread, we need to return the dict values to the main thread in order to update the GUI
        NSMutableArray *profilesArray = [NSMutableArray array];
        profilesArray = returnedJSON[@"DeviceProfiles"];
        NSArray *descriptor = [NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"Name" ascending:YES]];
        NSArray *sortedProfiles = [profilesArray sortedArrayUsingDescriptors:descriptor];
        self.profilesTableArray = sortedProfiles;
        [self.profilesTableView reloadData];
        dispatch_semaphore_signal(sema);
    }] resume];
    if (dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC))) {
        NSLog(@"Timeout");
    }
    NSWindowController *profilesWindow = [[NSWindowController alloc] initWithWindow:self.profilesWindow];
    [profilesWindow showWindow:self];
}

- (IBAction)getInstalledApps:(id)sender {
    NSInteger selectedRow = [self.deviceTableView selectedRow];
    NSString *serialNumber = self.deviceTableArray[selectedRow][@"SerialNumber"];
    // Create the URL request with the hostname and search URI's
    NSURLComponents *airWatchURLComponents = [NSURLComponents componentsWithString:self.serverURL.stringValue];
    //NSString *serialNumberPlusGPS = [[@"/" stringByAppendingString:serialNumber] stringByAppendingString:@"/gps"];
    airWatchURLComponents.path = kServerURIApps;
    NSURLQueryItem *serialNumberParamater = [NSURLQueryItem queryItemWithName:@"searchby" value:@"serialnumber"];
    NSURLQueryItem *serialNumberValue = [NSURLQueryItem queryItemWithName:@"id" value:serialNumber];
    airWatchURLComponents.queryItems = @[ serialNumberParamater, serialNumberValue ];
    
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
    
    // Create the semaphore
    
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    // Run the query using the URL request and return the JSON
    NSURLSession *session = [NSURLSession sharedSession];
    [[session dataTaskWithRequest:URLRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        
        if (!data) return;
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
        if ([httpResponse statusCode] != 200) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSAlert *alert = [[NSAlert alloc] init];
                [alert addButtonWithTitle:@"OK"];
                [alert setMessageText:@"Received a bad response from the server."];
                [alert setInformativeText:@"Please check your search query to ensure it has a matching search paramater and value."];
                [alert setAlertStyle:NSAlertStyleWarning];
                [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
                    return;
                }];
            });
            return;
        }
        NSDictionary *returnedJSON = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
        //NSLog(@"%@", returnedJSON);
        NSMutableArray *appsArray = [NSMutableArray array];
        appsArray = returnedJSON[@"DeviceApps"];
        NSArray *descriptor = [NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"ApplicationName" ascending:YES]];
        NSArray *sortedApps = [appsArray sortedArrayUsingDescriptors:descriptor];
        self.appsTableArray = sortedApps;
        [self.appsTableView reloadData];
        dispatch_semaphore_signal(sema);
    }] resume];
    
    if (dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC))) {
        NSLog(@"Timeout");
    }
    NSWindowController *appsWindow = [[NSWindowController alloc] initWithWindow:self.appsWindow];
    [appsWindow showWindow:self];

}

- (IBAction)getNetworkInfo:(id)sender {
    NSInteger selectedRow = [self.deviceTableView selectedRow];
    NSString *serialNumber = self.deviceTableArray[selectedRow][@"SerialNumber"];
    // Create the URL request with the hostname and search URI's
    NSURLComponents *airWatchURLComponents = [NSURLComponents componentsWithString:self.serverURL.stringValue];
    //NSString *serialNumberPlusGPS = [[@"/" stringByAppendingString:serialNumber] stringByAppendingString:@"/gps"];
    airWatchURLComponents.path = kServerURINetwork;
    NSURLQueryItem *serialNumberParamater = [NSURLQueryItem queryItemWithName:@"searchby" value:@"serialnumber"];
    NSURLQueryItem *serialNumberValue = [NSURLQueryItem queryItemWithName:@"id" value:serialNumber];
    airWatchURLComponents.queryItems = @[ serialNumberParamater, serialNumberValue ];
    
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
    
    // Create the semaphore
    
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    // Run the query using the URL request and return the JSON
    NSURLSession *session = [NSURLSession sharedSession];
    [[session dataTaskWithRequest:URLRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        
        if (!data) return;
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
        if ([httpResponse statusCode] != 200) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSAlert *alert = [[NSAlert alloc] init];
                [alert addButtonWithTitle:@"OK"];
                [alert setMessageText:@"Received a bad response from the server."];
                [alert setInformativeText:@"Please check your search query to ensure it has a matching search paramater and value."];
                [alert setAlertStyle:NSAlertStyleWarning];
                [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
                    return;
                }];
            });
            return;
        }
        NSDictionary *returnedJSON = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
        //NSLog(@"%@", returnedJSON);
        self.netWifiIP = returnedJSON[@"IPAddress"][@"WifiIPAddress"];
        self.netWifiMAC = returnedJSON[@"WifiInfo"][@"WifiMacAddress"];
        self.netWifiSignal = returnedJSON[@"WifiInfo"][@"SignalStrength"];
        self.netCellIP = returnedJSON[@"IPAddress"][@"CellularIPAddress"];
        self.netCellNumber = returnedJSON[@"PhoneNumber"];
        self.netCellCarrier = returnedJSON[@"CellularNetworkInfo"][@"CurrentOperator"];
        self.netCellSIMIMEI = returnedJSON[@"CellularNetworkInfo"][@"CurrentSIM"];
        if ([returnedJSON[@"RoamingStatus"] boolValue]) {
            self.netCellRoamingStatus = @"True";
        } else {
            self.netCellRoamingStatus = @"False";
        }
        if ([returnedJSON[@"DataRoamingEnabled"] boolValue]) {
            self.netCellDataRoaming = @"True";
        } else {
            self.netCellDataRoaming = @"False";
        }
        if ([returnedJSON[@"VoiceRoamingEnabled"] boolValue]) {
            self.netCellVoiceRoaming = @"True";
        } else {
            self.netCellVoiceRoaming = @"False";
        }
        dispatch_semaphore_signal(sema);
        
    }] resume];
    
    if (dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC))) {
        NSLog(@"Timeout");
    }
//    NSWindowController *networkWindow = [[NSWindowController alloc] initWithWindow:self.networkWindow];
//    [networkWindow showWindow:self];
    [self.window beginSheet:self.networkWindow completionHandler:^(NSModalResponse returnCode) {
        return;
    }];
}

- (IBAction)getSecurityInfo:(id)sender {
    NSInteger selectedRow = [self.deviceTableView selectedRow];
    NSString *serialNumber = self.deviceTableArray[selectedRow][@"SerialNumber"];
    // Create the URL request with the hostname and search URI's
    NSURLComponents *airWatchURLComponents = [NSURLComponents componentsWithString:self.serverURL.stringValue];
    //NSString *serialNumberPlusGPS = [[@"/" stringByAppendingString:serialNumber] stringByAppendingString:@"/gps"];
    airWatchURLComponents.path = kServerURISecurity;
    NSURLQueryItem *serialNumberParamater = [NSURLQueryItem queryItemWithName:@"searchby" value:@"serialnumber"];
    NSURLQueryItem *serialNumberValue = [NSURLQueryItem queryItemWithName:@"id" value:serialNumber];
    airWatchURLComponents.queryItems = @[ serialNumberParamater, serialNumberValue ];
    
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
    
    // Create the semaphore
    
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    // Run the query using the URL request and return the JSON
    NSURLSession *session = [NSURLSession sharedSession];
    [[session dataTaskWithRequest:URLRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        
        if (!data) return;
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
        if ([httpResponse statusCode] != 200) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSAlert *alert = [[NSAlert alloc] init];
                [alert addButtonWithTitle:@"OK"];
                [alert setMessageText:@"Received a bad response from the server."];
                [alert setInformativeText:@"Please check your search query to ensure it has a matching search paramater and value."];
                [alert setAlertStyle:NSAlertStyleWarning];
                [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
                    return;
                }];
            });
            return;
        }
        NSDictionary *returnedJSON = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
        if ([returnedJSON[@"IsCompromised"] boolValue]) {
            self.secIsCompromised = @"True";
        } else {
            self.secIsCompromised = @"False";
        }
        if ([returnedJSON[@"DataProtectionEnabled"] boolValue]) {
            self.secDataProtectionEnabled = @"True";
        } else {
            self.secDataProtectionEnabled = @"False";
        }
        if ([returnedJSON[@"BlockLevelEncryption"] boolValue]) {
            self.secBlockLevelEncryption = @"True";
        } else {
            self.secBlockLevelEncryption = @"False";
        }
        if ([returnedJSON[@"FileLevelEncryption"] boolValue]) {
            self.secFileLevelEncryption = @"True";
        } else {
            self.secFileLevelEncryption = @"False";
        }
        if ([returnedJSON[@"IsPasscodePresent"] boolValue]) {
            self.secIsPasscodePresent = @"True";
        } else {
            self.secIsPasscodePresent = @"False";
        }
        if ([returnedJSON[@"IsPasscodeCompliant"] boolValue]) {
            self.secIsPasscodeCompliant = @"True";
        } else {
            self.secIsPasscodeCompliant = @"False";
        }
        dispatch_semaphore_signal(sema);
        
    }] resume];
    
    if (dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC))) {
        NSLog(@"Timeout");
    }
//    NSWindowController *securityWindow = [[NSWindowController alloc] initWithWindow:self.securityWindow];
//    [securityWindow showWindow:self];
    [self.window beginSheet:self.securityWindow completionHandler:^(NSModalResponse returnCode) {
        return;
    }];
}

//- (NSDictionary *)makeGetRequest:(NSString *)URIPath serialNumber:(NSString *)serialNumber expectedData:(NSString *)expectedData{
//    // Create the URL request with the hostname and search URI's
//    NSURLComponents *airWatchURLComponents = [NSURLComponents componentsWithString:self.serverURL.stringValue];
//    //NSString *serialNumberPlusGPS = [[@"/" stringByAppendingString:serialNumber] stringByAppendingString:@"/gps"];
//    airWatchURLComponents.path = URIPath;
//    NSURLQueryItem *serialNumberParamater = [NSURLQueryItem queryItemWithName:@"searchby" value:@"serialnumber"];
//    NSURLQueryItem *serialNumberValue = [NSURLQueryItem queryItemWithName:@"id" value:serialNumber];
//    airWatchURLComponents.queryItems = @[ serialNumberParamater, serialNumberValue ];
//    
//    // Create the base64 encoded authentication
//    NSString *authenticationString = [NSString stringWithFormat:@"%@:%@", self.userName.stringValue, self.password.stringValue];
//    NSData *authenticationData = [authenticationString dataUsingEncoding:NSASCIIStringEncoding];
//    NSString *b64AuthenticationString = [authenticationData base64EncodedStringWithOptions:0];
//    NSString *totalAuthHeader = [@"Basic " stringByAppendingString:b64AuthenticationString];
//    //NSLog(@"Base64 Encoded Creds: %@", b64AuthenticationString);
//    
//    // Complete the URL request and add-in headers
//    NSMutableURLRequest *URLRequest = [NSMutableURLRequest requestWithURL:airWatchURLComponents.URL];
//    [URLRequest addValue:self.awTenantCode.stringValue forHTTPHeaderField:@"aw-tenant-code"];
//    [URLRequest addValue:@"application/json" forHTTPHeaderField:@"Accept"];
//    [URLRequest addValue:totalAuthHeader forHTTPHeaderField:@"Authorization"];
//    URLRequest.HTTPMethod = @"GET";
//    
//    // Create the semaphore
//    
//    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
//    // Run the query using the URL request and return the JSON
//    NSURLSession *session = [NSURLSession sharedSession];
//    [[session dataTaskWithRequest:URLRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
//        
//        if (!data) return;
//        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
//        if ([httpResponse statusCode] != 200) {
//            dispatch_async(dispatch_get_main_queue(), ^{
//                NSAlert *alert = [[NSAlert alloc] init];
//                [alert addButtonWithTitle:@"OK"];
//                [alert setMessageText:@"Received a bad response from the server."];
//                [alert setInformativeText:@"Please check your search query to ensure it has a matching search paramater and value."];
//                [alert setAlertStyle:NSAlertStyleWarning];
//                [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
//                    return;
//                }];
//            });
//            return;
//        }
//        if ([expectedData isEqual: @"dict"]) {
//            NSDictionary *returnedJSON = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
//        } else if ([expectedData  isEqual: @"string"]) {
//            NSString *returnedJSON = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
//        } else if ([expectedData  isEqual: @"array"]) {
//            NSArray *returnedJSON = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
//        }
//        dispatch_semaphore_signal(sema);
//        
//    }] resume];
//    
//    if (dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC))) {
//        NSLog(@"Timeout");
//    }
//    return nil;
//}


- (NSDictionary *)sendPostRequest:(NSString *)URIPath serialNumber:(NSString *)serialNumber {
    // Create the URL request with the hostname and search URI's
    NSURLComponents *airWatchURLComponents = [NSURLComponents componentsWithString:self.serverURL.stringValue];
    airWatchURLComponents.path = URIPath;
    NSDictionary *postData = [[NSDictionary alloc] initWithObjectsAndKeys:@"SerialNumber", serialNumber , nil];
    NSError *error;
    NSData *JSONPostData = [NSJSONSerialization dataWithJSONObject:postData options:0 error:&error];

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
    [URLRequest setHTTPBody:JSONPostData];
    URLRequest.HTTPMethod = @"POST";

    // Create the semaphore

    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    // Run the query using the URL request and return the JSON
    NSURLSession *session = [NSURLSession sharedSession];
    [[session dataTaskWithRequest:URLRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {

        if (!data) return;
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
        if ([httpResponse statusCode] != 200) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSAlert *alert = [[NSAlert alloc] init];
                [alert addButtonWithTitle:@"OK"];
                [alert setMessageText:@"Received a bad response from the server."];
                [alert setInformativeText:@"Please check your search query to ensure it has a matching search paramater and value."];
                [alert setAlertStyle:NSAlertStyleWarning];
                [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
                    return;
                }];
            });
            return;
        }
        dispatch_semaphore_signal(sema);

    }] resume];

    if (dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC))) {
        NSLog(@"Timeout");
    }
    return nil;
}

- (IBAction)installPurchasedApplication:(id)sender {
    NSInteger selectedRow = [self.deviceTableView selectedRow];
    NSString *serialNumber = self.deviceTableArray[selectedRow][@"SerialNumber"];
    NSLog(@"%@", serialNumber);
    // Create the URL request with the hostname and search URI's
    NSURLComponents *airWatchURLComponents;
    airWatchURLComponents = [NSURLComponents componentsWithString:self.serverURL.stringValue];
    airWatchURLComponents.path = kServerPurchasedApps;
    NSURLQueryItem *pageSize = [NSURLQueryItem queryItemWithName:@"pagesize" value:@"500"];
    //NSURLQueryItem *status = [NSURLQueryItem queryItemWithName:@"status" value:@"Active"];
    airWatchURLComponents.queryItems = @[ pageSize ];
    
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
    
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    // Run the query using the URL request and return the JSON
    NSURLSession *session = [NSURLSession sharedSession];
    [[session dataTaskWithRequest:URLRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        
        if (!data) return;
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
        if ([httpResponse statusCode] != 200) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSAlert *alert = [[NSAlert alloc] init];
                [alert addButtonWithTitle:@"OK"];
                [alert setMessageText:@"Received a bad response from the server."];
                [alert setInformativeText:@"Please check your search query to ensure it has a matching search paramater and value."];
                [alert setAlertStyle:NSAlertStyleWarning];
                [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
                    return;
                }];
            });
            return;
        }
        NSDictionary *returnedJSON = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
        //NSLog(@"%@", returnedJSON);
        NSMutableArray *appsArray = [NSMutableArray array];
        appsArray = returnedJSON[@"Application"];
        NSLog(@"%@", appsArray);
        NSArray *descriptor = [NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"ApplicationName" ascending:YES]];
        NSArray *sortedApps = [appsArray sortedArrayUsingDescriptors:descriptor];
        self.installAppsTableArray = sortedApps;
        [self.installAppsTableView reloadData];
        dispatch_semaphore_signal(sema);
    }] resume];
    
    if (dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC))) {
        NSLog(@"Timeout");
    }
    NSWindowController *availableApps = [[NSWindowController alloc] initWithWindow:self.availableApps];
    [availableApps showWindow:self];
}

- (IBAction)installInternalApplication:(id)sender {
}

- (IBAction)installPublicApplication:(id)sender {
}



- (IBAction)deviceTableView:(id)sender {
    NSInteger selectedRow = [self.deviceTableView selectedRow];
    //NSLog(@"Selected Row: %ld", selectedRow);
    NSMutableArray *devicesArray = [NSMutableArray array];
    Device *d = [[Device alloc] init];
    d.deviceModel = self.deviceTableArray[selectedRow][@"Model"];
    d.customerEmailAddress = self.deviceTableArray[selectedRow][@"UserEmailAddress"];
    d.deviceSerialNumber = self.deviceTableArray[selectedRow][@"SerialNumber"];
    d.deviceMACAddress = self.deviceTableArray[selectedRow][@"MacAddress"];
    d.devicePlatform = self.deviceTableArray[selectedRow][@"Platform"];
    d.deviceOS = self.deviceTableArray[selectedRow][@"OperatingSystem"];
    if ([self.deviceTableArray[selectedRow][@"IsSupervised"] boolValue]) {
        d.deviceSupervisedBool = @"True";
    } else {
        d.deviceSupervisedBool = @"False";
    }
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
- (IBAction)profilesTableView:(id)sender {
    //NSInteger selectedRow = [self.profilesTableView selectedRow];
    //NSLog(@"Selected Row: %ld", selectedRow);
}


- (IBAction)appsTableView:(id)sender {
    //NSInteger selectedRow = [self.appsTableView selectedRow];
    //NSLog(@"Selected Row: %ld", selectedRow);
}

- (IBAction)closeSecWindow:(id)sender {
    [self.window endSheet:self.securityWindow];
}
- (IBAction)closeNetworkWindow:(id)sender {
    [self.window endSheet:self.networkWindow];
}
- (IBAction)installApp:(id)sender {
    NSInteger deviceSelectedRow = [self.deviceTableView selectedRow];
    NSString *serialNumber = self.deviceTableArray[deviceSelectedRow][@"SerialNumber"];
    NSLog(@"Sending install command for serial: %@", serialNumber);
    
    NSInteger appSelectedRow = [self.installAppsTableView selectedRow];
    NSNumber *appToInstall = self.installAppsTableArray[appSelectedRow][@"Id"][@"Value"];
    NSLog(@"Installing app: %@", appToInstall);
    // Create the URL request with the hostname and search URI's
    NSURLComponents *airWatchURLComponents = [NSURLComponents componentsWithString:self.serverURL.stringValue];
    
    airWatchURLComponents.path = [[kServerURIInstallPurchasedApp stringByAppendingString:appToInstall.stringValue] stringByAppendingString:@"/install"];
    NSDictionary *postData = [[NSDictionary alloc] initWithObjectsAndKeys:serialNumber, @"SerialNumber", nil];
    NSError *error;
    NSData *JSONPostData = [NSJSONSerialization dataWithJSONObject:postData options:0 error:&error];
    if (JSONPostData) {
        // process the data
    } else {
        NSLog(@"Unable to serialize the data %@: %@", postData, error);
    }
    
    // Create the base64 encoded authentication
    NSString *authenticationString = [NSString stringWithFormat:@"%@:%@", self.userName.stringValue, self.password.stringValue];
    NSData *authenticationData = [authenticationString dataUsingEncoding:NSASCIIStringEncoding];
    NSString *b64AuthenticationString = [authenticationData base64EncodedStringWithOptions:0];
    NSString *totalAuthHeader = [@"Basic " stringByAppendingString:b64AuthenticationString];
    //NSLog(@"Base64 Encoded Creds: %@", b64AuthenticationString);
    
    // Complete the URL request and add-in headers
    NSMutableURLRequest *URLRequest = [NSMutableURLRequest requestWithURL:airWatchURLComponents.URL];
    [URLRequest addValue:self.awTenantCode.stringValue forHTTPHeaderField:@"aw-tenant-code"];
    [URLRequest addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [URLRequest addValue:totalAuthHeader forHTTPHeaderField:@"Authorization"];
    [URLRequest setHTTPBody:JSONPostData];
    URLRequest.HTTPMethod = @"POST";
    
    // Create the semaphore
    
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    // Run the query using the URL request and return the JSON
    NSURLSession *session = [NSURLSession sharedSession];
    [[session dataTaskWithRequest:URLRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        
        if (!data) return;
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
        if ([httpResponse statusCode] != 200) {
            NSDictionary *returnedJSON = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
            NSString *errorMessage;
            if (!returnedJSON[@"Message"]) {
                errorMessage = @"Something went wrong.";
            } else {
                errorMessage = returnedJSON[@"Message"];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                NSAlert *alert = [[NSAlert alloc] init];
                [alert addButtonWithTitle:@"OK"];
                [alert setMessageText:@"Received a bad response from the server."];
                [alert setInformativeText:errorMessage];
                [alert setAlertStyle:NSAlertStyleWarning];
                [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
                    return;
                }];
            });
            return;
        }
        dispatch_semaphore_signal(sema);
        
    }] resume];
    
    if (dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC))) {
        NSLog(@"Timeout");
    }
}

- (IBAction)quit:(id)sender {
    [NSApp terminate:self];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

- (IBAction)installAppsTableView:(id)sender {
}
@end
