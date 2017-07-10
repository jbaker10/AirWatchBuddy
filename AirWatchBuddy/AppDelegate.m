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

#define theSpan 0.30f;
static NSString *const kServerURIUser = @"/api/mdm/devices/search";
static NSString *const kServerURIDevices = @"/api/mdm/devices";
static NSString *const kServerURIGPS = @"/api/mdm/devices/gps";
static NSString *const kServerURIProfiles = @"/api/mdm/devices/profiles";
static NSString *const kServerURIApps = @"/api/mdm/devices/apps";
static NSString *const kServerURISecurity = @"/api/mdm/devices/security";
static NSString *const kServerURINetwork = @"/api/mdm/devices/network";

@interface AppDelegate ()
- (IBAction)deviceTableView:(id)sender;
@property (weak) IBOutlet NSTableView *deviceTableView;
@property (weak) IBOutlet NSWindow *window;
@property NSArray *devicesArray;
@property NSArray *deviceTableArray;
@property NSMutableDictionary *gpsInfo;
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
- (IBAction)showCredentials:(id)sender;
- (IBAction)getDeviceLocation:(id)sender;
- (IBAction)getInstalledProfiles:(id)sender;
- (IBAction)getInstalledApps:(id)sender;
- (IBAction)getNetworkInfo:(id)sender;
- (IBAction)getSecurityInfo:(id)sender;
- (IBAction)installApplication:(id)sender;
- (IBAction)closeProfilesSheet:(id)sender;
@property (weak) IBOutlet NSWindow *profilesWindow;



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
        [self showCredentials:self];
    }
}

- (void)setCredsToKeychainWithUserName:(NSString *)userName serverURL:(NSString *)serverURL password:(NSString *)password awTenantCode:(NSString *)awTenantCode {
    NSString *creds = [[password stringByAppendingString:@"\n"] stringByAppendingString:awTenantCode];
    
    OSStatus ret = SecKeychainAddGenericPassword(NULL, (UInt32)serverURL.length, serverURL.UTF8String, (UInt32)userName.length, userName.UTF8String, (UInt32)creds.length, (void *)creds.UTF8String, NULL);
    //NSLog(@"The return code from trying to add the keychain entry: %d", ret);
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
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
        if ([httpResponse statusCode] != 200) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSAlert *alert = [[NSAlert alloc] init];
                [alert addButtonWithTitle:@"OK"];
                [alert setMessageText:@"Received a bad response from the server."];
                [alert setInformativeText:@"Please check your search query to ensure it has a matching search paramter and value."];
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
            [self.deviceTableView reloadData];
        });
    }] resume];
    return nil;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return [self.deviceTableArray count];
}


- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    //NSLog(@"In the Table view function now.");
    NSDictionary *device = self.deviceTableArray[row];
    NSString *identifier = [tableColumn identifier];
    //NSLog(@"%@", device);
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
            dispatch_async(dispatch_get_main_queue(), ^{
                NSAlert *alert = [[NSAlert alloc] init];
                [alert addButtonWithTitle:@"OK"];
                [alert setMessageText:@"Received a bad response from the server."];
                [alert setInformativeText:@"Please check your search query to ensure it has a matching search paramter and value."];
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
            [self.deviceTableView reloadData];
        });
    }] resume];
    return nil;
}

- (NSDictionary *)deviceLocation:(NSString *)serialNumber {
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
        NSArray *returnedJSON = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
        NSMutableDictionary *gpsDict = returnedJSON[0];
        self.gpsInfo = gpsDict;
        dispatch_semaphore_signal(sema);
        
    }] resume];
    
    if (dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC))) {
        NSLog(@"Timeout");
    }
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

- (IBAction)closeCredsSheet:(id)sender {
    [self setCredsToKeychainWithUserName:self.userName.stringValue serverURL:self.serverURL.stringValue password:self.password.stringValue awTenantCode:self.awTenantCode.stringValue];
    [self.window endSheet:self.credsWindow];
}

- (IBAction)quit:(id)sender {
    [NSApp terminate:self];
}

- (IBAction)showCredentials:(id)sender {
    [self.window beginSheet:self.credsWindow completionHandler:^(NSModalResponse returnCode) {
        return;
    }];
}


