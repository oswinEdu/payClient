#import "ViewController.h"
#import <StoreKit/StoreKit.h>

//iOS内购掉单问题： https://blog.bombox.org/2018-07-14/ios-iap/
static bool is_first = true;

@interface ViewController ()<SKProductsRequestDelegate,SKPaymentTransactionObserver>
    @property (retain, nonatomic) NSMutableArray *purchasableProducts;
@property (retain, nonatomic) NSString *receiptJson;
@end


@implementation ViewController


- (void) viewDidLoad {
    [super viewDidLoad];
    self.purchasableProducts = [[NSMutableArray alloc] init];
    
    // 1.设置购买的观察者，处理购买的
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    // 2.获取商品列表
    [self getProductInfo];
}


/*先通过该IAP的ProductID 向APP store查询，获得SKPayment实例，通过SKPaymentQueue 的addPayment方法发起一个购买的操作*/
- (void) getProductInfo {
    
    // 1.可以不获取商品的 SKProduct
    // 2.通过 SKPayment *payment = [SKPayment  paymentWithProductIdentifier:productIdentifier]; 获得商品SKPayment
    
    NSSet *set = [NSSet setWithArray:@[@"com.xianlai.funhenan.6", @"com.xianlai.funhenan.30", @"com.xianlai.funhenan.128"]];
    SKProductsRequest* request = [[SKProductsRequest alloc] initWithProductIdentifiers:set];
    request.delegate = self;
    [request start];
}

/*以上查询的回调函数*/
- (void) productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response{
    NSArray * myProduct = response.products;
    if (myProduct.count==0) {
        NSLog(@"失败：无法获取产品信息");
        return;
    }
    
    NSLog(@"成功：获取商品信息");
    [self.purchasableProducts addObjectsFromArray:response.products];
}



//用户点击了一个IAP项目，我们事先需要查询用户是否允许应用内购买，如果不允许则不用进行以下步骤了
#pragma mark==点击购买按钮
- (IBAction)pochaseAC:(UIButton *)sender {
    is_first = false;
//    if(true) {
//        [self sendToServer:self.receiptJson];
//        return;
//    }
    
    if ([SKPaymentQueue canMakePayments]) {
        SKProduct *product = [self.purchasableProducts objectAtIndex:1];
        
        //SKPayment *payment = [SKPayment paymentWithProduct:product];
        SKMutablePayment *payment = [SKMutablePayment paymentWithProduct:product];
        payment.applicationUsername = [product productIdentifier];
        payment.quantity = 10;
        
        // 1.设置 productIdentifier 支付失败
        //payment.productIdentifier = @"12324";
        // 2.设置 requestData 支付失败
        //NSData* xmlData = [@"testdata" dataUsingEncoding:NSUTF8StringEncoding];
        //payment.requestData = xmlData;
        
        [[SKPaymentQueue defaultQueue] addPayment:payment];
    }else{
        NSLog(@"失败，用户禁止应用内付费购买");
    }
    
}


#pragma mark处理观察者的回调
-(void) paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions {
    for (SKPaymentTransaction * transaction in transactions) {
        switch (transaction.transactionState) {
            case SKPaymentTransactionStatePurchased:
                [self transactionsSuccess:transaction];//交易成功
                break;
            case SKPaymentTransactionStateFailed:
                NSLog(@"支付失败");
                [self transactionsFailed:transaction];
                break;
            case SKPaymentTransactionStateRestored:
                NSLog(@"恢复购买 用于非消耗品");
                [self transactionsRestored:transaction];
                break;
            case SKPaymentTransactionStatePurchasing:
                NSLog(@"商品添加进列表  购买中");
                break;
            case SKPaymentTransactionStateDeferred:
                NSLog(@"事务在队列中，但它的最终状态是等待外部操作");
                break;
            default:
                NSLog(@"未知错误");
                break;
        }
    }
}

#pragma mark==交易完成的操作
- (void) sendReceipt:(SKPaymentTransaction *)transaction {
    NSData *receipt = nil;
    if ([[NSBundle mainBundle] respondsToSelector:@selector(appStoreReceiptURL)]) {
        NSURL *receiptUrl = [[NSBundle mainBundle] appStoreReceiptURL];
        receipt = [NSData dataWithContentsOfURL:receiptUrl];
    }else {
        // iOS7之前 使用
        if ([transaction respondsToSelector:@selector(transactionReceipt)]) {
            receipt = [transaction transactionReceipt];
        }
    }
    
    // 服务器
    NSString *aareceipt = [receipt base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed];
    self.receiptJson = aareceipt;
    
    // 苹果服务器
    [self verifyReceipt:aareceipt andDebug:YES];
    // 游戏服务器
    [self sendToServer:aareceipt transID:transaction.transactionIdentifier];
    // 交易完成
//    [self removePaymentQueue:transaction];
    
    if(!is_first) {
//        [self removePaymentQueue:transaction];
    }
}

-(void) transactionsSuccess:(SKPaymentTransaction*)transaction {
    NSLog(@"transactionIdentifier: %@", transaction.transactionIdentifier);//交易事物id
    NSLog(@"productIdentifier: %@", transaction.payment.productIdentifier);//不能设置(产品id)
    NSLog(@"applicationUsername: %@", transaction.payment.applicationUsername);//自己设置的订单id
    NSLog(@"quantity: %ld", transaction.payment.quantity);//自己设置的数量
    NSLog(@"date: %@", transaction.transactionDate);//交易时间 Thu Nov 21 15:41:07 2019
    
    [self sendReceipt:transaction];
}

