# Archie — App Store Listing Checklist for Danny

The build has been uploaded to App Store Connect. Everything below needs to be filled in before you can click "Submit for Review."

---

## 1. App Information

| Field | Notes |
|-------|-------|
| **App Name** | How it appears on the App Store (e.g. "Archie" or "Archie - Product Safety Scanner") |
| **Subtitle** | Max 30 characters. Short tagline (e.g. "Product Safety Scanner") |
| **Primary Category** | Suggested: Utilities or Health & Fitness |
| **Secondary Category** | Optional |

## 2. Version Information (for v1.0)

| Field | Notes |
|-------|-------|
| **Description** | Up to 4,000 characters. What the app does, key features, value proposition |
| **Keywords** | Up to 100 characters, comma-separated. e.g. "product safety,baby safe,pet safe,ingredient scanner" |
| **What's New** | Can be simple for v1.0: "Initial release" |
| **Promotional Text** | Optional, 170 chars. Can be changed without a new build |

## 3. Screenshots (required)

Minimum two device sizes:

| Size | Resolution | Device |
|------|-----------|--------|
| **6.7" iPhone** (required) | 1290 x 2796 | iPhone 15/16 Pro Max |
| **5.5" iPhone** (required) | 1242 x 2208 | iPhone 8 Plus |

- 3-10 screenshots per size
- Suggested screens to capture:
  1. Main scan screen (the camera/gallery view)
  2. Camera scanning a product
  3. Safety analysis results
  4. Scan history
  5. Account/settings

## 4. Pricing & Availability

| Field | Notes |
|-------|-------|
| **Price** | Free (subscriptions are in-app) |
| **Availability** | Select which countries/regions |

## 5. In-App Purchases / Subscriptions

These must be created in App Store Connect under **Monetization > Subscriptions**:

| Subscription | Product ID | Price | Duration |
|-------------|-----------|-------|----------|
| Archie Premium Monthly | `com.VariFax.Archie.monthly` | $9.99 | 1 Month |
| Archie Premium Yearly | `com.VariFax.Archie.yearly` | $99.99 | 1 Year |

**Subscription Group Name:** Archie Premium

Each subscription needs:
- Display name and description
- A screenshot showing the purchase UI in the app
- Review notes explaining what the subscription unlocks

**Important:** If these products are not already created in App Store Connect, they must be set up before submission. The product IDs above must match exactly — they're what the app code references via RevenueCat.

## 6. URLs

| Field | URL | Action needed |
|-------|-----|---------------|
| **Privacy Policy** | `https://archieml.com/privacy` | Verify this page is live and accessible |
| **Support URL** | `https://archieml.com` (or dedicated support page) | Must be a working link |
| **Marketing URL** | Optional | Landing page if available |

## 7. App Review Information

| Field | Suggestion |
|-------|-----------|
| **Contact Name** | Your name or team contact |
| **Contact Phone** | Phone number Apple can reach during review |
| **Contact Email** | Email for review communication |
| **Sign-in required** | Yes |
| **Demo account** | Not needed — reviewer can use Sign in with Apple |
| **Notes for reviewer** | See suggested text below |

### Suggested Review Notes

> Archie scans consumer products for safety analysis (child safety, pet safety) using the device camera or photo library.
>
> **How to test:**
> 1. Open the app — you'll see the scan screen
> 2. Tap Camera or Gallery — you'll be prompted to redeem a code or subscribe
> 3. Sign in with Apple to access History and Account
> 4. Use a sandbox purchase (Monthly or Yearly) to unlock premium access
> 5. Once premium, scan a product by taking a photo or selecting from gallery
>
> The app requires a network connection to perform safety analysis.
>
> If you need an offer code for testing, please contact us at support@archieml.com.

## 8. Age Rating

Fill out the age rating questionnaire in App Store Connect. For Archie, the likely answers are:
- No violence, gambling, horror, etc.
- Unrestricted web access: No
- Expected result: 4+ rating

## 9. Content Rights

Confirm that you own or have rights to all content in the app.

---

## After Approval: Transfer to Signature Labs

Once the app is live, initiate the transfer:

1. In App Store Connect: go to the app > **App Information** > **Transfer App**
2. Both teams must agree in App Store Connect
3. After transfer completes:
   - Generate a new .p8 key from the Signature Labs developer account
   - Update the shared secret + .p8 key in the RevenueCat dashboard
   - Verify S2S notification URL is still configured
   - Test a purchase/restore to confirm everything reconnected
4. Stripe is completely unaffected
