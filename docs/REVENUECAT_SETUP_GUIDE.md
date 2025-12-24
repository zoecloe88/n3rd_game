# RevenueCat Setup Guide for N3RD Game

## Overview
This guide walks you through setting up RevenueCat subscriptions for the N3RD Game app. Follow these steps in order to enable monetization.

---

## Part 1: Store Configuration

### Option A: Test Store (For Development/Testing)

1. **In RevenueCat Dashboard:**
   - Navigate to "Apps & providers" page
   - You'll see the Test Store with API key: `test_nKjKZdchUSWxK0WrEWopRtYXgyK`
   - **Copy this test key** if you want to use it for testing
   - The Test Store allows you to test subscriptions without connecting real app stores

2. **Update launch.json (optional for testing):**
   - Replace `REVENUECAT_API_KEY` in `.vscode/launch.json` with the test key
   - Or keep using production key: `sk_dkIMaGJLgRDTNPq0aHJtDAINRbvWk`

### Option B: Real Store Setup (For Production)

1. **Click "New app configuration"** button
   - This opens a setup wizard

2. **For iOS (Apple App Store):**
   - Connect your App Store Connect account
   - Authorize RevenueCat to access your apps
   - Select your app: `com.clairsaint.wordn3rd`

3. **For Android (Google Play):**
   - Connect your Google Play Console account
   - Authorize RevenueCat
   - Select your app: `com.clairsaint.wordn3rd`

---

## Part 2: Configure Entitlements

**Location:** Project Settings → Entitlements (or Product catalog → Entitlements)

### Step 1: Create "basic" Entitlement

1. Click **"+ New entitlement"** or **"Create entitlement"**
2. Enter the following:
   - **Identifier:** `basic` (must be exactly this - case-sensitive)
   - **Display Name:** `Basic Tier`
   - **Description:** `Basic subscription with access to all game modes (excluding premium features)`
3. Click **"Create"** or **"Save"**

### Step 2: Create "premium" Entitlement

1. Click **"+ New entitlement"**
2. Enter the following:
   - **Identifier:** `premium` (must be exactly this - case-sensitive)
   - **Display Name:** `Premium Tier`
   - **Description:** `Premium subscription with access to all features including AI Mode, Practice, and Learning modes`
3. Click **"Create"** or **"Save"**

### Step 3: Create "family_friends" Entitlement

1. Click **"+ New entitlement"**
2. Enter the following:
   - **Identifier:** `family_friends` (must be exactly this - case-sensitive)
   - **Display Name:** `Family & Friends Tier`
   - **Description:** `Family subscription for up to 4 members with premium access`
3. Click **"Create"** or **"Save"**

---

## Part 3: Configure Products

**Location:** Product catalog → Products

### Step 1: Create "basic_tier" Product

1. Click **"+ New product"** or **"Add product"**
2. Enter the following:
   - **Product ID:** `basic_tier` (must be exactly this - case-sensitive)
   - **Display Name:** `Basic Tier`
   - **Description:** `$4.99/month subscription with 7-day free trial`
   - **Type:** Subscription
   - **Price:** $4.99 USD/month (or your target currency)
   - **Free Trial:** 7 days
3. **Link to Entitlement:**
   - Find the "Entitlement" or "Attach entitlement" field
   - Select: `basic` (the entitlement you created)
4. Click **"Save"** or **"Create"**

### Step 2: Create "premium_monthly" Product

1. Click **"+ New product"**
2. Enter the following:
   - **Product ID:** `premium_monthly` (must be exactly this - case-sensitive)
   - **Display Name:** `Premium Monthly`
   - **Description:** `$9.99/month premium subscription`
   - **Type:** Subscription
   - **Price:** $9.99 USD/month
   - **Free Trial:** None (or your preference)
3. **Link to Entitlement:**
   - Select: `premium`
4. Click **"Save"**

### Step 3: Create "family_friends_monthly" Product

1. Click **"+ New product"**
2. Enter the following:
   - **Product ID:** `family_friends_monthly` (must be exactly this - case-sensitive)
   - **Display Name:** `Family & Friends Monthly`
   - **Description:** `$19.99/month subscription for up to 4 family members`
   - **Type:** Subscription
   - **Price:** $19.99 USD/month
   - **Free Trial:** None (or your preference)
3. **Link to Entitlement:**
   - Select: `family_friends`
4. Click **"Save"**

---

## Part 4: Link Products to App Stores

### For iOS (Apple App Store Connect)

