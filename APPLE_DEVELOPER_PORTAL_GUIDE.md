# Apple Developer Portal Configuration Guide

## 🎯 Objective
Enable Sign in with Apple capability for your app: `com.ancientplus.flip`

## 📋 Prerequisites
- Apple Developer Account access
- Admin or Account Holder role (required to modify capabilities)

---

## Part 1: Enable Sign in with Apple Capability

### Step 1: Navigate to Apple Developer Portal
1. Open browser and go to: https://developer.apple.com/account/
2. Sign in with your Apple ID (the one used for your developer account)
3. You should see the main Account page

### Step 2: Access Certificates, Identifiers & Profiles
1. Look for the sidebar or main menu
2. Click on **"Certificates, Identifiers & Profiles"**
3. This will take you to the certificate management area

### Step 3: Find Your App Identifier
1. In the left sidebar, click **"Identifiers"**
2. You'll see a list of all your app identifiers
3. Find and click on: **`com.ancientplus.flip`**
   - Use the search box if you have many identifiers
   - It should show as an "App ID" type

### Step 4: Enable Sign in with Apple
1. Once you've opened your app identifier, scroll down
2. You'll see a long list of capabilities (checkboxes)
3. Find **"Sign in with Apple"** in the list
4. ✅ **Check the checkbox** next to "Sign in with Apple"
5. A configuration dialog may appear:
   - Select "Enable as a primary App ID"
   - Click "Save" or "Continue"

### Step 5: Save Changes
1. Scroll to the top of the page
2. Click the **"Save"** button in the top-right corner
3. You'll see a confirmation message
4. The capability is now enabled!

---

## Part 2: Regenerate Provisioning Profiles

**Why:** After adding a new capability, existing provisioning profiles need to be regenerated to include the new entitlement.

### Step 1: Navigate to Profiles
1. In the left sidebar, click **"Profiles"**
2. You'll see a list of all your provisioning profiles

### Step 2: Regenerate Development Profile
1. Find your **Development** profile for `com.ancientplus.flip`
   - Usually named something like "iOS Team Provisioning Profile" or "Development Profile"
2. Click on the profile name to open it
3. Click the **"Edit"** button
4. Scroll down and click **"Generate"** or **"Save"**
5. Click **"Download"** to download the updated profile
6. **Double-click** the downloaded file to install it in Xcode

### Step 3: Regenerate Distribution Profile
1. Find your **Distribution** profile for `com.ancientplus.flip`
   - Usually named something like "App Store Distribution" or "Distribution Profile"
2. Click on the profile name to open it
3. Click the **"Edit"** button
4. Scroll down and click **"Generate"** or **"Save"**
5. Click **"Download"** to download the updated profile
6. **Double-click** the downloaded file to install it in Xcode

### Step 4: Verify Installation in Xcode
1. Open Xcode
2. Go to **Xcode** → **Settings** (or Preferences on older versions)
3. Click on the **"Accounts"** tab
4. Select your Apple ID
5. Click **"Download Manual Profiles"**
6. Verify your profiles are up to date

---

## Part 3: Verify Configuration in Xcode

### Step 1: Open Your Project
```bash
cd /path/to/your/project
open ios/Runner.xcworkspace
```

### Step 2: Check Signing & Capabilities
1. In Xcode, in the left sidebar, click on **"Runner"** (the blue icon at the top)
2. Make sure **"Runner"** target is selected (not RunnerTests)
3. Click on the **"Signing & Capabilities"** tab at the top
4. You should now see:
   - ✅ Automatically manage signing (checked)
   - ✅ Team: Your development team
   - ✅ **Sign in with Apple** capability listed

### Step 3: Add Capability if Missing
If you don't see "Sign in with Apple" in the capabilities list:
1. Click the **"+ Capability"** button
2. Search for "Sign in with Apple"
3. Double-click it to add
4. It should now appear in your capabilities list

### Step 4: Verify Entitlements File
1. In the left sidebar (Project Navigator), expand the **Runner** folder
2. You should see **"Runner.entitlements"** file
3. Click on it to view contents
4. Verify it contains:
   ```xml
   <key>com.apple.developer.applesignin</key>
   <array>
       <string>Default</string>
   </array>
   ```

