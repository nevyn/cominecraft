#import <Foundation/Foundation.h>
#import <CoreServices/CoreServices.h>
#import "AsyncSocket.h"
#import "MinecraftClient.h"


int main (int argc, const char * argv[]) {
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	NSLog(@"Usage: -user [name] -password [pass] -server [host]");
		
	NSError *err;
	MinecraftClient *client = [[MinecraftClient alloc] initTo:[[NSUserDefaults standardUserDefaults] stringForKey:@"server"] error:&err];
	if(!client) NSLog(@"No client :( %@", err);
	
	
	[[NSRunLoop currentRunLoop] run];
	
	
    [pool drain];
    return 0;
}
