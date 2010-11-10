#import "AutoProto.h"
#import <objc/runtime.h>

#pragma mark Internal interface
@interface APMessagePartReaderBase ()
@property (readwrite, retain) APMessage *msg;
@end


@protocol APMessageReaderDelegate <NSObject /*, AsyncSocketDelegate*/>
-(void)messageReader:reader doneReadingMessage:(APMessage*)msg;
@end

@interface APMessageReader : NSObject
{
	APMessage *message;
	id delegate;
	int currentField;
	objc_property_t *props; unsigned int c;
}
-(id)initWithMessage:(APMessage*)toPopulate fromSocket:(AsyncSocket*)sck whenDone:delegate_;
-(void)readField:(int)field onSocket:(AsyncSocket*)sck;
-(void)tellDelegateWeAreDoneOnSocket:(AsyncSocket*)sck;
@end

@interface APMessageWriter : NSObject
+(void)writeMessage:(APMessage*)msg toSocket:(AsyncSocket*)sck;
@end

NSString *APTypeEncodingInPropertyAttribs(NSString *attrs);
Class APClassFromIdTypeEncoding(NSString *prefix, NSString *idTypeEncoding);
size_t APSizeOfType(NSString *typeEncoding);
typedef enum { SwapBtoN, SwapNtoB } SwapDirection;
void APSwapInPlace(void *data, NSString *typeEncoding, size_t length, SwapDirection direction);

@interface NSObject (APAccessors)
-(NSInvocation*)ap_setterForKey:(NSString*)name;
-(NSInvocation*)ap_getterForKey:(NSString*)name;
@end

#pragma mark 
#pragma mark Infrastructure
#pragma mark -

