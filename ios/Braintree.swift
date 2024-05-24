

import UIKit
import BraintreeDropIn
import Accelerate
import PassKit


@objc(BrainTreeDropIn)
class BrainTreeDropIn: NSObject, PKPaymentAuthorizationViewControllerDelegate {
    
    
    
    
    var reactRoot: UIViewController!
    
    //Apple-Pay settings
    private static let merchantCapabilities = PKMerchantCapability.capability3DS
    private static let countryCode = "US"
    private static let currencyCode = "USD"
    private static let paymentNetworks: [PKPaymentNetwork] = [.amex, .masterCard, .visa, .discover]
    
    
    private var accountId:String = ""
    private var clientToken:String = ""
    private var applePayAuthorized:Bool = false
    private var resolve:RCTPromiseResolveBlock!
    private var reject:RCTPromiseRejectBlock!
    private var paymentCompletedCallback:((PKPaymentAuthorizationStatus) ->Void)?
    
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
                    
                    var data: [String: Any] = [
                        "nonce": nonce,
                        "firstName":tokenizedPayPalAccount?.firstName ?? "",
                        "lastName":tokenizedPayPalAccount?.lastName ?? ""
                    ]
                    
                    if let billingAddress = tokenizedPayPalAccount?.billingAddress {
                        var dict:  [String: Any] = [:]
                        dict["recipientName"] = billingAddress.recipientName
                        dict["streetAddress"] = billingAddress.streetAddress
                        dict["extendedAddress"] = billingAddress.extendedAddress
                        dict["locality"] = billingAddress.locality
                        dict["countryCodeAlpha2"] = billingAddress.countryCodeAlpha2
                        dict["postalCode"] = billingAddress.postalCode
                        dict["region"] = billingAddress.region
                        data["billingAddress"] = dict
                    }
                    
                    if let shippingAddress = tokenizedPayPalAccount?.shippingAddress{
                        var dict:  [String: Any] = [:]
                        dict["recipientName"] = shippingAddress.recipientName
                        dict["streetAddress"] = shippingAddress.streetAddress
                        dict["extendedAddress"] = shippingAddress.extendedAddress
                        dict["locality"] = shippingAddress.locality
                        dict["countryCodeAlpha2"] = shippingAddress.countryCodeAlpha2
                        dict["postalCode"] = shippingAddress.postalCode
                        dict["region"] = shippingAddress.region
                        data["shippingAddress"] = dict
                    }
                    
