#import "MinecraftClient.h"

@implementation MinecraftClient
@synthesize hostToConnectTo, sessionId, sessionIdRequest, serverJoinRequest;
-(id)initTo:(NSString*)host error:(NSError**)err;
{
	sck = [[AsyncSocket alloc] initWithDelegate:self];
	self.hostToConnectTo = host;
	
	self.sessionIdRequest = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://www.minecraft.net/game/getversion.jsp?user=%@&password=%@&version=%d",
		[[NSUserDefaults standardUserDefaults] stringForKey:@"user"],
		[[NSUserDefaults standardUserDefaults] stringForKey:@"password"],
		17
	]]];
	[self.sessionIdRequest setDelegate:self];
	[self.sessionIdRequest startAsynchronous];
	
	return self;
}
-(void)dealloc;
{
	self.hostToConnectTo = self.sessionIdRequest = self.serverJoinRequest = self.sessionId = nil;
	[sck release];
	[_talker release];
	[super dealloc];
}

-(void)requestFinished:(ASIHTTPRequest*)req;
{
	if(req == self.sessionIdRequest) {
		NSArray *parts = [[req responseString] componentsSeparatedByString:@":"];
		if([parts count] < 4) {
			NSLog(@"Failed session id request: %@", [req responseString]);
			return;
		}
		self.sessionId = [parts objectAtIndex:3];
		
		self.sessionIdRequest = nil;
		
		NSError *err;
		if(![sck connectToHost:self.hostToConnectTo onPort:25565 error:&err])
			NSLog(@"Couldn't connect to host: %@", err);
	} else if(req == self.serverJoinRequest) {
		if(![[[req responseString] lowercaseString] isEqual:@"ok"]) {
			NSLog(@"Wasn't allowed to log in :( %@", [req responseString]);
			return;
		}
		CSLoginRequest *request = [CSLoginRequest new];
		request.dimension = 0;
		request.mapSeed = 1234;
		request.username = @"nevyn";
		request.password = @"";
		request.protocolVersion = 4;
		[_talker sendMessage:request];
		
		self.serverJoinRequest = nil;
		
		CSChatMessage *msg = [CSChatMessage new];
		msg.message = @"omg spam spam spam :D";
		
		[_talker performSelector:@selector(sendMessage:) withObject:msg afterDelay:1.0];
	}
}

- (void)onSocket:(AsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port;
{
	_talker = [[APProtoTalker alloc] initWithSocket:sck receivedMessageFactory:&MinecraftMessageFactorySC];
	_talker.delegate = self;
	
	CSHandshake *handshake = [CSHandshake new];
	handshake.username = [[NSUserDefaults standardUserDefaults] stringForKey:@"user"];
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
		NSLog(@"WARNING: Password protected server");
	}
	if([handshake.connectionHash isEqual:@"-"]) {
		NSLog(@"Hmm, no hash.");
	}
	
	NSLog(@"OMG!! We got a connection hash! %@", handshake.connectionHash);
	
	self.serverJoinRequest = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://www.minecraft.net/game/joinserver.jsp?user=%@&sessionId=%@&serverId=%@",
		@"nevyn",
		self.sessionId,
		handshake.connectionHash
	]]];
	[self.serverJoinRequest setDelegate:self];
	[self.serverJoinRequest startAsynchronous];
}

-(void)protoTalker:talker sentMessage:(APMessage*)message;
{
	NSLog(@"Client sent a message: %@", message);
	[message release];
}
@end
