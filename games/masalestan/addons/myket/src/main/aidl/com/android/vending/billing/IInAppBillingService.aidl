// Minimal declaration of the v3 in-app billing service interface.
//
// Provenance: authored for this project from the publicly documented method signatures of the
// v3 billing interface, which Myket's own developer documentation instructs integrators to bind
// against. The package and interface name are fixed by the interface DESCRIPTOR the store's
// service expects ("com.android.vending.billing.IInAppBillingService") — an interoperability
// requirement, not a design choice. Only the methods this game actually calls are declared.
package com.android.vending.billing;

import android.os.Bundle;

interface IInAppBillingService {
    /** 0 when in-app billing of the given type ("inapp") is available. */
    int isBillingSupported(int apiVersion, String packageName, String type);

    /** Details (price, title, description) for the SKUs listed in skusBundle. */
    Bundle getSkuDetails(int apiVersion, String packageName, String type, in Bundle skusBundle);

    /** A PendingIntent that starts the store's purchase flow for one SKU. */
    Bundle getBuyIntent(int apiVersion, String packageName, String sku, String type,
            String developerPayload);

    /** Purchases the user already owns and has not consumed. */
    Bundle getPurchases(int apiVersion, String packageName, String type, String continuationToken);

    /** Consumes a purchase so the same SKU can be bought again. Returns 0 on success. */
    int consumePurchase(int apiVersion, String packageName, String purchaseToken);
}