#pragma mark cancel or fail
-(void) transactionsFailed:(SKPaymentTransaction*)transaction {
    if (transaction.error.code!=SKErrorPaymentCancelled) {
        NSLog(@"购买失败");
    }else if (transaction.error.code!=SKErrorPaymentInvalid) {
        NSLog(@"无效支付");
    }else if (transaction.error.code!=SKErrorPaymentNotAllowed) {
        NSLog(@"不允许支付");
    }else{
        NSLog(@"购买取消");
    }
    [self removePaymentQueue:transaction];
}

#pragma mark Restored
-(void) transactionsRestored:(SKPaymentTransaction*)transaction {
    //对于已经购买过的商品，处理恢复购买的逻辑
    [self removePaymentQueue:transaction];
    
}

#pragma mark==remove the paymentQueue
-(void) removePaymentQueue:(SKPaymentTransaction*)transaction {
     [[SKPaymentQueue defaultQueue ]finishTransaction:transaction];
}

//移除观察者
-(void) dealloc {
    [[SKPaymentQueue defaultQueue]removeTransactionObserver:self];
}

- (void) didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}



/**
 服务器端验证：
     21000 App Store无法读取你提供的JSON数据
     21002 收据数据不符合格式
     21003 收据无法被验证
     21004 你提供的共享密钥和账户的共享密钥不一致
     21005 收据服务器当前不可用
     21006 收据是有效的，但订阅服务已经过期。当收到这个信息时，解码后的收据信息也包含在返回内容中
     21007 收据信息是测试用（sandbox），但却被发送到产品环境中验证
     21008 收据信息是产品环境中使用，但却被发送到测试环境中验证
 **/
#pragma mark== 苹果服务器验证
-(void) verifyReceipt:(NSString*)receiptStr andDebug:(BOOL)debug
{
    NSLog(@"你正在进行客户端验证收据, 建议服务器来做验证");
    NSError *error;
    // NSLog(@"%@", receiptStr);
    NSDictionary *requestContents = @{@"receipt-data": receiptStr};
    NSData *requestData = [NSJSONSerialization dataWithJSONObject:requestContents
                                                          options:0
                                                            error:&error];
    if (!requestData) {
        NSLog(@"requestData  is nil");
        return;
    }
    
    // Create a POST request with the receipt data.
    NSString *url = nil;
    if (debug){
        url = [NSString stringWithUTF8String:"https://sandbox.itunes.apple.com/verifyReceipt"];
    }else{
        url = [NSString stringWithUTF8String:"https://buy.itunes.apple.com/verifyReceipt"];
    }
    NSURL *storeURL = [NSURL URLWithString:url];
    NSMutableURLRequest *storeRequest = [NSMutableURLRequest requestWithURL:storeURL];
    [storeRequest setHTTPMethod:@"POST"];
    [storeRequest setHTTPBody:requestData];
    
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:storeRequest completionHandler: ^(NSData *data, NSURLResponse *response, NSError *error) {
          if (error) {
              NSLog(@"[IAPApi] 验证connectionError :%@",error);
          } else {
              NSString * str  =[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
              NSError *error;
              NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
              
              if (!jsonResponse) {
                  NSLog(@"[IAPApi] 验证错误:%@", error);
                  NSLog(@"%@", str);
                  return;
              }
              
              // NSLog(@"[IAPApi] 验证结果 :%@",str);
              NSNumber *status = jsonResponse[@"status"];
              switch ([status intValue]) {
                  case 21007:
                      NSLog(@"[IAPApi] verify result code: 21007,resend to sandbox env");
                      [self verifyReceipt:receiptStr andDebug:YES];
                      break;
                  case 21008:
                      NSLog(@"[IAPApi] verify result code: 21008,resend to production env ");
                      [self verifyReceipt:receiptStr andDebug:NO];
                      break;
                  case 0:
                      //NSLog(@"验证结果成功：");
                      //NSLog(@"%@", str);
                  default:
                      //NSLog(@"验证结果：");
                      //NSLog(@"%@", str);
                      break;
              }
          }
    }];
    
    [task resume];
}


#pragma mark 游戏服务器验证
-(void) sendToServer:(NSString*)receiptStr transID:(NSString*)transID {
    NSString *url = @"http://172.16.140.70:8212/iapIOS";

    NSError *error;
    NSDictionary *requestContents = @{@"receipt-data": receiptStr, @"transactionID":transID};
    NSData *requestData = [NSJSONSerialization dataWithJSONObject:requestContents
                                                          options:0
                                                            error:&error];
    
    NSURL *storeURL = [NSURL URLWithString:url];
    NSMutableURLRequest *storeRequest = [NSMutableURLRequest requestWithURL:storeURL];
    [storeRequest setHTTPMethod:@"POST"];
    [storeRequest setHTTPBody:requestData];
    // 请求头的设置根服务器端一定要一样
    [storeRequest setValue:@"application/json;charset=utf-8" forHTTPHeaderField:@"content-type"];
    
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:storeRequest completionHandler: ^(NSData *data, NSURLResponse *response, NSError *error) {
          if (error) {
              NSLog(@"[IAPApi] 验证connectionError :%@",error);
          } else {
              NSString * str  =[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
              NSError *error;
              NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
              
              if(error) {
                  NSLog(@"err:%@", error);
              } else {
                  NSLog(@"%@", jsonResponse);
                  NSLog(@"%@", str);
              }
          }
    }];
    
    [task resume];
}

@end
