#import <Foundation/Foundation.h>
#import <CoreServices/CoreServices.h>
#import "AsyncSocket.h"
#import "MinecraftClient.h"





@interface asdf : NSObject {
	APProtoTalker *_talker;
}
@end
@implementation asdf
- (void)onSocket:(AsyncSocket *)sock didAcceptNewSocket:(AsyncSocket *)newSocket;
{
	NSLog(@"Accepted");
	
	/*struct {
		uint8_t type; uint32_t pv; uint16_t ul; char u[12]; uint16_t pl; char p[21]; uint64_t ms; uint8_t d;
	} __attribute__((__packed__)) data0 = {0x01, 
		EndianU32_NtoB(5), 
		EndianU16_NtoB(12), "Nev's server", 
		EndianU16_NtoB(21), "Welcome! To zombocom!", 
		EndianU64_NtoB(12345),
		2
	};
	NSData *data = [NSData dataWithBytes:&data0 length:sizeof(data0)];
	[newSocket writeData:data withTimeout:-1 tag:0];*/
	
	_talker = [[APProtoTalker alloc] initWithSocket:newSocket receivedMessageFactory:&MinecraftMessageFactoryCS];
	_talker.delegate = self;
}
-(void)protoTalker:talker receivedMessage:(APMessage*)message;
{
	NSLog(@"Server got unhandled message: %@", message);
}
-(void)protoTalker:talker receivedCSHandshake:(CSHandshake*)request;
{
	SCHandshake *response = [SCHandshake new];
	response.connectionHash = @"+";
	[talker sendMessage:response];
}
-(void)protoTalker:talker sentMessage:(APMessage*)message;
{
	NSLog(@"Server sent a message: %@", message);
	[message release];
}
@end



int main (int argc, const char * argv[]) {
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	AsyncSocket *server = [[AsyncSocket alloc] initWithDelegate:[asdf new]];
	[server acceptOnPort:25565 error:nil];
	
	NSLog(@"Usage: -user [name] -password [pass] -server [host]");
		
	NSError *err;
	MinecraftClient *client = [[MinecraftClient alloc] initTo:[[NSUserDefaults standardUserDefaults] stringForKey:@"server"] error:&err];
	if(!client) NSLog(@"No client :( %@", err);
	
	
	[[NSRunLoop currentRunLoop] run];
	
	
    [pool drain];
    return 0;
}
