#import "MinecraftMessages.h"

@implementation LoginRequest
@synthesize protocolVersion, username, password, mapSeed, dimension;
@end

Class MinecraftMessageFactory(uint8_t packetId)
{
	static Class messages[0xff] = {Nil};
	static BOOL inited = NO;
	if(!inited) {
		messages[0x01] = [LoginRequest class];
		inited = YES;
	}
	return messages[packetId];
}