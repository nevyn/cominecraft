#import <Foundation/Foundation.h>
#import <CoreServices/CoreServices.h>
#import "AsyncSocket.h"
#import "MinecraftClient.h"





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
	
	NSError *err;
	MinecraftClient *client = [[MinecraftClient alloc] initTo:@"localhost" error:&err];
	if(!client) NSLog(@"No client :( %@", err);
	
	
	[[NSRunLoop currentRunLoop] run];
	
	
    [pool drain];
    return 0;
}
