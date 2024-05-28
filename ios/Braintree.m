
#import <Foundation/Foundation.h>

#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(BrainTreeDropIn,NSObject)


RCT_EXTERN_METHOD(fetchCardNonce:
                  (NSString)clientToken
                  number:(NSString)number
                  expirationMonth:(NSString)expirationMonth
                  expirationYear:(NSString)expirationYear
                  cvv:(NSString)cvv
                  name:(NSString)name
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject
                  )


RCT_EXTERN_METHOD(fetchPayPalNonce:
                  (NSString)clientToken
                  ticketPrice:(NSString)ticketPrice
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject
                  )

RCT_EXTERN_METHOD(fetchApplePayNonce:
                  (NSDictionary)quote
                  settings:(NSDictionary)settings
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject
                  )

RCT_EXTERN_METHOD(completeApplePayment:
                  (BOOL)completed
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject
                  )

RCT_EXTERN_METHOD(showDropIn:
                  (NSString)clientToken
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject
                  )


RCT_EXTERN_METHOD(startPayPalCheckout:
                  (NSString)clientToken
                  agreementDescription:(NSString)agreementDescription
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject
                  )

RCT_EXTERN_METHOD(collectDeviceData:
                  (NSString)clientToken
                  (BOOL)sandbox
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject
                  )

@end

