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

## License

Copyright 2017 Jeremiah Baker.

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at

`http://www.apache.org/licenses/LICENSE-2.0`

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
