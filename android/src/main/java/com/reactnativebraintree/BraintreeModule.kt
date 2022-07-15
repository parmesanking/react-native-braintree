package com.reactnativebraintree

import android.content.Context
import androidx.fragment.app.FragmentActivity
import com.braintreepayments.api.*
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.WritableMap
import com.facebook.react.bridge.Arguments
import java.lang.Exception

class BraintreeModule(reactContext: ReactApplicationContext) :
  ReactContextBaseJavaModule(reactContext), PayPalListener {

  val appContext: Context = reactContext.applicationContext
  private var paypalPromise: Promise? = null


  override fun getName(): String {
    return "BrainTreeDropIn"
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
    paypalPromise?.reject( error)
  }
}
