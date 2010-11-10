#import "MinecraftClient.h"

@implementation MinecraftClient
-(id)initTo:(NSString*)host error:(NSError**)err;
{
	sck = [[AsyncSocket alloc] initWithDelegate:self];
	if(![sck connectToHost:host onPort:25565 error:err]) {
		[self release];
		return nil;
	}
	return self;
}
-(void)dealloc;
{
	[sck release];
	[_talker release];
	[super dealloc];
}
- (void)onSocket:(AsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port;
{
	_talker = [[APProtoTalker alloc] initWithSocket:sck receivedMessageFactory:&MinecraftMessageFactorySC];
	_talker.delegate = self;
	
	CSHandshake *handshake = [CSHandshake new];
	handshake.username = @"nevyn";
	[_talker sendMessage:handshake];
}
-(void)onSocket:(AsyncSocket *)sock willDisconnectWithError:(NSError *)err;
{
	NSLog(@"Client got kicked off :( %@", err);
}

-(void)protoTalker:talker receivedMessage:(APMessage*)message;
{
	NSLog(@"Client got unhandled message: %@", message);
}
-(void)protoTalker:talker receivedSCHandshake:(SCHandshake*)handshake;
{
	if([handshake.connectionHash isEqual:@"+"]) {
		CSLoginRequest *request = [CSLoginRequest new];
		request.dimension = 0;
		request.mapSeed = 1234;
		request.username = @"nevyn";
		request.password = @"1234";
		request.protocolVersion = 3;
		[talker sendMessage:request];
	} else {
		NSLog(@"OMG!! We got a connection hash! %@", handshake.connectionHash);
	}

}

-(void)protoTalker:talker sentMessage:(APMessage*)message;
{
	NSLog(@"Client sent a message: %@", message);
	[message release];
}
@end
