# Remove Hardcoded Address & Implement Smart Saved Address / Last Used Location Popup for Booking

## Problem Statement
When a customer is entering booking information in [customer_task_description_screen.dart](file:///C:/reapiroo/lib/screens/customer/customer_task_description_screen.dart) and clicks "Next" without explicitly selecting a location on the map, a hardcoded address (`"Downtown Road, Dubai"`) is automatically applied. The user wants this hardcoded address removed. Instead, when no location is selected and "Next" is pressed, a popup dialog should appear allowing the customer to choose a saved address according to strict rules.

## User Review Required & Rules
- **Remove Hardcoded Address**: Do not auto-apply `"Downtown Road, Dubai"` when `_hasSelectedLocation` is false.
- **Show Address Selection Popup**: When `_hasSelectedLocation` is false and the user clicks "Next", show a popup dialog presenting available saved/recent addresses.
- **Address Selection Cases**:
  1. **No Saved Address**: The popup informs the customer that there are no saved addresses and asks them to set up an address (or pick from maps).
  2. **One Saved Address**: The popup presents the single saved address (or option to use it / select from map).
  3. **Multiple Saved Addresses (Twist / Max 2 rule)**:
     - Show **maximum two addresses**:
       - Address 1: A manually entered saved address by the customer.
       - Address 2: The last used map location from the previous booking.
     - Strictly enforce **no more than two addresses** and **never show two map locations**.

## Proposed Changes

### [Customer Task Description Screen](file:///C:/reapiroo/lib/screens/customer/customer_task_description_screen.dart)
- Modify `_handleNext()`:
  - If `!_hasSelectedLocation`, instead of setting `"Downtown Road, Dubai"`, display a custom saved/recent address selection dialog.
- Implement `_showSavedAddressPopup()`:
  - Fetch saved addresses from SharedPreferences / Database / Profile storage.
  - Fetch the last used map location (`customer_request_location` or `user_address`).
  - Apply the rules:
    - 0 addresses: show empty state prompting to add an address / pick on map.
    - 1 address: show that single saved address + option to pick on map.
    - 2+ addresses: filter/select exactly one manually entered saved address and one last used map location (max 2 addresses total).
  - Allow the user to select one of the shown addresses or choose "Select on Maps" / "Add New Address".
  - Proceed with booking creation upon selection.

## Verification Plan

### Automated Tests
- Build test / static analysis via IDE inspections.

### Manual Verification
- Test booking flow without selecting map location:
  - Verify popup appears instead of hardcoded address.
  - Test case with 0 saved addresses.
  - Test case with 1 saved address.
  - Test case with multiple saved addresses (verifying max 2 addresses: 1 manual saved + 1 last used map location).
