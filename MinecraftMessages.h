#import "AutoProto.h"

// http://mc.kev009.com/wiki/Protocol

#pragma mark Client-to-server

@interface CSKeepAlive : APMessage
@end

@interface CSLoginRequest : APMessage
@property uint32_t protocolVersion;
@property (copy) NSString *username, *password;
@property uint64_t mapSeed;
@property uint8_t dimension;
@end

@interface CSHandshake : APMessage
@property (copy) NSString *username;
@end

@interface CSChatMessage : APMessage
@property (copy) NSString *message;
@end

Class MinecraftMessageFactoryCS(uint8_t packetId);


#pragma mark 
#pragma mark Server-to-client

@interface SCKeepAlive : APMessage
@end

@interface SCLoginResponse : APMessage
@property uint32_t unknown;
@property (copy) NSString *serverNameMaybe;
@property (copy) NSString *MOTDMaybe;
@property uint64_t mapSeed;
@property uint8_t dimension;
@end

@interface SCHandshake : APMessage
@property (copy) NSString *connectionHash;
@end

@interface SCChatMessage : APMessage
@property (copy) NSString *message;
@end

@interface SCTimeUpdate : APMessage
@property uint64_t timeInMinutes;
@end

Class MinecraftMessageFactorySC(uint8_t packetId);