                    resolve(data)
                } else{
                    let errDesc = (error as? NSError)?.userInfo["NSLocalizedDescription"] as? String
                    
                    reject("Fetch card token error", errDesc ?? "Unable to generate nonce for PayPal flow", error)
                }
            }
        })
        
        
        
    }
    
    @objc
    func fetchApplePayNonce(_ quote:NSDictionary,
                            settings: NSDictionary,
                            resolve: @escaping RCTPromiseResolveBlock,
                            reject: @escaping  RCTPromiseRejectBlock) {
        
        //let quantity = quote["quantity"]
        
        self.resolve=resolve
        self.reject=reject
        
        self.applePayAuthorized = false
        self.paymentCompletedCallback = nil
        
        
        let request = PKPaymentRequest()
        if let merchantIdentifier = settings["merchantIdentifier"] as? String{
            request.merchantIdentifier = merchantIdentifier
        } else{
            let error = NSError(domain: "", code: 100, userInfo: nil)
            reject("ApplePay error","Invalid merchantId provided in settings.merchantIdentifier", error)
            return
        }
        
        if let clientToken = settings["clientToken"] as? String{
            self.clientToken = clientToken
        } else{
            let error = NSError(domain: "", code: 100, userInfo: nil)
            reject("ApplePay error","Invalid clientToken provided in settings.clientToken", error)
            return
        }
        
        if let accountId = settings["accountId"] as? String{
            self.accountId = accountId
        } else{
            let error = NSError(domain: "", code: 100, userInfo: nil)
            reject("ApplePay error","Invalid accountId provided in settings.accountId", error)
            return
        }
        
        request.merchantCapabilities = BrainTreeDropIn.merchantCapabilities
        request.countryCode          = BrainTreeDropIn.countryCode
        request.currencyCode         = BrainTreeDropIn.currencyCode
        request.supportedNetworks    = BrainTreeDropIn.paymentNetworks
        
        //request.shippingMethods = getShippingMethods()
        
        var summaryItems: [PKPaymentSummaryItem] = []
        /*
         if shouldShowAppliedCredit {
         
         let appliedCreditAmount = NSDecimalNumber(value: totalAppliedCredit).roundedCurrency().negative()
         
         if showLoyaltyV2 {
         let storeCreditItem = PKPaymentSummaryItem(label: CheckoutStrings.rewardCreditLineItem.localized, amount: appliedCreditAmount)
         summaryItems.append(storeCreditItem)
         } else {
         let storeCreditItem = PKPaymentSummaryItem(label: CheckoutStrings.rewardsCashLineItem.localized, amount: appliedCreditAmount)
         summaryItems.append(storeCreditItem)
         }
         }
         
         if let discount = quote.promoDiscount {
         let discountSummaryItem = PKPaymentSummaryItem(label: promoPriceDetailsTitle, amount: discount.negative())
         summaryItems.append(discountSummaryItem)
         }
         
         for transaction in quote.giftCardTransactions {
         let giftCardItem = PKPaymentSummaryItem(label: String(format: CheckoutStrings.giftCardLineItem.localized, transaction.maskedCode), amount: transaction.amount.negative())
         summaryItems.append(giftCardItem)
         }
         
         let ticketLabel = ApplePayStrings.ticketItem.localized + (quantity > 1 ? "s" : "")
         let serviceChargeLabel = ApplePayStrings.serviceChargeItem.localized + (quantity > 1 ? "s" : "")
         let ticketSummaryItem = PKPaymentSummaryItem(label: "\(quantity) \(ticketLabel)", amount: quote.totalTicketPriceforQuantity)
         summaryItems.append(ticketSummaryItem)
         
         
         
         let serviceChargeAmount = quote.totalServiceChargeForQuantity
         let serviceChargeSummaryItem = PKPaymentSummaryItem(label: serviceChargeLabel, amount: serviceChargeAmount)
         summaryItems.append(serviceChargeSummaryItem)
         
         let shippingAmount = quote.deliveryMethod.cost
         let deliveryMethodPriceDetailsString = quote.deliveryMethod.methodForPriceDetailsDisplay(makeSubstitutions: quote.isAxsEnabled)
         let shippingSummaryItem = PKPaymentSummaryItem(label: deliveryMethodPriceDetailsString, amount: shippingAmount)
         summaryItems.append(shippingSummaryItem)
         
         if let salesTax = quote.salesTax?.amount {
         let salesTaxItem = PKPaymentSummaryItem(label: ApplePayStrings.salesTax.localized, amount: salesTax)
         summaryItems.append(salesTaxItem)
         }
         
         */
        
        let totalCharge: NSDecimalNumber = NSDecimalNumber(value: quote["totalCharge"] as! Double)
        
        
        let totalSummaryItem = PKPaymentSummaryItem(label: "Vivid Seats", amount: totalCharge)
        summaryItems.append(totalSummaryItem)
        
        //let contactFieldsNoEmail: Set<PKContactField> = [.name, .postalAddress, .phoneNumber]
        //let contactFieldsAll: Set<PKContactField> = [.emailAddress, .name, .postalAddress, .phoneNumber]
        
        request.paymentSummaryItems = summaryItems
        //request.requiredBillingContactFields = email != nil ? contactFieldsNoEmail : contactFieldsAll
        /*
         if quote.deliveryMethod.isShipping {
         request.requiredShippingContactFields = email != nil ? contactFieldsNoEmail : contactFieldsAll
         } else {
         request.requiredShippingContactFields = email != nil ? [.phoneNumber] : [.emailAddress, .phoneNumber]
         }
         */
        request.requiredShippingContactFields = [.name, .phoneNumber,.postalAddress]
        
        DispatchQueue.main.async {
            guard let viewController = PKPaymentAuthorizationViewController(paymentRequest: request) else {
                
                
                let error = NSError(domain: "", code: 100, userInfo: nil)
                reject("ApplePay error","Unable to start view controller", error)
                return
            }
            
            viewController.delegate = self
            
            if let rootVC = RCTPresentedViewController() {
                rootVC.present(viewController, animated: true)
            }
        }
        
        
    }
    
    
    
    func finalizeApplePayNonce(
        payment: PKPayment, handler: @escaping (_ nonce: String?, _ error: NSError?) -> Void) {
            
            
            
            guard let apiClient = BTAPIClient(authorization: self.clientToken) else {
                let error = NSError(domain: "", code: 100, userInfo: nil)
                self.reject("Fetch applePay error","Unable to create api client for applePay token", error)
                return
            }
            
            let client = BTApplePayClient(apiClient: apiClient)
            
            client.tokenizeApplePay(payment, completion: { [weak self] (applePayNonce, error) in
                guard let self = self else { return }
                
                
                DispatchQueue.main.async {
                    if let nonce = applePayNonce?.nonce {
                        handler(nonce, nil)
                    } else {
                        
                        let error = NSError(domain: "", code: 100, userInfo: nil)
                        handler(nil, error )
                    }
                }
            })
        }
    
    
    func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController, didAuthorizePayment payment: PKPayment,  completion: @escaping (PKPaymentAuthorizationStatus) -> Void) {
        
        finalizeApplePayNonce(payment: payment, handler: { [weak self] (nonce, error) in
            guard let self = self else { return }
            
            
            guard let nonce = nonce else {
                completion(PKPaymentAuthorizationStatus.failure)
                self.reject("ApplePay error","Token not generated",error)
                return
            }
            
            
            let data: [String: Any] = [
                "nonce": nonce
            ]
            self.paymentCompletedCallback = completion
            self.resolve(data)
            self.applePayAuthorized = true
            
            
            
        } )
    }
    
    
    @objc
    func completeApplePayment(_ completed:Bool,  resolve: @escaping RCTPromiseResolveBlock,
                              reject: @escaping  RCTPromiseRejectBlock) {
        
        guard let complete = self.paymentCompletedCallback else {
            reject("ApplePay error","Invalid status, unable to complete the payment",nil)
            return
        }
        
        
        if (completed){
            complete(PKPaymentAuthorizationStatus.success)
        }else{
            complete(PKPaymentAuthorizationStatus.failure)
        }
        resolve(true)
    }
    
    
    func paymentAuthorizationViewControllerDidFinish(_ controller: PKPaymentAuthorizationViewController) {
        controller.dismiss(animated: true)
        if (!self.applePayAuthorized){
            
            self.reject("APPLE_PAY_CANCELLED", "APPLE_PAY_USER_CANCELLED", nil)
        }
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

    @objc
    func startPayPalCheckout(_ clientToken: String,
                        agreementDescription: String,
                        completed:Bool,
                        resolve: @escaping RCTPromiseResolveBlock,
                             reject: @escaping  RCTPromiseRejectBlock) {
        
        
        guard let apiClient = BTAPIClient(authorization: clientToken) else {
            let error = NSError(domain: "", code: 100, userInfo: nil)
            reject("PayPal vault token error","Unable to create api client for PayPal checkout", error)
            return
        }
        
        let payPalDriver = BTPayPalDriver(apiClient: apiClient!)
        
        let request = BTPayPalVaultRequest()
        request.billingAgreementDescription = agreementDescription // Displayed in customer's PayPal account
        payPalDriver.tokenizePayPalAccount(with: request) { (tokenizedPayPalAccount, error) -> Void in
            DispatchQueue.main.async {
                if let tokenizedPayPalAccount = tokenizedPayPalAccount {
                    let data: [String: Any] = [
                        "nonce": tokenizedPayPalAccount.nonce
                    ]
                    resolve(data)
                }else if let error = error {
                    let errDesc = (error as? NSError)?.userInfo["NSLocalizedDescription"] as? String
                    
                    reject("PayPal error", errDesc ?? "Unable to generate nonce for PayPal flow", error)
                    
                } else {
                    reject("PayPal user canceled","PayPal user canceled", nil)
                }
            }
        }
        
    }
}