1. **In App Store Connect:**
   - Go to your app: `com.clairsaint.wordn3rd`
   - Navigate to **Subscriptions**
   - Create subscription groups if needed
   - Create subscription products matching your RevenueCat product IDs:
     - `basic_tier` → $4.99/month with 7-day free trial
     - `premium_monthly` → $9.99/month
     - `family_friends_monthly` → $19.99/month

2. **Back in RevenueCat:**
   - Go to Product catalog
   - For each product, click **"Link to store"** or **"Configure store"**
   - Select the corresponding App Store Connect product
   - RevenueCat will sync the products

### For Android (Google Play Console)

1. **In Google Play Console:**
   - Go to your app: `com.clairsaint.wordn3rd`
   - Navigate to **Monetize → Products → Subscriptions**
   - Create subscription products matching your RevenueCat product IDs:
     - `basic_tier` → $4.99/month with 7-day free trial
     - `premium_monthly` → $9.99/month
     - `family_friends_monthly` → $19.99/month

2. **Back in RevenueCat:**
   - Go to Product catalog
   - For each product, click **"Link to store"** or **"Configure store"**
   - Select the corresponding Google Play product
   - RevenueCat will sync the products

---

## Part 5: Create Offerings (Optional but Recommended)

**Location:** Product catalog → Offerings

1. Click **"+ New offering"** or **"Create offering"**
2. Name it: `default` (or `main`)
3. Add all three products to this offering:
   - `basic_tier`
   - `premium_monthly`
   - `family_friends_monthly`
4. Set this as the **current offering** (RevenueCat uses this by default)

---

## Part 6: Verification Checklist

After completing all steps, verify:

- [ ] All 3 entitlements created: `basic`, `premium`, `family_friends`
- [ ] All 3 products created: `basic_tier`, `premium_monthly`, `family_friends_monthly`
- [ ] Each product is linked to its corresponding entitlement
- [ ] Products are linked to App Store Connect (iOS) or Google Play Console (Android)
- [ ] API key is configured in `.vscode/launch.json`
- [ ] Test purchases work in sandbox/test environment

---

## Part 7: Testing

### Test with Test Store

1. Use the test API key: `test_nKjKZdchUSWxK0WrEWopRtYXgyK`
2. Update `.vscode/launch.json` to use test key (optional)
3. Run the app and try purchasing subscriptions
4. Check RevenueCat dashboard → Customers to see test purchases

### Test with Sandbox (iOS) / Test Track (Android)

1. Use production API key: `sk_dkIMaGJLgRDTNPq0aHJtDAINRbvWk`
2. Create sandbox/test accounts in App Store Connect / Google Play Console
3. Test purchases will appear in RevenueCat dashboard
4. Verify entitlements are granted correctly

---

## Troubleshooting

### Products Not Appearing in App

- **Check:** Product IDs match exactly (case-sensitive)
- **Check:** Products are linked to entitlements
- **Check:** Products are in the current offering
- **Check:** API key is correct in launch.json

### Entitlements Not Working

- **Check:** Entitlement identifiers match exactly: `basic`, `premium`, `family_friends`
- **Check:** Products are linked to correct entitlements
- **Check:** Subscription is active in RevenueCat dashboard → Customers

### Purchase Fails

- **Check:** Store connection is configured correctly
- **Check:** Products exist in App Store Connect / Google Play Console
- **Check:** Product IDs match between RevenueCat and stores
- **Check:** Using test accounts for sandbox testing

---

## Quick Reference

### Exact Values Required (Case-Sensitive)

**Entitlements:**
- `basic`
- `premium`
- `family_friends`

**Product IDs:**
- `basic_tier`
- `premium_monthly`
- `family_friends_monthly`

**Prices:**
- Basic: $4.99/month (7-day free trial)
- Premium: $9.99/month
- Family & Friends: $19.99/month

**API Keys:**
- Production: `sk_dkIMaGJLgRDTNPq0aHJtDAINRbvWk`
- Test: `test_nKjKZdchUSWxK0WrEWopRtYXgyK`

---

## Next Steps After Setup

1. Test purchases in development environment
2. Verify subscription status updates correctly in app
3. Test subscription renewal
4. Test subscription cancellation
5. Monitor RevenueCat dashboard for purchase events
6. Set up webhooks (optional) for server-side validation

---

## Support

- RevenueCat Docs: https://docs.revenuecat.com
- RevenueCat Dashboard: https://app.revenuecat.com
- Your Project: N3RD

**Last Updated:** Based on codebase configuration

