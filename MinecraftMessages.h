#import "AutoProto.h"

// http://mc.kev009.com/wiki/Protocol

#pragma mark Model

@interface MCInventoryItem : NSObject
{
	int16_t itemId;
	uint8_t count;
	uint16_t health;
}
@property int16_t itemId;
@property uint8_t count;
@property uint16_t health;
-(BOOL)empty;
@end

@interface MCInventory : NSObject
{
	NSMutableArray *items;
}
@property (retain) NSMutableArray *items;
@end

@interface MCBlockChange : NSObject
{
	uint8_t x, y, z;
	uint8_t type, metadata;
}
@property uint8_t x, y, z;
@property uint8_t type, metadata;
@end

@interface MCChanges : NSObject
{
	NSMutableArray *changes;
}
@property (retain) NSMutableArray *changes;
@end

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


typedef enum { 
	InventoryTypeMain = -1,
	InventoryTypeEquipped = -2,
	InventoryTypeCrafting = -3,
} InventoryType;
@interface SCPlayerInventory : APMessage
@property int32_t type;
@property uint16_t count;
@property (retain) MCInventory *inventory;
@end


@interface SCSpawnPosition : APMessage
@property int32_t x, y, z;
@end

@interface SCPlayerPositionAndLook : APMessage
@property double x, stance, y, z;
@property float yaw, pitch;
@property uint8_t onGround;
@end

@interface SCNamedEntitySpawn : APMessage
@property uint32_t entityId;
@property (copy) NSString *entityName;
@property int32_t x, y, z;
@property int8_t yaw, pitch;
@property int16_t itemId;
@end

@interface SCMobSpawn : APMessage
@property uint32_t entityId;
@property uint8_t mobType;
@property int32_t x, y, z;
@property int8_t yaw, pitch;
@end

@interface SCCreateEntity : APMessage
@property uint32_t entityId;
@end

@interface SCEntityRelativeMove : APMessage
@property uint32_t entityId;
@property int8_t x, y, z;
@end

@interface SCEntityLook : APMessage
@property uint32_t entityId;
@property int8_t yaw, pitch;
@end

@interface SCEntityLookRelativeMove : APMessage
@property uint32_t entityId;
@property int8_t x, y, z;
@property int8_t yaw, pitch;
@end

@interface SCEntityTeleport : APMessage
@property uint32_t entityId;
@property int32_t x, y, z;
@property int8_t yaw, pitch;
@end

@interface SCAttachEntity : APMessage
@property uint32_t entityId;
@property uint32_t vehicleId;
@end

@interface SCPreChunk : APMessage
@property int32_t x;
@property int32_t y;
@property uint8_t mode;
@end

@interface SCMapChunk : APMessage
@property int32_t x;
@property int16_t y;
@property int32_t z;
@property uint8_t w, h, d;
@property (retain) NSData *chunk;
@end

@interface SCMultiBlockChange : APMessage
@property int32_t x, z;
@property (retain) MCChanges *changes;
@end


@interface SCBlockChange : APMessage
@property int32_t x, z;
@property int8_t y;
@property uint8_t type;
@property uint8_t metadata;
@end




@interface SCKick : APMessage
@property (copy) NSString *reason;
@end

Class MinecraftMessageFactorySC(uint8_t packetId);


#pragma mark -

@interface APReaderNSData : APMessagePartReaderBase 
-(id)initReadingField:(int)field
			ofMessage:(APMessage*)msg 
		   fromSocket:(AsyncSocket*)sck
			 delegate:delegate;
@end

@interface APReaderMCInventory : APMessagePartReaderBase
{
	MCInventory *inventory;
	MCInventoryItem *underConstruction;
	int itemsToRead;
}
@property (retain) MCInventoryItem *underConstruction;
-(id)initReadingField:(int)field
			ofMessage:(APMessage*)msg 
		   fromSocket:(AsyncSocket*)sck
			 delegate:delegate;
@end

@interface APReaderMCChanges : APMessagePartReaderBase
{
	MCChanges *changes;
}
-(id)initReadingField:(int)field
			ofMessage:(APMessage*)msg 
		   fromSocket:(AsyncSocket*)sck
			 delegate:delegate;
@end

