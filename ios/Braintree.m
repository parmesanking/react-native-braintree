
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

RCT_EXTERN_METHOD(showDropIn:
                  (NSString)clientToken
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject
                  )

@end

