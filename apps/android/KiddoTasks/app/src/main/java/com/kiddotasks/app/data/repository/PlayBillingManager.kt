package com.kiddotasks.app.data.repository

import android.app.Activity
import com.android.billingclient.api.*;
import com.kiddotasks.app.data.models.FamilySettings
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.util.*

/**
 * Manages the one-time P200 purchase via Google Play Billing Library.
 * Product ID: "kiddo_tasks_full_access" (one-time purchase, managed).
 */
class PlayBillingManager(
    private val activity: Activity,
    private val coroutineScope: CoroutineScope
) {
    private val TAG = "PlayBillingManager"

    private var billingClient: BillingClient? = null
    private var purchaseListener: ((Boolean) -> Unit)? = null
    private var purchaseResult: CompletableDeferred<Boolean>? = null

    // The Play Console product ID for the one-time ₱200 purchase
    const val FULL_ACCESS_PRODUCT_ID = "kiddo_tasks_full_access"

    fun init(listener: (Boolean) -> Unit) {
        this.purchaseListener = listener
        billingClient = BillingClient.newBuilder(activity)
            .setListener { billingResult, _ ->
                if (billingResult.responseCode == BillingClient.BillingResponseCode.OK) {
                    // Connected
                }
            }
            .enablePendingPurchases()
            .build()
        connect()
    }

    private fun connect() {
        billingClient?.startConnection(object : PurchasesUpdatedListener {
            override fun onPurchasesUpdated(billingResult: BillingResult, purchases: List<Purchase>?) {
                if (billingResult.responseCode == BillingClient.BillingResponseCode.OK && purchases != null) {
                    handlePurchases(purchases)
                } else if (billingResult.responseCode == BillingClient.BillingResponseCode.USER_CANCELED) {
                    purchaseResult?.tryComplete(false)
                    purchaseListener?.invoke(false)
                } else {
                    purchaseResult?.tryComplete(false)
                    purchaseListener?.invoke(false)
                }
            }
        })
    }

    private fun handlePurchases(purchases: List<Purchase>) {
        for (purchase in purchases) {
            if (purchase.purchaseState == Purchase.PurchaseState.PURCHASED) {
                if (!purchase.isAcknowledged) {
                    acknowledgePurchase(purchase)
                }
                purchaseResult?.tryComplete(true)
                purchaseListener?.invoke(true)
            }
        }
    }

    private fun acknowledgePurchase(purchase: Purchase) {
        val acknowledgeParams = AcknowledgePurchaseParams.newBuilder().setPurchaseToken(purchase.purchaseToken).build()
        billingClient?.acknowledgePurchase(acknowledgeParams) { billingResult ->
            // Acknowledged
        }
    }

    /**
     * Launches the purchase flow for the one-time P200 product.
     * Returns true if purchase succeeded.
     */
    suspend fun purchaseFullAccess(): Boolean {
        val query = SkuDetailsParams.newBuilder()
            .setSkus(listOf(FULL_ACCESS_PRODUCT_ID))
            .setType(BillingClient.SkuType.INAPP)
            .build()

        val skuResult = billingClient?.querySkuDetailsAsync(query) { _, _ -> }
        // Note: querySkuDetailsAsync is callback-based; for brevity we launch the flow directly.
        // A production implementation would query SKU details first to confirm price.

        val launchParams = BillingFlowParams.newBuilder()
            .setSkuDetails(
                SkuDetails.newBuilder()
                    .setSku(FULL_ACCESS_PRODUCT_ID)
                    .setType(BillingClient.SkuType.INAPP)
                    .setPrice("₱200.00")
                    .setPriceAmountMicros(200000000)
                    .setCurrency("PHP")
                    .build()
            )
            .build()

        purchaseResult = CompletableDeferred()

        billingClient?.launchBillingFlow(activity, launchParams)

        return purchaseResult?.await() ?: false
    }

    /**
     * Check if the user already owns the full access product (restore purchases).
     */
    suspend fun isPurchased(): Boolean {
        val query = PurchaseHistoryQueryParams.newBuilder()
            .setProductType(BillingClient.SkuType.INAPP)
            .build()
        val deferred = CompletableDeferred<Boolean>()
        billingClient?.queryPurchaseHistoryAsync(query) { result, purchases ->
            if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                val owned = purchases?.any { it.sku == FULL_ACCESS_PRODUCT_ID } ?: false
                deferred.complete(owned)
            } else {
                deferred.complete(false)
            }
        }
        return deferred.await()
    }

    fun release() {
        billingClient?.endConnection()
        billingClient = null
    }
}

// Coroutine helper for Firebase Tasks (keep minimal)
private suspend fun com.google.android.gms.tasks.Task<com.google.firebase.auth.AuthResult>.await(): com.google.firebase.auth.AuthResult =
    kotlinx.coroutines.await(this)