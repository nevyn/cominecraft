#import "MinecraftClient.h"

@implementation MinecraftClient
-(id)initTo:(NSString*)host error:(NSError**)err;
{
	sck = [[AsyncSocket alloc] initWithDelegate:self];
	if(![sck connectToHost:host onPort:1234 error:err]) {
		[self release];
		return nil;
	}
	return self;
}
-(void)dealloc;
{
	[sck release];
	[talker release];
	[super dealloc];
}
- (void)onSocket:(AsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port;
{
	talker = [[APProtoTalker alloc] initWithSocket:sck messageFactory:&MinecraftMessageFactory];
	talker.delegate = self;
}
-(void)protoTalker:talker receivedMessage:(APMessage*)message;
{
	NSLog(@"Got a message: %@", message);
}
-(void)protoTalker:talker sentMessage:(APMessage*)message;
{
	NSLog(@"Sent a message: %@", message);
}
@end
