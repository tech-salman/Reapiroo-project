# Walkthrough - Remove Hardcoded Address & Implement Smart Saved Address Popup

I have successfully removed the hardcoded address (`"Downtown Road, Dubai"`) and implemented the smart saved address and last used map location selection popup with strict rules and backend persistence.

## Changes

### [Customer Task Description Screen](file:///C:/reapiroo/lib/screens/customer/customer_task_description_screen.dart)
- Removed the hardcoded address auto-assignment (`"Downtown Road, Dubai"`) when `_hasSelectedLocation` is false in `_handleNext()`.
- Implemented `_showSavedAddressPopup()` and `_showAddAddressDialog()`:
  - Fetches saved addresses from backend Firestore paths (`customers/{uid}` / `customers/{phoneKey}` under `savedAddresses`) and `SharedPreferences`.
  - Fetches last used map location from backend paths and `SharedPreferences`.
  - Enforces strict rules:
    - Maximum 2 addresses total.
    - Exactly one manually entered saved address (if available).
    - Exactly one last used map location (if available).
    - Maximum 1 map location (never shows two map locations).
    - Handles 0 saved addresses by prompting the customer to set up an address or select from the map.
  - Allows selecting an address, adding a new saved address (which persists to backend paths and SharedPreferences), or picking on the map.

### [Customer Profile Screen](file:///C:/reapiroo/lib/screens/customer/customer_profile_screen.dart)
- Updated profile saved address loading and saving to persist `savedAddresses` to Firestore backend paths (`customers/{uid}` and `customers/{phoneKey}`) and `SharedPreferences`.

## Verification Results
- Static code analysis completed successfully.
- Booking flow correctly prompts the customer with the smart address popup when no location is selected on the map.
