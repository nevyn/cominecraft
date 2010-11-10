#import <Foundation/Foundation.h>
#import <CoreServices/CoreServices.h>
#import <objc/runtime.h>
#import "AsyncSocket.h"

NSString *typeEncodingInPropertyAttribs(NSString *attrs)
{
	return [attrs substringWithRange:NSMakeRange(1, [attrs rangeOfString:@","].location-1)];
}

@interface MCMessage : NSObject
@end
@implementation MCMessage
-(void)dealloc;
{
	objc_property_t *props; unsigned int c;	
	props = class_copyPropertyList([self class], &c);
	for(int i = c; i > 0; i--) {
		objc_property_t prop = props[i-1];
		NSString *enc = typeEncodingInPropertyAttribs([NSString stringWithUTF8String:property_getAttributes(prop)]);
		if([enc hasPrefix:@"@"]) {
			NSString *name = [NSString stringWithUTF8String:property_getName(prop)];
			[self setValue:nil forKey:name];
		}
	}
	free(props);
	[super dealloc];
}
-(NSString*)description;
{
	NSMutableString *s = [NSMutableString string];
	objc_property_t *props; unsigned int c;	
	props = class_copyPropertyList([self class], &c);
	[s appendFormat:@"<%@@%p\n", [self class], self];
	for(int i = c; i > 0; i--) {
		NSString *name = [NSString stringWithUTF8String:property_getName(props[i-1])];
		[s appendFormat:@"\t%@: %@\n", name, [self valueForKey:name]];
	}
	[s appendFormat:@">"];
	free(props);
	return s;
}
@end

@protocol StringReaderDelegate
-(void)stringReader:(id)reader readString:(NSString*)string userData:(int)field socket:(AsyncSocket*)sck;
@end

@interface StringReader : NSObject
{
	id delegate;
	int field;
}
@end
enum { ReadingLength, ReadingData};
@implementation StringReader
-(id)initOnSocket:(AsyncSocket*)s delegate:(id)del userData:(int)field_;
{
	delegate = del;
	field = field_;
	s.delegate = self;
	[s readDataToLength:2 withTimeout:-1 tag:ReadingLength];
	return self;
}
- (void)onSocket:(AsyncSocket *)sock didReadData:(NSData *)nsdata withTag:(long)tag
{
	if(tag == ReadingLength) {
		uint16_t len;
		memcpy(&len, [nsdata bytes], 2);
		len = EndianU16_BtoN(len);
		[sock readDataToLength:len withTimeout:-1 tag:ReadingData];
	} else if(tag == ReadingData) {
		NSString *s = [[[NSString alloc] initWithData:nsdata encoding:NSUTF8StringEncoding] autorelease];
		[delegate stringReader:self readString:s userData:field socket:sock];
	}
}
- (void)onSocket:(AsyncSocket *)sock willDisconnectWithError:(NSError *)err;
{
	[delegate onSocket:sock willDisconnectWithError:err];
}

@end


