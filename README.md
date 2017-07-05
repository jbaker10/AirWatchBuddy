# AirWatchBuddy
AirWatchBuddy is a simple API companion app that will pull device information from your AirWatch instance. The information can be retrieved using one of 5 queries:
* UserName - Can be a username or will search as a wildcard string. 
  * I.e. User `bakerjr`'s devices will be returned with a search for `baker` among any other Baker's in your organization
* SerialNumber - The devices Serial Number
* IMEI - The devices IMEI number
* MAC Address - The devices MAC Address
* UDID - The device's UDID as defined in AirWatch

AirwatchBuddy requires the FQDN or IP address for your AirWatch server, as well as your AW Tenant Code (your API code) and a username and password for an account with API privileges. This information is all stored in the user's default keychain.

AirWatchBuddy also places a preference file on disk under `~/Library/Preferences/com.jbakersystems.AirWatchBuddy` where both the `ServerURL` and `Username` info is kept. These fields are used to key off of and search for your keychain entry to authenticate for the API call.

## Credits
* Tom Burgin - Thanks for teaching me and helping me create this app!
* AirWatchBuddy icon by [New Haricut](https://thenounproject.com/newhaircut/)