- (IBAction)getDeviceLocation:(id)sender {
    // Get the device's coordinates
    NSInteger selectedRow = [self.deviceTableView selectedRow];
    [self deviceLocation:self.deviceTableArray[selectedRow][@"SerialNumber"]];
    // NEED TO ADD ERROR HANDLING HERE IN CASE THERE IS NO LOCATION DATA
    Location *l = [[Location alloc] initWithWindow:self.mapWindow];
    [l showWindow:self];
    MKMapView *mapView = self.mapView;
    mapView.mapType = MKMapTypeStandard;
    MKCoordinateRegion region;
    CLLocationCoordinate2D center;
    center = CLLocationCoordinate2DMake([self.gpsInfo[@"Latitude"] doubleValue], [self.gpsInfo[@"Longitude"] doubleValue]);
    NSString *lastQueryTime = self.gpsInfo[@"SampleTime"];
    
    MKCoordinateSpan span;
    span.latitudeDelta = theSpan;
    span.longitudeDelta = theSpan;
    
    //[mapView showAnnotations:annotation animated:YES];
    region.center = center;
    region.span = span;
    
    MapAnnotations *deviceAnnotation = [[MapAnnotations alloc] init];
    deviceAnnotation.title = @"Last Known Location";
    deviceAnnotation.subtitle = lastQueryTime;
    deviceAnnotation.coordinate = center;

    
    [mapView addAnnotation:deviceAnnotation];
    [mapView setRegion:region animated:YES];

}

- (IBAction)getInstalledProfiles:(id)sender{
    [self.window beginSheet:self.profilesWindow completionHandler:^(NSModalResponse returnCode) {
        return;
    }];
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
        NSLog(@"%@", returnedJSON);
        dispatch_semaphore_signal(sema);
        
    }] resume];
    
    if (dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC))) {
        NSLog(@"Timeout");
    }
}

- (IBAction)getInstalledApps:(id)sender {
    [self.window beginSheet:self.profilesWindow completionHandler:^(NSModalResponse returnCode) {
        return;
    }];
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
        NSLog(@"%@", returnedJSON);
        dispatch_semaphore_signal(sema);
        
    }] resume];
    
    if (dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC))) {
        NSLog(@"Timeout");
    }
}

- (IBAction)getNetworkInfo:(id)sender {
    [self.window beginSheet:self.profilesWindow completionHandler:^(NSModalResponse returnCode) {
        return;
    }];
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
        NSLog(@"%@", returnedJSON);
        dispatch_semaphore_signal(sema);
        
    }] resume];
    
    if (dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC))) {
        NSLog(@"Timeout");
    }
}

- (IBAction)getSecurityInfo:(id)sender {
    [self.window beginSheet:self.profilesWindow completionHandler:^(NSModalResponse returnCode) {
        return;
    }];
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
        NSLog(@"%@", returnedJSON);
        dispatch_semaphore_signal(sema);
        
    }] resume];
    
    if (dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC))) {
        NSLog(@"Timeout");
    }
}

- (NSDictionary *)configuredAPICall:(NSString *)URIPath serialNumber:(NSString *)serialNumber expectedData:(NSString *)expectedData{
    // Create the URL request with the hostname and search URI's
    NSURLComponents *airWatchURLComponents = [NSURLComponents componentsWithString:self.serverURL.stringValue];
    //NSString *serialNumberPlusGPS = [[@"/" stringByAppendingString:serialNumber] stringByAppendingString:@"/gps"];
    airWatchURLComponents.path = URIPath;
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
        if ([expectedData  isEqual: @"dict"]) {
            NSDictionary *returnedJSON = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
        } else if ([expectedData  isEqual: @"string"]) {
            NSString *returnedJSON = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
        } else if ([expectedData  isEqual: @"array"]) {
            NSArray *returnedJSON = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
        }
        dispatch_semaphore_signal(sema);
        
    }] resume];
    
    if (dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC))) {
        NSLog(@"Timeout");
    }
    return nil;
}

- (IBAction)installApplication:(id)sender {
    [self.window beginSheet:self.profilesWindow completionHandler:^(NSModalResponse returnCode) {
        return;
    }];
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
        NSArray *returnedJSON = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
        NSLog(@"%@", returnedJSON);
        dispatch_semaphore_signal(sema);
        
    }] resume];
    
    if (dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC))) {
        NSLog(@"Timeout");
    }
}

- (IBAction)closeProfilesSheet:(id)sender {
    [self.window endSheet:self.profilesWindow];
}

- (IBAction)deviceTableView:(id)sender {
    NSInteger selectedRow = [self.deviceTableView selectedRow];
    NSLog(@"Selected Row: %ld", selectedRow);
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
@end