---

## 🎬 Visual Walkthrough

### Apple Developer Portal Navigation Flow:
```
developer.apple.com/account
    ↓
Certificates, Identifiers & Profiles
    ↓
Identifiers → Select App ID → com.ancientplus.flip
    ↓
Scroll down → Find "Sign in with Apple" → ✅ Check it
    ↓
Save (top-right)
    ↓
Profiles → Select each profile → Edit → Generate → Download
```

### Xcode Configuration Flow:
```
Open ios/Runner.xcworkspace
    ↓
Select Runner target
    ↓
Signing & Capabilities tab
    ↓
Verify "Sign in with Apple" appears
    ↓
If not present: + Capability → Add "Sign in with Apple"
```

---

## ✅ Verification Checklist

After completing all steps, verify:
- [ ] "Sign in with Apple" capability is enabled in Apple Developer Portal
- [ ] Development provisioning profile regenerated and installed
- [ ] Distribution provisioning profile regenerated and installed
- [ ] Xcode shows "Sign in with Apple" in Signing & Capabilities
- [ ] Runner.entitlements file exists and contains Sign in with Apple key
- [ ] No signing errors in Xcode

---

## 🚨 Troubleshooting

### Issue: "Sign in with Apple" option is grayed out
**Cause:** Your Apple Developer Program membership may not be active or you don't have admin rights.
**Solution:** 
- Verify your Apple Developer Program membership is active
- Check that you have the appropriate role (Admin or Account Holder)

### Issue: Can't find provisioning profile
**Cause:** Profile might not exist yet or was deleted.
**Solution:**
- Create a new provisioning profile:
  1. Go to Profiles
  2. Click the "+" button
  3. Select "iOS App Development" or "App Store Distribution"
  4. Follow the wizard to create new profile

### Issue: Xcode says "Provisioning profile doesn't include Sign in with Apple"
**Cause:** Profile wasn't regenerated after enabling the capability.
**Solution:**
- Go back to Apple Developer Portal
- Regenerate the profiles again
- Download and install them
- Clean build folder in Xcode: Product → Clean Build Folder

### Issue: Multiple accounts in Xcode causing confusion
**Solution:**
1. Xcode → Settings → Accounts
2. Remove any old or unused Apple IDs
3. Keep only the active developer account
4. Download profiles for the correct account

---

## 📞 Need Help?

### Apple Developer Support:
- Phone: 1-800-633-2152 (US)
- Website: https://developer.apple.com/support/
- Email support available through your Apple Developer account

### Common Questions:

**Q: How long does it take for the capability to activate?**
A: Immediately after saving. No waiting period.

**Q: Do I need to pay extra for Sign in with Apple?**
A: No, it's included in your Apple Developer Program membership ($99/year).

**Q: Can I test without enabling the capability?**
A: No, iOS will block the Sign in with Apple API without the capability.

**Q: Will this affect my Android app?**
A: No, these changes only affect iOS. Android uses a separate Sign in with Apple implementation.

---

## ⏱️ Time Estimate

- Enabling capability: **2-3 minutes**
- Regenerating profiles: **3-5 minutes**
- Xcode configuration: **2-3 minutes**
- **Total: 10-15 minutes**

---

## 🎯 Success Criteria

You've successfully completed this guide when:
✅ Apple Developer Portal shows "Sign in with Apple" enabled for your app ID
✅ Both provisioning profiles regenerated and installed
✅ Xcode shows the capability without any errors
✅ No red/orange warnings in Xcode's Signing & Capabilities tab

**Next Step:** Proceed to testing on a real iPad device (see PRE_SUBMISSION_CHECKLIST.md)

---

## 📝 Notes

- Changes in Apple Developer Portal are immediate
- Provisioning profiles are device-specific (Development) or universal (Distribution)
- You can regenerate profiles as many times as needed
- This process is non-destructive to your app or existing functionality
- Sign in with Apple only works on iOS 13+ devices

---

**Last Updated:** February 18, 2026
**For App:** Flip (com.ancientplus.flip)
**Issue:** App Store rejection - Sign in with Apple not working on iPad
