#import "AutoProto.h"

@interface LoginRequest : APMessage
@property uint32_t protocolVersion;
@property (retain) NSString *username, *password;
@property uint64_t mapSeed;
@property uint8_t dimension;
@end

Class MinecraftMessageFactory(uint8_t packetId);