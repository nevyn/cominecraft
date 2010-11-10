#import <Foundation/Foundation.h>
#import "AsyncSocket.h"

#pragma mark Infrastructure

// Synthesizes -[dealloc] and -[description]
@interface APMessage : NSObject
@end


typedef Class(*APMessageFactory)(uint8_t packetId);

@protocol APProtoTalkerDelegate /*<AsyncSocketDelegate>*/
// May also implement protoTalker:received[MessageName]:
-(void)protoTalker:talker receivedMessage:(APMessage*)message;
-(void)protoTalker:talker sentMessage:(APMessage*)message;
@end

@interface APProtoTalker : NSObject
{
	id delegate;
	AsyncSocket *sck;
	APMessageFactory factory;
}
@property (assign) id delegate;
-(id)initWithSocket:(AsyncSocket*)sck messageFactory:(APMessageFactory)factory;
//-(void)sendMessage:(APMessage*)msg;
@end






@protocol APMessagePartReaderDelegate /*<AsyncSocketDelegate>*/
-(void)partReader:reader
	   readObject:obj 
		 forField:(int)field
		ofMessage:(APMessage*)msg
		 onSocket:(AsyncSocket*)sck;
@end

@interface APMessagePartReaderBase : NSObject {
	id delegate;
	int field;
	APMessage *msg;
}
@property (readonly, retain) APMessage *msg;
@property (readonly) int field;
-(id)initReadingField:(int)field
			ofMessage:(APMessage*)msg 
		   fromSocket:(AsyncSocket*)sck
			 delegate:delegate;
// for subclasses to call. Returns socket control to delegate.
-(void)notifyDelegateObjectWasRead:obj fromSocket:(AsyncSocket*)sck;
@end





#pragma mark 
#pragma mark Base implementations
@interface APReaderNSString : APMessagePartReaderBase 
-(id)initReadingField:(int)field
			ofMessage:(APMessage*)msg 
		   fromSocket:(AsyncSocket*)sck
			 delegate:delegate;
@end


#pragma mark 
#pragma mark Helpers
NSString *APTypeEncodingInPropertyAttribs(NSString *attrs);