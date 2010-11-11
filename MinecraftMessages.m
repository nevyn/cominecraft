#import "MinecraftMessages.h"

#pragma mark Model
@implementation MCInventory
@synthesize items;
-(id)init;
{
	items = [NSMutableArray new];
	return self;
}
-(void)dealloc;
{
	[items release];
	[super dealloc];
}
-(NSString*)description;
{
	return [items description];
}
@end

@implementation MCInventoryItem
@synthesize itemId, count, health;
-(BOOL)empty;
{
	return itemId == -1;
}
-(NSString*)description;
{
	return [NSString stringWithFormat:@"<Item %d (x%d) at %d health>", itemId, count, health];
}
@end



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

@implementation SCPlayerInventory
+(uint8_t)packetId; { return 0x05; }
@synthesize type, count, inventory;
@end


@implementation SCSpawnPosition
+(uint8_t)packetId; { return 0x06; }
@synthesize x, y, z;
@end

@implementation SCPlayerPositionAndLook
+(uint8_t)packetId; { return 0x0d; }
@synthesize x, stance, y, z, yaw, pitch, onGround;
@end

@implementation SCMobSpawn
+(uint8_t)packetId; { return 0x18; }
@synthesize entityId, mobType, x, y, z, yaw, pitch;
@end

@implementation SCCreateEntity
+(uint8_t)packetId; { return 0x1e; }
@synthesize entityId;
@end

@implementation SCEntityRelativeMove
+(uint8_t)packetId; { return 0x1f; }
@synthesize entityId, x, y, z;
@end

@implementation SCEntityLook
+(uint8_t)packetId; { return 0x20; }
@synthesize entityId, yaw, pitch;
@end

@implementation SCEntityLookRelativeMove
+(uint8_t)packetId; { return 0x21; }
@synthesize entityId, x, y, z, yaw, pitch;
@end

@implementation SCEntityTeleport
+(uint8_t)packetId; { return 0x22; }
@synthesize entityId, x, y, z, yaw, pitch;
@end

@implementation SCAttachEntity
+(uint8_t)packetId; { return 0x27; }
@synthesize entityId, vehicleId;
@end




@implementation SCPreChunk
+(uint8_t)packetId; { return 0x32; }
@synthesize x, y, mode;
@end

@implementation SCMapChunk
+(uint8_t)packetId; { return 0x33; }
@synthesize x, y, z, w, h, d, chunk;
@end


@implementation SCKick
+(uint8_t)packetId; { return 0xff; }
@synthesize reason;
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
		insert(SCPlayerInventory);
		insert(SCSpawnPosition);
		insert(SCPlayerPositionAndLook);
		insert(SCMobSpawn);
		insert(SCCreateEntity);
		insert(SCEntityRelativeMove);
		insert(SCEntityLook);
		insert(SCEntityLookRelativeMove);
		insert(SCEntityTeleport);
		insert(SCAttachEntity);
		insert(SCPreChunk);
		insert(SCMapChunk);
		insert(SCKick);
		inited = YES;
	}
	return messages[packetId];
}


#pragma mark -

enum { ReadingLength, ReadingData};

@implementation APReaderNSData
-(id)initReadingField:(int)field_
			ofMessage:(APMessage*)msg_
		   fromSocket:(AsyncSocket*)sck
			 delegate:delegate_;
{
	if(![super initReadingField:field_ ofMessage:msg_ fromSocket:sck delegate:delegate_]) return nil;
	
	[sck readDataToLength:4 withTimeout:1 tag:ReadingLength];

	return self;
}
- (void)onSocket:(AsyncSocket *)sock didReadData:(NSData *)nsdata withTag:(uintptr_t)tag
{
	if(tag == ReadingLength) {
		uint32_t len;
		[nsdata getBytes:&len length:4];
		len = EndianU32_BtoN(len);
		if(len == 0) {
			[self notifyDelegateObjectWasRead:[NSData data] fromSocket:sock];
			return;
		}
		[sock readDataToLength:len withTimeout:1 tag:ReadingData];
	} else if(tag == ReadingData) {
		[self notifyDelegateObjectWasRead:nsdata fromSocket:sock];
	}
}
@end

enum {
	ReadingItemId, ReadingItemInfo
};
@implementation APReaderMCInventory
@synthesize underConstruction;
-(void)readNextOnSocket:(AsyncSocket*)sck;
{
	if(inventory.items.count == itemsToRead) {
		[self notifyDelegateObjectWasRead:inventory fromSocket:sck];
	} else {
		[sck readDataToLength:2 withTimeout:1 tag:ReadingItemId];
	}
}
-(id)initReadingField:(int)field_
			ofMessage:(APMessage*)msg_
		   fromSocket:(AsyncSocket*)sck
			 delegate:delegate_;
{
	if(![super initReadingField:field_ ofMessage:msg_ fromSocket:sck delegate:delegate_]) return nil;
	
	itemsToRead = [(SCPlayerInventory*)msg_ count];
	
	inventory = [MCInventory new];
	
	[self readNextOnSocket:sck];
	return self;
}
-(void)dealloc;
{
	[inventory release];
	[super dealloc];
}

- (void)onSocket:(AsyncSocket *)sock didReadData:(NSData *)nsdata withTag:(uintptr_t)tag
{
	if(tag == ReadingItemId) {
		int16_t itemId;
		[nsdata getBytes:&itemId length:4];
		itemId = EndianS16_BtoN(itemId);
		
		self.underConstruction = [[MCInventoryItem new] autorelease];
		underConstruction.itemId = itemId;
		
		if(itemId == -1) {
			[inventory.items addObject:underConstruction];
			self.underConstruction = nil;
			[self readNextOnSocket:sock];
		} else {
			[sock readDataToLength:3 withTimeout:1 tag:ReadingItemInfo];
		}		
	} else if(tag == ReadingItemInfo) {
		uint8_t count;
		uint16_t health;
		[nsdata getBytes:&count range:NSMakeRange(0, 1)];
		[nsdata getBytes:&health range:NSMakeRange(1, 2)];
		underConstruction.count = count;
		underConstruction.health = health;
		[inventory.items addObject:underConstruction];
		self.underConstruction = nil;
		[self readNextOnSocket:sock];
	}
}
@end
