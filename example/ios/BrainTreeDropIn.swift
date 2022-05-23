//
//  BrainTreeDropIn.swift
//  braintree_dropin
//
//  Created by Luca Agostini on 16/05/22.
//


import UIKit
import BraintreeDropIn
import Accelerate

@objc(BrainTreeDropIn)
class BrainTreeDropIn: NSObject {
  
  var reactRoot: UIViewController!
  
  override init() {
    //Get reference of root view controller
    let root:UIViewController = UIApplication.shared.keyWindow!.rootViewController!
    let maybeModal:UIViewController? = root.presentedViewController
    var modalRoot:UIViewController? = root
    
    if (maybeModal != nil) {
      modalRoot = maybeModal
    }
    
    reactRoot = modalRoot
    
    
    
  }
  
  //this component must be already instanced before any JS object rendered
  @objc
  static func requiresMainQueueSetup() -> Bool{
    return true
  }
  
  
  @objc
  func fetchCardNonce(_ clientToken: String,
                      number: String?,
                      expirationMonth: String?,
                      expirationYear: String?,
                      cvv: String?,
                      name: String?,
                      resolve: @escaping RCTPromiseResolveBlock,
                      reject: @escaping  RCTPromiseRejectBlock) {
    
         
          guard let apiClient = BTAPIClient(authorization: clientToken) else {
              let error = NSError(domain: "", code: 100, userInfo: nil)
              reject("Fetch card token error","Unable to create api client for credit card token", error)
              return
          }
          
          let client = BTCardClient(apiClient: apiClient)
          let card = BTCard()
          card.number = number
          card.expirationMonth = expirationMonth
          card.expirationYear = expirationYear
          card.cvv = cvv
          card.cardholderName = name
          
          client.tokenizeCard(card, completion: { (cardNonce, error) in
            
            DispatchQueue.main.async {
                if let nonce = cardNonce?.nonce {
                  
                  let data: [String: Any] = [
                    "nonce": nonce
                  ]
                  resolve(data)
                }else{
                  reject("Fetch card token error","Error tokenizing credit card", error)
                }
            }
           
          })
           
    
  }
  
  @objc
  func fetchPayPalNonce(_ clientToken: String,
                      ticketPrice: String,
                      resolve: @escaping RCTPromiseResolveBlock,
                      reject: @escaping  RCTPromiseRejectBlock) {
    
       guard let apiClient = BTAPIClient(authorization: clientToken) else {
              let error = NSError(domain: "", code: 100, userInfo: nil)
              reject("Fetch card token error","Unable to create api client for credit card token", error)
              return
          }
          
          let driver = BTPayPalDriver(apiClient: apiClient)
          let request = BTPayPalCheckoutRequest(amount: ticketPrice)
    
    
          driver.tokenizePayPalAccount(with: request, completion:  {  (tokenizedPayPalAccount, error) -> Void in
            
            DispatchQueue.main.async {
              if let nonce = tokenizedPayPalAccount?.nonce {
                  
                  let data: [String: Any] = [
                    "nonce": nonce
                  ]
                  resolve(data)
                } else{
                  reject("Fetch card token error","Error tokenizing PayPal account", error)
                }
            }
        })
          
           
    
  }
  
  
  @objc
  func showDropIn(_ clientToken: String,
                  resolve: @escaping RCTPromiseResolveBlock,
                  reject: @escaping  RCTPromiseRejectBlock) {
    
    DispatchQueue.main.async {
      var request =  BTDropInRequest()
      request.allowVaultCardOverride = true
      request.cardholderNameSetting = .optional
      request.shouldMaskSecurityCode = true
      request.vaultCard = true
      request.vaultManager = false
      request.applePayDisabled = true
      let dropIn = BTDropInController(authorization: clientToken, request: request)
      {  (controller, result, error) in
        if (error != nil) {
          print("ERROR")
          reject("ERROR","Error raised in BT drop-in flow", error)
        } else if (result?.isCanceled == true) {
          
          
          print("CANCELED")
          let error = NSError(domain: "", code: 100, userInfo: nil)
          reject("USER CANCELED","User canceled operation", error)
        } else if let result = result {
          // Use the BTDropInResult properties to update your UI
          // result.paymentMethodType
          // result.paymentMethod
          // result.paymentIcon
          // result.paymentDescription
          
          var data: [String: Any] = [
            "methodType": result.paymentMethodType.rawValue,
              "description": result.paymentDescription
          ]
         
          if (result.paymentMethod != nil){
            data["nonce"] = result.paymentMethod?.nonce
            data["isDefault"] = result.paymentMethod?.isDefault
            data["cardtype"] = result.paymentMethod?.type
          }
          
          
                  
          resolve(data)
          
        }
        controller.dismiss(animated: true, completion: nil)
      }
      
      self.reactRoot.present(dropIn!, animated: true, completion: nil)
    }
  }
}