@implementation APMessage
+(uint8_t)packetId;
{
	[NSException raise:NSInvalidArgumentException format:@"+[%@ packetId] not implemented", NSStringFromClass(self)];
	return 0;
}
-(void)dealloc;
{
	objc_property_t *props; unsigned int c;	
	props = class_copyPropertyList([self class], &c);
	for(int i = c; i > 0; i--) {
		objc_property_t prop = props[i-1];
		NSString *enc = APTypeEncodingInPropertyAttribs([NSString stringWithUTF8String:property_getAttributes(prop)]);
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

@implementation APMessagePartReaderBase
@synthesize msg, field;
-(id)initReadingField:(int)field_
			ofMessage:(APMessage*)msg_
		   fromSocket:(AsyncSocket*)sck
			 delegate:delegate_;
{
	field = field_;
	self.msg = msg_;
	sck.delegate = self;
	delegate = delegate_;
	return self;
}
-(void)dealloc;
{
	self.msg = nil;
	[super dealloc];
}
-(void)notifyDelegateObjectWasRead:obj fromSocket:(AsyncSocket*)sck;
{
	sck.delegate = delegate;
	[delegate partReader:self readObject:obj forField:field ofMessage:msg onSocket:sck];
}
- (void)onSocket:(AsyncSocket *)sock willDisconnectWithError:(NSError *)err;
{
	[delegate onSocket:sock willDisconnectWithError:err];
	sock.delegate = delegate;
}

@end



@implementation APProtoTalker
@synthesize delegate;
-(id)initWithSocket:(AsyncSocket*)sock receivedMessageFactory:(APMessageFactory)factory_;
{
	sck = [sock retain];
	sck.delegate = self;
	factory = factory_;
	
	[sck readDataToLength:sizeof(uint8_t) withTimeout:-1 tag:0];
	
	return self;
}
- (void)onSocket:(AsyncSocket *)sock didReadData:(NSData *)data withTag:(uintptr_t)tag
{
	uint8_t packet = *(uint8_t*)[data bytes];
	
	APMessage *msg = [[[factory(packet) alloc] init] autorelease];
	if(!msg) {
		[NSException raise:NSInvalidArgumentException format:@"Unknown packet id encountered: 0x%x", packet];
		return;
	}
	[[APMessageReader alloc] initWithMessage:msg fromSocket:sck whenDone:self];
}
- (void)onSocket:(AsyncSocket *)sock willDisconnectWithError:(NSError *)err;
{
	[delegate onSocket:sock willDisconnectWithError:err];
}
-(void)messageReader:(id)reader doneReadingMessage:(APMessage*)msg;
{
	sck.delegate = self;
	NSString *specificSelName = [NSString stringWithFormat:@"protoTalker:received%@:", NSStringFromClass([msg class])];
	SEL specificSel = NSSelectorFromString(specificSelName);
	if(specificSel && [delegate respondsToSelector:specificSel]) {
		NSMethodSignature *sig = [delegate methodSignatureForSelector:specificSel];
		NSInvocation *ivc = [NSInvocation invocationWithMethodSignature:sig];
		[ivc setSelector:specificSel];
		[ivc setArgument:&self atIndex:2];
		[ivc setArgument:&msg atIndex:3];
		[ivc invokeWithTarget:delegate];
	} else {
		[delegate protoTalker:self receivedMessage:msg];
	}
	
	[reader release];
	[sck readDataToLength:sizeof(uint8_t) withTimeout:-1 tag:0];
}
-(void)sendMessage:(APMessage*)msg;
{
	[APMessageWriter writeMessage:msg toSocket:sck];
}
-(void)onSocket:(AsyncSocket *)sock didWriteDataWithTag:(uintptr_t)tag;
{
	[delegate protoTalker:self sentMessage:(id)tag];
}
@end



#pragma mark 
#pragma mark Internal implementations
#pragma mark -
@implementation APMessageReader
-(id)initWithMessage:(APMessage*)toPopulate fromSocket:(AsyncSocket*)sck whenDone:(id)delegate_;
{
	message = [toPopulate retain];
	delegate = delegate_;
	
	props = class_copyPropertyList([message class], &c);

	if(c == 0) {
		[self tellDelegateWeAreDoneOnSocket:sck];
		return self;
	}
	
	sck.delegate = self;

	[self readField:0 onSocket:sck];
	return self;
}
-(void)dealloc;
{
	free(props);
	[message release];
	[super dealloc];
}

-(objc_property_t)propAtIndex:(int)i;
{
	return props[c-i-1];
}
-(void)readField:(int)field onSocket:(AsyncSocket*)sck;
{
	objc_property_t prop = [self propAtIndex:field];
	NSString *attrs = [NSString stringWithUTF8String:property_getAttributes(prop)];
	NSString *typeEncoding = APTypeEncodingInPropertyAttribs(attrs);
	
	if([typeEncoding hasPrefix:@"@"]) {
		Class readerClass = APClassFromIdTypeEncoding(@"APReader", typeEncoding);
		[[readerClass alloc] initReadingField:field ofMessage:message fromSocket:sck delegate:self];
		return;
	}
	size_t length = APSizeOfType(typeEncoding);
		
	[sck readDataToLength:length withTimeout:-1 tag:field];
}
-(void)partReader:reader
	   readObject:obj 
		 forField:(int)field
		ofMessage:(APMessage*)msg
		 onSocket:(AsyncSocket*)sck;
{
	objc_property_t prop = [self propAtIndex:field];
	NSString *name = [NSString stringWithUTF8String:property_getName(prop)];
	
	NSString *setterName = [NSString stringWithFormat:@"set%@%@:", [[name substringToIndex:1] uppercaseString], [name substringFromIndex:1]];
	SEL setter = NSSelectorFromString(setterName);
	NSMethodSignature *sig = [message methodSignatureForSelector:setter];	
	NSInvocation *ivc = [NSInvocation invocationWithMethodSignature:sig];
	[ivc setArgument:&obj atIndex:2];
	[ivc setSelector:setter];
	[ivc invokeWithTarget:message];
	
	[reader release];
	
	
	if(field+1 == c)
		[delegate messageReader:self doneReadingMessage:message];
	else
		[self readField:field+1 onSocket:sck];
}
- (void)onSocket:(AsyncSocket *)sock didReadData:(NSData *)nsdata withTag:(uintptr_t)field
{
	objc_property_t prop = [self propAtIndex:field];
	NSString *attrs = [NSString stringWithUTF8String:property_getAttributes(prop)];
	NSString *typeEncoding = APTypeEncodingInPropertyAttribs(attrs);
	NSString *name = [NSString stringWithUTF8String:property_getName(prop)];
	
	uint8_t data[[nsdata length]];
	[nsdata getBytes:data length:[nsdata length]];
	APSwapInPlace(data, typeEncoding, [nsdata length], SwapBtoN);
	
	NSInvocation *ivc = [message ap_setterForKey:name];
	[ivc setArgument:data atIndex:2];
	[ivc invoke];
	
	if(field+1 == c)
		[delegate messageReader:self doneReadingMessage:message];
	else
		[self readField:field+1 onSocket:sock];
}
- (void)onSocket:(AsyncSocket *)sock willDisconnectWithError:(NSError *)err;
{
	[delegate onSocket:sock willDisconnectWithError:err];
}

-(void)tellDelegateWeAreDoneOnSocket:(AsyncSocket*)sck;
{
	sck.delegate = delegate;

	[delegate messageReader:self doneReadingMessage:message];
}
@end

@implementation APMessageWriter
+(void)writeMessage:(APMessage*)message toSocket:(AsyncSocket*)sck;
{
	uint8_t packet = [[message class] packetId];
	NSMutableData *d = [NSMutableData dataWithBytes:&packet length:1];
	
	unsigned c;
	objc_property_t *props = class_copyPropertyList([message class], &c);
	for(int i = c; i > 0; i--) {
		objc_property_t prop = props[i-1];
		NSString *attrs = [NSString stringWithUTF8String:property_getAttributes(prop)];
		NSString *typeEncoding = APTypeEncodingInPropertyAttribs(attrs);
		NSString *name = [NSString stringWithUTF8String:property_getName(prop)];
		
		if([typeEncoding hasPrefix:@"@"]) {
			Class writerClass = APClassFromIdTypeEncoding(@"APWriter", typeEncoding);
			[d appendData:[writerClass dataForKey:name ofMessage:message]];
		} else {
			size_t len = APSizeOfType(typeEncoding);
			uint8_t data[len];
			NSInvocation *ivc = [message ap_getterForKey:name];
			[ivc invoke];
			[ivc getReturnValue:data];
			APSwapInPlace(data, typeEncoding, len, SwapNtoB);
			[d appendData:[NSData dataWithBytes:data length:len]];
		}
	}
	
	[sck writeData:d withTimeout:-1 tag:(uintptr_t)message];
}
@end



#pragma mark 
#pragma mark Base implementations
#pragma mark -
enum { ReadingLength, ReadingData};

@implementation APReaderNSString
-(id)initReadingField:(int)field_
			ofMessage:(APMessage*)msg_
		   fromSocket:(AsyncSocket*)sck
			 delegate:delegate_;
{
	if(![super initReadingField:field_ ofMessage:msg_ fromSocket:sck delegate:delegate_]) return nil;
	
	[sck readDataToLength:2 withTimeout:-1 tag:ReadingLength];

	return self;
}
- (void)onSocket:(AsyncSocket *)sock didReadData:(NSData *)nsdata withTag:(uintptr_t)tag
{
	if(tag == ReadingLength) {
		uint16_t len;
		[nsdata getBytes:&len length:2];
		len = EndianU16_BtoN(len);
		[sock readDataToLength:len withTimeout:-1 tag:ReadingData];
	} else if(tag == ReadingData) {
		NSString *s = [[[NSString alloc] initWithData:nsdata encoding:NSUTF8StringEncoding] autorelease];
		[self notifyDelegateObjectWasRead:s fromSocket:sock];
	}
}
@end

@implementation APWriterNSString
+(NSData*)dataForKey:(NSString*)key ofMessage:(APMessage*)msg;
{
	NSString *str = [msg valueForKey:key];
	uint16_t len = EndianU16_NtoB([str length]);
	NSMutableData *d = [NSMutableData dataWithBytes:&len length:2];
	[d appendData:[str dataUsingEncoding:NSUTF8StringEncoding]];
	return d;
}
@end
#pragma mark 
#pragma mark Helpers
#pragma mark -

NSString *APTypeEncodingInPropertyAttribs(NSString *attrs)
{
	return [attrs substringWithRange:NSMakeRange(1, [attrs rangeOfString:@","].location-1)];
}

Class APClassFromIdTypeEncoding(NSString *prefix, NSString *typeEncoding)
{
	NSString *className = [typeEncoding substringFromIndex:2];
	className = [className substringToIndex:[className rangeOfString:@"\""].location];
	
	NSString *modClassName = [prefix stringByAppendingString:className];
	Class modClass = NSClassFromString(modClassName);
	if(!modClass) [NSException raise:NSInvalidArgumentException format:@"No %@ found for %@", prefix, className];
	return modClass;
}

size_t APSizeOfType(NSString *typeEncoding)
{
	if([[typeEncoding uppercaseString] isEqual:@"C"]) return 1;
	else if([[typeEncoding uppercaseString] isEqual:@"S"]) return 2;
	else if([[typeEncoding uppercaseString] isEqual:@"I"]) return 4;
	else if([typeEncoding isEqual:@"f"]) return 4;
	else if([[typeEncoding uppercaseString] isEqual:@"Q"]) return 8;
	else if([typeEncoding isEqual:@"d"]) return 8;
	[NSException raise:NSInvalidArgumentException format:@"No size for type encoding %@ available", typeEncoding];
	return 0;
}

void APSwapInPlace(void *data, NSString *typeEncoding, size_t length, SwapDirection direction) {
	#define swapIf(encoding, type, conversionMethodNtoB, conversionMethodBtoN) \
		if([typeEncoding isEqual:encoding]) { \
			type converted; \
			if(direction ==SwapBtoN)\
				converted = conversionMethodBtoN(*((type*)data)); \
			else \
				converted = conversionMethodNtoB(*((type*)data)); \
			memcpy(data, &converted, length); \
		}
	
	swapIf(@"s", int16_t, EndianS16_NtoB, EndianS16_BtoN)
	else swapIf(@"S", uint16_t, EndianU16_NtoB, EndianU16_BtoN)
	else swapIf(@"i", int32_t, EndianS32_NtoB, EndianS32_BtoN)
	else swapIf(@"I", uint32_t, EndianU32_NtoB, EndianU32_BtoN)
	else swapIf(@"q", int64_t, EndianS64_NtoB, EndianS64_BtoN)
	else swapIf(@"Q", uint64_t, EndianU64_NtoB, EndianU64_BtoN)
	#undef swapIf
}

@implementation NSObject (APAccessors)
-(NSInvocation*)ap_setterForKey:(NSString*)name;
{
	NSString *setterName = [NSString stringWithFormat:@"set%@%@:", [[name substringToIndex:1] uppercaseString], [name substringFromIndex:1]];
	SEL setter = NSSelectorFromString(setterName);
	NSMethodSignature *sig = [self methodSignatureForSelector:setter];	
	NSInvocation *ivc = [NSInvocation invocationWithMethodSignature:sig];
	[ivc setTarget:self];
	[ivc setSelector:setter];
	return ivc;
}
-(NSInvocation*)ap_getterForKey:(NSString*)name;
{
	SEL getter = NSSelectorFromString(name);
	NSMethodSignature *sig = [self methodSignatureForSelector:getter];
	NSInvocation *ivc = [NSInvocation invocationWithMethodSignature:sig];
	[ivc setTarget:self];
	[ivc setSelector:getter];
	return ivc;
}
@end
