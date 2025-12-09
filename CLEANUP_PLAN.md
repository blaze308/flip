# 🧹 FLIP APP CLEANUP PLAN

## 📋 **ISSUES IDENTIFIED**

### **1. Duplicate Files** (2 files)
- ❌ `flip/lib/screens/wallet_screen.dart` - OLD, has 48 errors
- ✅ `flip/lib/screens/wallet_screen_riverpod.dart` - NEW, Riverpod version (keep)
- ❌ `flip/lib/widgets/purchase_dialog.dart` - OLD, has 14 errors
- ✅ `flip/lib/widgets/purchase_dialog_v2.dart` - NEW version (keep)

### **2. Broken Files** (4 files with errors)
- ❌ `flip/lib/services/payment_service.dart` - 26 errors (PaymentMethod enum issue)
- ❌ `flip/lib/screens/guardian_purchase_screen.dart` - 1 error
- ❌ `flip/lib/services/ancient_coin_service.dart` - 7 errors (const map issue)
- ❌ `flip/lib/services/profile_service.dart` - 1 error

### **3. Files with Warnings** (6 files)
- ⚠️ `flip/lib/home_screen.dart` - 2 warnings (unused imports/methods)
- ⚠️ `flip/lib/providers/profile_providers.dart` - 6 warnings + errors
- ⚠️ `flip/lib/screens/agora_*_screen.dart` - unused fields
- ⚠️ `flip/lib/screens/chat_screen.dart` - unused methods

---

## 🎯 **CLEANUP ACTIONS**

### **Phase 1: Delete Duplicate/Old Files** ✅
1. Delete `flip/lib/screens/wallet_screen.dart` (use wallet_screen_riverpod.dart)
2. Delete `flip/lib/widgets/purchase_dialog.dart` (use purchase_dialog_v2.dart)

### **Phase 2: Fix Critical Errors** ✅
1. Fix `payment_service.dart` - Move PaymentMethod enum outside class
2. Fix `guardian_purchase_screen.dart` - Add missing _searchResults field
3. Fix `ancient_coin_service.dart` - Remove const from map with double keys
4. Fix `profile_service.dart` - Remove updateCachedUser call
5. Fix `profile_providers.dart` - Fix WalletService method calls
6. Fix `wallet_screen_riverpod.dart` - Add missing TransactionModel getters

### **Phase 3: Clean Warnings** ✅
1. Remove unused imports in `home_screen.dart`
2. Remove unused fields in Agora screens
3. Remove unused methods in `chat_screen.dart`
4. Remove unused fields in `wallet_screen_riverpod.dart`

### **Phase 4: Rename Files** ✅
1. Rename `wallet_screen_riverpod.dart` → `wallet_screen.dart`

---

## 📊 **EXPECTED RESULTS**

**Before Cleanup:**
- Total Errors: 109
- Files with Errors: 13
- Duplicate Files: 4

**After Cleanup:**
- Total Errors: 0 ✅
- Files with Errors: 0 ✅
- Duplicate Files: 0 ✅

---

## 🚀 **EXECUTION ORDER**

1. ✅ Delete old wallet_screen.dart
2. ✅ Delete old purchase_dialog.dart
3. ✅ Fix payment_service.dart
4. ✅ Fix guardian_purchase_screen.dart
5. ✅ Fix ancient_coin_service.dart
6. ✅ Fix profile_service.dart
7. ✅ Fix profile_providers.dart
8. ✅ Fix wallet_screen_riverpod.dart
9. ✅ Clean warnings in all files
10. ✅ Rename wallet_screen_riverpod.dart
11. ✅ Verify no errors remain

---

**Status**: Ready to execute
**Estimated Time**: 15 minutes

