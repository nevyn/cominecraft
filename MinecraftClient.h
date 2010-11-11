#import <Foundation/Foundation.h>
#import "MinecraftMessages.h"
#import "AsyncSocket.h"
#import "AutoProto.h"
#import "ASIHTTPRequest.h"

@interface MinecraftClient : NSObject {
	AsyncSocket *sck;
	APProtoTalker *_talker;
}
@property (copy) NSString *hostToConnectTo, *sessionId;
@property (retain) ASIHTTPRequest *sessionIdRequest, *serverJoinRequest;
-(id)initTo:(NSString*)host error:(NSError**)err;
@end
