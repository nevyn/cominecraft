#import <Foundation/Foundation.h>
#import "MinecraftMessages.h"
#import "AsyncSocket.h"
#import "AutoProto.h"

@interface MinecraftClient : NSObject {
	AsyncSocket *sck;
	APProtoTalker *_talker;
}
-(id)initTo:(NSString*)host error:(NSError**)err;
@end