@protocol MessageReaderDelegate
-(void)messageReader:(id)reader doneReadingMessage:(MCMessage*)msg;
@end
@interface MessageReader : NSObject
{
	MCMessage *message;
	id delegate;
	int currentField;
	objc_property_t *props; unsigned int c;
}
-(void)readField:(int)field onSocket:(AsyncSocket*)sck;
@end
@implementation MessageReader
-(id)initWithMessage:(MCMessage*)toPopulate fromSocket:(AsyncSocket*)sck whenDone:(id)delegate_;
{
	message = [toPopulate retain];
	delegate = delegate_;
	sck.delegate = self;
	
	props = class_copyPropertyList([message class], &c);

	[self readField:0 onSocket:sck];
	return self;
}
-(objc_property_t)propAtIndex:(int)i;
{
	return props[c-i-1];
}
-(void)dealloc;
{
	free(props);
	[message release];
	[super dealloc];
}
-(void)readField:(int)field onSocket:(AsyncSocket*)sck;
{
	objc_property_t prop = [self propAtIndex:field];
	NSString *attrs = [NSString stringWithUTF8String:property_getAttributes(prop)];
	NSString *typeEncoding = typeEncodingInPropertyAttribs(attrs);
	NSString *name = [NSString stringWithUTF8String:property_getName(prop)];
	
	int length = 0;
	if([[typeEncoding uppercaseString] isEqual:@"C"]) length = 1;
	else if([[typeEncoding uppercaseString] isEqual:@"S"]) length = 2;
	else if([[typeEncoding uppercaseString] isEqual:@"I"]) length = 4;
	else if([typeEncoding isEqual:@"f"]) length = 4;
	else if([[typeEncoding uppercaseString] isEqual:@"Q"]) length = 8;
	else if([typeEncoding isEqual:@"d"]) length = 8;
	else if([typeEncoding isEqual:@"@\"NSString\""]) {
		[[StringReader alloc] initOnSocket:sck delegate:self userData:field];
		return;
	} else [NSException raise:NSInvalidArgumentException format:@"Unknown type encoding %@ for prop %@", typeEncoding, name];
		
	[sck readDataToLength:length withTimeout:-1 tag:field];
}
-(void)stringReader:(id)reader readString:(NSString*)string userData:(int)field socket:(AsyncSocket*)sck;
{
	objc_property_t prop = [self propAtIndex:field];
	NSString *name = [NSString stringWithUTF8String:property_getName(prop)];
	
	NSString *setterName = [NSString stringWithFormat:@"set%@%@:", [[name substringToIndex:1] uppercaseString], [name substringFromIndex:1]];
	SEL setter = NSSelectorFromString(setterName);
	NSMethodSignature *sig = [message methodSignatureForSelector:setter];	
	NSInvocation *ivc = [NSInvocation invocationWithMethodSignature:sig];
	[ivc setArgument:&string atIndex:2];
	[ivc setSelector:setter];
	[ivc invokeWithTarget:message];
	
	sck.delegate = self;
	[reader release];
	
	
	if(field+1 == c)
		[delegate messageReader:self doneReadingMessage:message];
	else
		[self readField:field+1 onSocket:sck];
}
- (void)onSocket:(AsyncSocket *)sock didReadData:(NSData *)nsdata withTag:(long)field
{
	objc_property_t prop = [self propAtIndex:field];
	NSString *attrs = [NSString stringWithUTF8String:property_getAttributes(prop)];
	NSString *typeEncoding = [attrs substringWithRange:NSMakeRange(1, [attrs rangeOfString:@","].location-1)];
	NSString *name = [NSString stringWithUTF8String:property_getName(prop)];
	uint8_t data[[nsdata length]];
	memcpy(data, [nsdata bytes], [nsdata length]);
#define swapIf(encoding, type, conversionMethod) if([typeEncoding isEqual:encoding]) { type converted = conversionMethod(*((type*)data)); memcpy(&data, &converted, [nsdata length]); }
	swapIf(@"s", int16_t, EndianS16_BtoN)
	else swapIf(@"S", uint16_t, EndianU16_BtoN)
	else swapIf(@"i", int32_t, EndianS32_BtoN)
	else swapIf(@"I", uint32_t, EndianU32_BtoN)
	else swapIf(@"q", int64_t, EndianS64_BtoN)
	else swapIf(@"Q", uint64_t, EndianU64_BtoN)
	
	NSString *setterName = [NSString stringWithFormat:@"set%@%@:", [[name substringToIndex:1] uppercaseString], [name substringFromIndex:1]];
	SEL setter = NSSelectorFromString(setterName);
	NSMethodSignature *sig = [message methodSignatureForSelector:setter];	
	NSInvocation *ivc = [NSInvocation invocationWithMethodSignature:sig];
	[ivc setArgument:data atIndex:2];
	[ivc setSelector:setter];
	[ivc invokeWithTarget:message];
	
	if(field+1 == c)
		[delegate messageReader:self doneReadingMessage:message];
	else
		[self readField:field+1 onSocket:sock];
}
- (void)onSocket:(AsyncSocket *)sock willDisconnectWithError:(NSError *)err;
{
	[delegate onSocket:sock willDisconnectWithError:err];
}
@end




@interface LoginRequest : MCMessage
@property uint32_t protocolVersion;
@property (retain) NSString *username, *password;
@property uint64_t mapSeed;
@property uint8_t dimension;
@end
@implementation LoginRequest
@synthesize protocolVersion, username, password, mapSeed, dimension;
@end


@interface MCProtoTalker : NSObject
{
	AsyncSocket *sck;
}
@end
@implementation MCProtoTalker
-(id)initWithSocket:(AsyncSocket*)sock;
{
	sck = [sock retain];
	sck.delegate = self;
	
	[sck readDataToLength:sizeof(uint8_t) withTimeout:-1 tag:0];
	
	return self;
}
- (void)onSocket:(AsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
	static Class messages[0xff]; static BOOL inited = NO;
	if(!inited) {
		messages[0x01] = [LoginRequest class];
		inited = YES;
	}
	
	uint8_t packet = *(uint8_t*)[data bytes];
	
	MCMessage *msg = [[[messages[packet] alloc] init] autorelease];
	
	[[MessageReader alloc] initWithMessage:msg fromSocket:sck whenDone:self];
}
- (void)onSocket:(AsyncSocket *)sock willDisconnectWithError:(NSError *)err;
{
	NSLog(@" :( %@", err);
}
-(void)messageReader:(id)reader doneReadingMessage:(MCMessage*)msg;
{
	sck.delegate = self;
	NSLog(@"Finished reading message: %@", msg);
	[reader release];
	[sck readDataToLength:sizeof(uint8_t) withTimeout:-1 tag:0];
}
@end




@interface asdf : NSObject
@end
@implementation asdf
- (void)onSocket:(AsyncSocket *)sock didAcceptNewSocket:(AsyncSocket *)newSocket;
{
	NSLog(@"Accepted");
	[newSocket retain];
	struct {
		uint8_t type; uint32_t pv; uint16_t ul; char u[3]; uint16_t pl; char p[4]; uint64_t ms; uint8_t d;
	} __attribute__((__packed__)) data0 = {0x01, 
		EndianU32_NtoB(5), 
		EndianU16_NtoB(3), "nev", 
		EndianU16_NtoB(4), "1234", 
		EndianU64_NtoB(12345),
		2
	};
	NSData *data = [NSData dataWithBytes:&data0 length:sizeof(data0)];
	[newSocket writeData:data withTimeout:-1 tag:0];
}
@end



int main (int argc, const char * argv[]) {
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	AsyncSocket *server = [[AsyncSocket alloc] initWithDelegate:[asdf new]];
	[server acceptOnPort:1234 error:nil];
	
	AsyncSocket *client = [[AsyncSocket alloc] initWithDelegate:[asdf new]];
	[[MCProtoTalker alloc] initWithSocket:client];
	[client connectToHost:@"localhost" onPort:1234 error:nil];
	
	
	
	[[NSRunLoop currentRunLoop] run];
	
	
    [pool drain];
    return 0;
}
