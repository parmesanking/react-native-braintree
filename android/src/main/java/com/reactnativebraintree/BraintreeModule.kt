package com.reactnativebraintree

import android.app.Activity
import android.content.Context
import android.content.Intent
import androidx.fragment.app.FragmentActivity
import com.braintreepayments.api.BraintreeClient
import com.braintreepayments.api.BraintreeRequestCodes
import com.braintreepayments.api.BrowserSwitchResult
import com.braintreepayments.api.Card
import com.braintreepayments.api.CardClient
import com.braintreepayments.api.DataCollector
import com.braintreepayments.api.DataCollectorRequest
import com.braintreepayments.api.PayPalAccountNonce
import com.braintreepayments.api.PayPalCheckoutRequest
import com.braintreepayments.api.PayPalClient
import com.braintreepayments.api.PayPalListener
import com.braintreepayments.api.PayPalPaymentIntent
import com.braintreepayments.api.PayPalVaultRequest
import com.braintreepayments.api.UserCanceledException
import com.braintreepayments.api.VenmoAccountNonce
import com.braintreepayments.api.VenmoClient
import com.braintreepayments.api.VenmoPaymentMethodUsage
import com.braintreepayments.api.VenmoRequest
import com.braintreepayments.api.VenmoTokenizeAccountCallback
import com.facebook.react.bridge.ActivityEventListener
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.LifecycleEventListener
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.WritableMap


