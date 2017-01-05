#import "ViewController.h"

@interface SignInViewController : ViewController
/** 主要向主界面传递登录用户名和下载的用户数据 */
@property (nonatomic, copy) void(^transferRecordsAndUserName)(NSArray *records, NSString *userName);
@end
