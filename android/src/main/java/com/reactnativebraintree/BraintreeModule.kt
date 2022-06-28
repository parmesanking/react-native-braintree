package com.reactnativebraintree

import android.content.Context
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.Promise
import com.braintreepayments.api.BraintreeClient
import com.braintreepayments.api.CardClient
import com.braintreepayments.api.Card

class BraintreeModule(reactContext: ReactApplicationContext) : ReactContextBaseJavaModule(reactContext) {

    val appContext:Context = reactContext.applicationContext

  override fun getName(): String {
        return "BrainTreeDropIn"
    }

    // Example method
    // See https://reactnative.dev/docs/native-modules-android
    @ReactMethod
    fun fetchCardNonce(clientToken: String, number: String, expirationMonth: String, expirationYear: String, cvv: String, name: String, promise: Promise) {

      try {
        var  apiClient: BraintreeClient = BraintreeClient(appContext, clientToken)
        if(apiClient == null){
          throw Error("unable to instanciate apiClient")
        }

        var cardClient:CardClient = CardClient(apiClient)
        val card = Card()
        if (number != null && number != ""){
          card.number = number
          card.expirationMonth = number
          card.number = expirationMonth
          card.expirationYear = expirationYear
          card.cardholderName = name
        }
        card.cvv = cvv

        cardClient.tokenize(card){ cardNonce, error ->
          cardNonce?.let {

            var data: WritableMap = Arguments.createMap()
            data.putString("nonce", cardNonce.string )

            promise.resolve(data)
          } ?: run {
            promise.reject("Fetch card token error","Error tokenizing credit card", error)
          }
        }

      }catch(e:Error){
        promise.reject(e)
      }

  }


}
