#import "ViewController.h"

@interface RegisterViewController : ViewController
/** 主要向登录页面传递注册的用户名, 不用再输入了 */
@property (nonatomic, copy) void(^transferUserName)(NSString *userName);
@end
