#import <Foundation/Foundation.h>
#import "MinecraftMessages.h"
#import "AsyncSocket.h"
#import "AutoProto.h"

@interface MinecraftClient : NSObject {
	AsyncSocket *sck;
	APProtoTalker *talker;
}
-(id)initTo:(NSString*)host error:(NSError**)err;
@end
