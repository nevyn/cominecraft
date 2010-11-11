#import "MinecraftMessages.h"

#pragma mark 
#pragma mark Client-to-server

@implementation CSKeepAlive
+(uint8_t)packetId; { return 0x00; }
@end
@implementation CSLoginRequest
+(uint8_t)packetId; { return 0x01; }
@synthesize protocolVersion, username, password, mapSeed, dimension;
@end
@implementation CSHandshake
+(uint8_t)packetId; { return 0x02; }
@synthesize username;
@end
@implementation CSChatMessage
+(uint8_t)packetId; { return 0x03; }
@synthesize message;
@end

#define insert(cls) messages[[cls packetId]] = [cls class]


Class MinecraftMessageFactoryCS(uint8_t packetId)
{
	static Class messages[0xff+1] = {Nil};
	static BOOL inited = NO;
	if(!inited) {
		insert(CSKeepAlive);
		insert(CSLoginRequest);
		insert(CSHandshake);
		insert(CSChatMessage);
		inited = YES;
	}
	return messages[packetId];
}

#pragma mark
#pragma mark Server-to-client

@implementation SCKeepAlive
+(uint8_t)packetId; { return 0x00; }
@end

@implementation SCLoginResponse
+(uint8_t)packetId; { return 0x01; }
@synthesize unknown, serverNameMaybe, MOTDMaybe, mapSeed, dimension;
@end

@implementation SCHandshake
+(uint8_t)packetId; { return 0x02; }
@synthesize connectionHash;
@end

@implementation SCChatMessage
+(uint8_t)packetId; { return 0x03; }
@synthesize message;
@end

@implementation SCTimeUpdate
+(uint8_t)packetId; { return 0x04; }
@synthesize timeInMinutes;
@end

Class MinecraftMessageFactorySC(uint8_t packetId)
{
	static Class messages[0xff+1] = {Nil};
	static BOOL inited = NO;
	if(!inited) {
		insert(SCKeepAlive);
		insert(SCLoginResponse);
		insert(SCHandshake);
		insert(SCChatMessage);
		insert(SCTimeUpdate);
		inited = YES;
	}
	return messages[packetId];
}
