#import "MinecraftMessages.h"
#import <objc/runtime.h>

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



@implementation MCChanges
@synthesize changes;
-(id)init;
{
	changes = [NSMutableArray new];
	return self;
}
-(void)dealloc;
{
	[changes release];
	[super dealloc];
}
-(NSString*)description;
{
	return [changes description];
}
@end

@implementation MCBlockChange
@synthesize x, y, z, type, metadata;
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

Class MinecraftMessageFactoryCS(uint8_t packetId)
{
	static Class messages[0xff+1] = {Nil};
	static BOOL inited = NO;
	if(!inited) {
		int numClasses = objc_getClassList(NULL, 0);
		Class *classes = malloc(sizeof(Class)*numClasses);
		numClasses = objc_getClassList(classes, numClasses);
		
		for(int i = 0; i < numClasses; i++) {
			Class cls = classes[i];
			if([NSStringFromClass(cls) hasPrefix:@"CS"] && [cls superclass] == [APMessage class])
				messages[[cls packetId]] = [cls class];
		}
		
		free(classes);
		
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

@implementation SCMultiBlockChange
+(uint8_t)packetId; { return 0x34; }
@synthesize x, z, changes;
@end


@implementation SCBlockChange
+(uint8_t)packetId; { return 0x35; }
@synthesize x, y, z, type, metadata;
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
		int numClasses = objc_getClassList(NULL, 0);
		Class *classes = malloc(sizeof(Class)*numClasses);
		numClasses = objc_getClassList(classes, numClasses);
		
		for(int i = 0; i < numClasses; i++) {
			Class cls = classes[i];
			if([NSStringFromClass(cls) hasPrefix:@"SC"] && [cls superclass] == [APMessage class])
				messages[[cls packetId]] = [cls class];
		}
		
		free(classes);
		
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
		[nsdata getBytes:&itemId length:2];
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



enum {
	ReadingSize, ReadingCoordinates, ReadingTypes, ReadingMetadata
};
@implementation APReaderMCChanges

-(id)initReadingField:(int)field_
			ofMessage:(APMessage*)msg_
		   fromSocket:(AsyncSocket*)sock
			 delegate:delegate_;
{
	if(![super initReadingField:field_ ofMessage:msg_ fromSocket:sock delegate:delegate_]) return nil;
	
	changes = [MCChanges new];
	
	[sock readDataToLength:2 withTimeout:1 tag:ReadingSize];
	return self;
}
-(void)dealloc;
{
	[changes release];
	[super dealloc];
}

- (void)onSocket:(AsyncSocket *)sock didReadData:(NSData *)nsdata withTag:(uintptr_t)tag
{
	if(tag == ReadingSize) {
		uint16_t size;
		[nsdata getBytes:&size length:2];
		size = EndianU16_BtoN(size);
		
		for(int i = 0; i < size; i++) {
			MCBlockChange *change = [MCBlockChange new];
			[changes.changes addObject:change];
			[change release];
		}
		
		[sock readDataToLength:size*2 withTimeout:1 tag:ReadingCoordinates];
	} else if(tag == ReadingCoordinates) {
		for(int i = 0, c = changes.changes.count; i < c; i++) {
			union {
				uint16_t val;
				struct  {
					uint8_t x:4;
					uint8_t z:4;
					uint8_t y:8; 
				} __attribute__((__packed__));
			} coord;
			[nsdata getBytes:&coord.val range:NSMakeRange(i*2, 2)];
			coord.val = EndianU16_BtoN(coord.val);
			MCBlockChange *change = [changes.changes objectAtIndex:i];
			change.x = coord.x;
			change.y = coord.y;
			change.z = coord.z;
		}
		[sock readDataToLength:changes.changes.count withTimeout:1 tag:ReadingTypes];
	} else if(tag == ReadingTypes) {
		for(int i = 0, c = changes.changes.count; i < c; i++) {
			MCBlockChange *change = [changes.changes objectAtIndex:i];
			uint8_t type;
			[nsdata getBytes:&type range:NSMakeRange(i, 1)];
			change.type = type;
		}
		[sock readDataToLength:changes.changes.count withTimeout:1 tag:ReadingMetadata];
	} else if(tag == ReadingMetadata) {
		for(int i = 0, c = changes.changes.count; i < c; i++) {
			MCBlockChange *change = [changes.changes objectAtIndex:i];
			uint8_t metadata;
			[nsdata getBytes:&metadata range:NSMakeRange(i, 1)];
			change.metadata = metadata;
		}
		[self notifyDelegateObjectWasRead:changes fromSocket:sock];
	}
}
@end

