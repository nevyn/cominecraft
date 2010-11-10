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


#pragma mark 
#pragma mark Infrastructure
#pragma mark -

@implementation APMessage
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
-(id)initWithSocket:(AsyncSocket*)sock messageFactory:(APMessageFactory)factory_;
{
	sck = [sock retain];
	sck.delegate = self;
	factory = factory_;
	
	[sck readDataToLength:sizeof(uint8_t) withTimeout:-1 tag:0];
	
	return self;
}
- (void)onSocket:(AsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
	uint8_t packet = *(uint8_t*)[data bytes];
	
	APMessage *msg = [[[factory(packet) alloc] init] autorelease];
	[[APMessageReader alloc] initWithMessage:msg fromSocket:sck whenDone:self];
}
- (void)onSocket:(AsyncSocket *)sock willDisconnectWithError:(NSError *)err;
{
	[delegate onSocket:sock willDisconnectWithError:err];
}
-(void)messageReader:(id)reader doneReadingMessage:(APMessage*)msg;
{
	sck.delegate = self;
	[delegate protoTalker:self receivedMessage:msg];
	[reader release];
	[sck readDataToLength:sizeof(uint8_t) withTimeout:-1 tag:0];
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
	NSString *name = [NSString stringWithUTF8String:property_getName(prop)];
	
	int length = 0;
	if([[typeEncoding uppercaseString] isEqual:@"C"]) length = 1;
	else if([[typeEncoding uppercaseString] isEqual:@"S"]) length = 2;
	else if([[typeEncoding uppercaseString] isEqual:@"I"]) length = 4;
	else if([typeEncoding isEqual:@"f"]) length = 4;
	else if([[typeEncoding uppercaseString] isEqual:@"Q"]) length = 8;
	else if([typeEncoding isEqual:@"d"]) length = 8;
	else if([typeEncoding hasPrefix:@"@"]) {
		NSString *className = [typeEncoding substringFromIndex:2];
		className = [className substringToIndex:[className rangeOfString:@"\""].location];
		NSString *readerClassName = [@"APReader" stringByAppendingString:className];
		Class readerClass = NSClassFromString(readerClassName);
		if(!readerClass) [NSException raise:NSInvalidArgumentException format:@"No APReader for property %@ of class %@", name, className];
		
		[[readerClass alloc] initReadingField:field ofMessage:message fromSocket:sck delegate:self];
		return;
	} else [NSException raise:NSInvalidArgumentException format:@"Unknown type encoding %@ for prop %@", typeEncoding, name];
		
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

-(void)tellDelegateWeAreDoneOnSocket:(AsyncSocket*)sck;
{
	sck.delegate = delegate;

	[delegate messageReader:self doneReadingMessage:message];
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
- (void)onSocket:(AsyncSocket *)sock didReadData:(NSData *)nsdata withTag:(long)tag
{
	if(tag == ReadingLength) {
		uint16_t len;
		memcpy(&len, [nsdata bytes], 2);
		len = EndianU16_BtoN(len);
		[sock readDataToLength:len withTimeout:-1 tag:ReadingData];
	} else if(tag == ReadingData) {
		NSString *s = [[[NSString alloc] initWithData:nsdata encoding:NSUTF8StringEncoding] autorelease];
		[self notifyDelegateObjectWasRead:s fromSocket:sock];
	}
}
@end

#pragma mark 
#pragma mark Helpers
#pragma mark -

NSString *APTypeEncodingInPropertyAttribs(NSString *attrs)
{
	return [attrs substringWithRange:NSMakeRange(1, [attrs rangeOfString:@","].location-1)];
}
