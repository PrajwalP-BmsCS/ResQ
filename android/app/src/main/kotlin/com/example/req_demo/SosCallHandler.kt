package com.example.req_demo

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import android.telecom.PhoneAccountHandle
import android.telecom.TelecomManager
import android.telephony.SmsManager
import android.telephony.SubscriptionManager
import android.util.Log
import androidx.core.app.ActivityCompat

class SosCallHandler(private val context: Context) {

    /**
     * Make a call using the preferred SIM subscription ID.
     * @param phone Phone number to call.
     * @param preferredSubscriptionId If null, uses the first active SIM.
     */
    fun callWithSim(phone: String, preferredSubscriptionId: Int? = null) {
        try {
            val subscriptionManager = SubscriptionManager.from(context)
            val activeList = subscriptionManager.activeSubscriptionInfoList

            

            if (activeList.isNullOrEmpty()) {
                Log.e("SosCallHandler", "No active SIMs available")
                return
            }

            // Log active SIMs for debugging
            activeList.forEachIndexed { index, sim ->
                Log.d(
                    "SosCallHandler",
                    "Active SIM Index: $index, Carrier: ${sim.carrierName}, subId: ${sim.subscriptionId}"
                )
            }

            // Find the subscription info for the preferred ID
            val preferredSubInfo = activeList.firstOrNull { it.subscriptionId == preferredSubscriptionId }
            val subscriptionId = preferredSubInfo?.subscriptionId ?: activeList[0].subscriptionId
            
            Log.d("SosCallHandler", "Using subscriptionId: $subscriptionId")

            val telecomManager = context.getSystemService(Context.TELECOM_SERVICE) as TelecomManager
            val phoneAccountHandle = getPhoneAccountHandleForSubId(telecomManager, subscriptionId)

            if (phoneAccountHandle != null) {
                // Check CALL_PHONE permission
                if (ActivityCompat.checkSelfPermission(
                        context,
                        Manifest.permission.CALL_PHONE
                    ) != PackageManager.PERMISSION_GRANTED
                ) {
                    Log.e("SosCallHandler", "CALL_PHONE permission not granted")
                    return
                }

                // Use TelecomManager to place the call directly. This is a non-interactive way
                // that may bypass the SIM selection dialog on some devices and Android versions.
                val extras = Bundle()
                extras.putParcelable(TelecomManager.EXTRA_PHONE_ACCOUNT_HANDLE, phoneAccountHandle)
                
                // ACTION_CALL is used here with the EXTRA_PHONE_ACCOUNT_HANDLE to specify the SIM.
                // This is still a best-effort approach and not guaranteed to work on all devices.
                val intent = Intent(Intent.ACTION_CALL)
                intent.data = Uri.parse("tel:$phone")
                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                intent.putExtras(extras)
                context.startActivity(intent)

            } else {
                Log.e("SosCallHandler", "Could not find PhoneAccountHandle for subscriptionId: $subscriptionId")
                // Fallback to the standard call intent if the specific SIM method fails
                val intent = Intent(Intent.ACTION_CALL)
                intent.data = Uri.parse("tel:$phone")
                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                context.startActivity(intent)
            }

        } catch (e: SecurityException) {
            Log.e("SosCallHandler", "Permission denied to make calls: ${e.message}")
        } catch (e: Exception) {
            Log.e("SosCallHandler", "Error in callWithSim: ${e.message}")
        }
    }
    
    /**
     * Helper function to get the PhoneAccountHandle for a given subscription ID.
     * This function has been corrected to use the proper method for matching
     * a PhoneAccountHandle to a subscription ID.
     */
    private fun getPhoneAccountHandleForSubId(telecomManager: TelecomManager, subId: Int): PhoneAccountHandle? {
        if (ActivityCompat.checkSelfPermission(
                context,
                Manifest.permission.READ_PHONE_STATE
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            Log.e("SosCallHandler", "READ_PHONE_STATE permission not granted")
            return null
        }

        // The TelecomManager's callCapablePhoneAccounts list is the primary source of truth.
        // We iterate through them to find one that matches our desired subscription ID.
        for (phoneAccountHandle in telecomManager.callCapablePhoneAccounts) {
            val phoneAccount = telecomManager.getPhoneAccount(phoneAccountHandle)
            if (phoneAccount != null) {
                // The `extras` bundle of a PhoneAccount contains the `subscription_id` key.
                val accountSubId = phoneAccount.extras?.getInt("subscription_id")
                if (accountSubId != null && accountSubId == subId) {
                    Log.d("SosCallHandler", "Found matching PhoneAccount for subId: $subId")
                    return phoneAccountHandle
                }
            }
        }
        return null
    }
}