class BraintreeModule(reactContext: ReactApplicationContext) :
  ReactContextBaseJavaModule(reactContext), PayPalListener, ActivityEventListener, LifecycleEventListener {

  val appContext: Context = reactContext.applicationContext

  private var paypalPromise: Promise? = null
  private var venmoPromise: Promise? = null
  private var venmoClient: VenmoClient? = null
  private var apiClient: BraintreeClient? = null

  init {
    reactContext.addLifecycleEventListener(this)
    reactContext.addActivityEventListener(this)
  }


  override fun getName(): String {
    return "BrainTreeDropIn"
  }




  override fun onActivityResult(
    activity: Activity?,
    requestCode: Int,
    resultCode: Int,
    intent: Intent?
  ) {
    when (requestCode) {
      BraintreeRequestCodes.VENMO -> venmoClient.let {
        venmoClient?.onActivityResult(
          appContext,
          resultCode,
          intent,
          ::onVenmoResult
        )
      }
    }
  }


  override fun onNewIntent(intent: Intent?) {
    currentActivity.let {
      currentActivity?.setIntent(intent)
    }
  }

  override fun onHostResume() {
    currentActivity.let {
       val browserSwitchResult: BrowserSwitchResult? =
         apiClient?.deliverBrowserSwitchResult(currentActivity as FragmentActivity)
      if (browserSwitchResult != null) {
        when (browserSwitchResult.requestCode) {

          BraintreeRequestCodes.VENMO ->venmoClient.let {
            venmoClient?.onBrowserSwitchResult(
              browserSwitchResult,
              ::onVenmoResult
            )
          }
        }
      }
    }
  }

  private fun onVenmoResult (venmoAccountNonce: VenmoAccountNonce?, error: Exception?) {
    venmoAccountNonce?.let {
      try {
        var data: WritableMap = Arguments.createMap()
        data.putString("nonce", venmoAccountNonce.string)
        data.putString("firstName", venmoAccountNonce.firstName)
        data.putString("lastName", venmoAccountNonce.lastName)
        data.putString("payerID", venmoAccountNonce.username)
        data.putString("email", venmoAccountNonce.email)

        venmoPromise?.resolve(data)
      } catch (e: Error) {
        venmoPromise?.reject("Fetch_venmo_token_error", "Error tokenizing venmo account", e)
      }
    } ?: error?.let {
      if (error is UserCanceledException) {
        venmoPromise?.reject("Venmo user canceled", "Venmo user canceled", null)
      } else {
        venmoPromise?.reject(error)
      }

    } ?: run {
      venmoPromise?.reject("Fetch_venmo_token_error", "Error tokenizing venmo account")
    }

  }

  override fun onHostPause() {
  }

  override fun onHostDestroy() {
  }



  // Example method
  // See https://reactnative.dev/docs/native-modules-android
  @ReactMethod
  fun fetchCardNonce(
    clientToken: String,
    number: String?,
    expirationMonth: String?,
    expirationYear: String?,
    cvv: String,
    name: String?,
    promise: Promise
  ) {

    try {
      var apiClient: BraintreeClient = BraintreeClient(appContext, clientToken)
      if (apiClient == null) {
        throw Error("unable to instanciate apiClient")
      }

      var cardClient: CardClient = CardClient(apiClient)
      var card = Card()
      card.number = number
      card.cvv = cvv
      card.expirationMonth = expirationMonth
      card.number = number
      card.expirationYear = expirationYear
      card.cardholderName = name


      cardClient.tokenize(card) { cardNonce, error ->
        cardNonce?.let {

          var data: WritableMap = Arguments.createMap()
          data.putString("nonce", cardNonce.string)

          promise.resolve(data)
        } ?: run {
          promise.reject("Fetch card token error", "Error tokenizing credit card", error)
        }
      }

    } catch (e: Error) {
      promise.reject(e)
    }

  }

  @ReactMethod
  fun fetchPayPalNonce(clientToken: String, ticketPrice: String, promise: Promise) {

    try {
      var apiClient: BraintreeClient = BraintreeClient(appContext, clientToken)
      if (apiClient == null) {
        throw Error("unable to instanciate apiClient")
      }

      paypalPromise = promise

      currentActivity?.runOnUiThread {
        var payPalClient: PayPalClient =
          PayPalClient(currentActivity as FragmentActivity, apiClient)
        payPalClient.setListener(this)
        var request: PayPalCheckoutRequest = PayPalCheckoutRequest(ticketPrice)
        request.currencyCode = "USD"
        request.intent = PayPalPaymentIntent.AUTHORIZE

        payPalClient.tokenizePayPalAccount(currentActivity as FragmentActivity, request)
      }


    } catch (e: Error) {
      promise.reject(e)
    }

  }

  override fun onPayPalSuccess(payPalAccountNonce: PayPalAccountNonce) {
    payPalAccountNonce?.let {

      try {
        var data: WritableMap = Arguments.createMap()
        data.putString("nonce", payPalAccountNonce.string)
        data.putString("firstName", payPalAccountNonce.firstName)
        data.putString("lastName", payPalAccountNonce.lastName)
        data.putString("clientMetadataID", payPalAccountNonce.clientMetadataId)
        data.putString("payerID", payPalAccountNonce.payerId)
        data.putString("email", payPalAccountNonce.email)
        payPalAccountNonce.isDefault?.let {
          data.putString("isDefault", payPalAccountNonce.isDefault.toString())
        }

        payPalAccountNonce.billingAddress?.let {
          if (payPalAccountNonce.billingAddress.streetAddress != null) {
            var address: WritableMap = Arguments.createMap()
            address.putString("recipientName", payPalAccountNonce.billingAddress.recipientName)
            address.putString("streetAddress", payPalAccountNonce.billingAddress.streetAddress)
            address.putString("extendedAddress", payPalAccountNonce.billingAddress.extendedAddress)
            address.putString("locality", payPalAccountNonce.billingAddress.locality)
            address.putString("region", payPalAccountNonce.billingAddress.region)
            address.putString(
              "countryCodeAlpha2",
              payPalAccountNonce.billingAddress.countryCodeAlpha2
            )
            address.putString("postalCode", payPalAccountNonce.billingAddress.postalCode)
            data.putMap("billingAddress", address)
          }
        }

        payPalAccountNonce.shippingAddress?.let {
          if (payPalAccountNonce.shippingAddress.streetAddress != null) {
            var address: WritableMap = Arguments.createMap()
            address.putString("recipientName", payPalAccountNonce.shippingAddress.recipientName)
            address.putString("streetAddress", payPalAccountNonce.shippingAddress.streetAddress)
            address.putString("extendedAddress", payPalAccountNonce.shippingAddress.extendedAddress)
            address.putString("locality", payPalAccountNonce.shippingAddress.locality)
            address.putString(
              "countryCodeAlpha2",
              payPalAccountNonce.shippingAddress.countryCodeAlpha2
            )
            address.putString("postalCode", payPalAccountNonce.shippingAddress.postalCode)
            data.putMap("shippingAddress", address)
          }
        }
        paypalPromise?.resolve(data)
      } catch (e: Error) {
        paypalPromise?.reject("Fetch_paypal_token_error", "Error tokenizing paypal card", e)
      }
    } ?: run {
      paypalPromise?.reject("Fetch_paypal_token_error", "Error tokenizing paypal card")
    }
  }

  override fun onPayPalFailure(error: Exception) {
    if (error is UserCanceledException) {
      // user
      paypalPromise?.reject("PayPal user canceled","PayPal user canceled", null)
    }else {
      paypalPromise?.reject(error)
    }
  }

  @ReactMethod
  fun startPayPalCheckout (clientToken: String, agreementDescription: String?, promise:Promise){
    try {
      var apiClient: BraintreeClient = BraintreeClient(appContext, clientToken)
      if (apiClient == null) {
        throw Error("unable to instanciate apiClient")
      }

      val request = PayPalVaultRequest()
      agreementDescription?.let{
        request.billingAgreementDescription =agreementDescription
      }
      paypalPromise = promise

      currentActivity?.runOnUiThread {
        val payPalClient: PayPalClient =
          PayPalClient(currentActivity as FragmentActivity, apiClient)
        payPalClient.setListener(this)

        payPalClient.tokenizePayPalAccount(currentActivity as FragmentActivity, request)
      }

    } catch (e: Error) {
      promise.reject(e)
    }

  }

  @ReactMethod
  fun startVenmoCheckout (clientToken: String, promise:Promise){
    try {

      apiClient = BraintreeClient(appContext, clientToken)
      if (apiClient == null) {
        throw Error("unable to instanciate apiClient")
      }


      val request = VenmoRequest(VenmoPaymentMethodUsage.MULTI_USE)
      //request.profileId = "your-profile-id"
      request.shouldVault = true
      request.fallbackToWeb = true

      venmoPromise = promise

      currentActivity?.runOnUiThread {

        venmoClient = VenmoClient( apiClient!!)

        venmoClient?.tokenizeVenmoAccount((currentActivity as FragmentActivity), request,
          VenmoTokenizeAccountCallback { error: java.lang.Exception? ->
            error?.let{
              promise.reject(error)
            }
          })



      }

    } catch (e: Error) {
      promise.reject(e)
    }

  }


  @ReactMethod
  fun collectDeviceData(clientToken: String,
                        sandbox:Boolean,
                        promise: Promise){

    try {
      val apiClient: BraintreeClient = BraintreeClient(appContext, clientToken)
      val dataCollector = DataCollector(apiClient)

      val dataCollectorRequest = DataCollectorRequest(true)
      dataCollector.collectDeviceData(appContext, dataCollectorRequest) { deviceData, error ->
        // send deviceData to your server to be included in verification or transaction requests
        deviceData?.let {

          promise.resolve(deviceData)
        } ?: run {
          promise.reject("Collect data error", "Error collecting device data", error)
        }
      }

    }catch(e:Error){
      promise.reject(e)
    }


  }


}
