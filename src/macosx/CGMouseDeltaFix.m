/*
===========================================================================

Return to Castle Wolfenstein multiplayer GPL Source Code
Copyright (C) 1999-2010 id Software LLC, a ZeniMax Media company. 

This file is part of the Return to Castle Wolfenstein multiplayer GPL Source Code (RTCW MP Source Code).  

RTCW MP Source Code is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

RTCW MP Source Code is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with RTCW MP Source Code.  If not, see <http://www.gnu.org/licenses/>.

In addition, the RTCW MP Source Code is also subject to certain additional terms. You should have received a copy of these additional terms immediately following the terms and conditions of the GNU General Public License which accompanied the RTCW MP Source Code.  If not, please request a copy in writing from id Software at the address below.

If you have questions concerning this license or the applicable additional terms, you may contact in writing id Software LLC, c/o ZeniMax Media Inc., Suite 120, Rockville, Maryland 20850 USA.

===========================================================================
*/

#import "CGMouseDeltaFix.h"
#import "CGPrivateAPI.h"

#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>


// We will try to automatically fall back to using the original CGGetLastMouseDelta when we are on a system new enough to have the fix.  Any version of CoreGraphics past 1.93.0 will have the fixed version.


static BOOL originalVersionShouldWork = YES;
static CGMouseDelta CGFix_Mouse_DeltaX, CGFix_Mouse_DeltaY;

static void CGFix_NotificationCallback( CGSNotificationType note, CGSNotificationData data, CGSByteCount dataLength, CGSNotificationArg arg );

static CGSRegisterNotifyProcType registerNotifyProc = NULL;

void CGFix_Initialize() {
	NSAutoreleasePool *pool;
	NSBundle *cgBundle;
	NSString *version;
	NSArray *components;

	if ( registerNotifyProc ) {
		// We've already been called once and have registered our callbacks.  If the original version works, this will be NULL, but we'll end up doing nothing (again, possibly).
		return;
	}

	//NSLog(@"CGFix_Initialize\n");

	pool = [[NSAutoreleasePool alloc] init];
	cgBundle = [NSBundle bundleWithPath: @ "/System/Library/Frameworks/ApplicationServices.framework/Frameworks/CoreGraphics.framework"];
	if ( !cgBundle ) {
		// If it's moved, it must be newer than what we know about and should work
		//NSLog(@"No /System/Library/Frameworks/ApplicationServices.framework/Frameworks/CoreGraphics.framework\n");
		goto done;
	}

	version = [[cgBundle infoDictionary] objectForKey: @ "CFBundleShortVersionString"];
	components = [version componentsSeparatedByString: @ "."];
	//NSLog(@"version = %@\n", version);
	//NSLog(@"components = %@\n", components);


	if ([components count] < 2 ) {
		// We don't understand this versioning scheme.  Must have changed.
		goto done;
	}

	if ( ![[components objectAtIndex : 0] isEqualToString : @ "1"] || [[components objectAtIndex : 1] intValue] > 93 ) {
		// This version should be new enough to work
		goto done;
	}

	// Look up the function pointer we need to register our callback.
	if ( !NSIsSymbolNameDefined( "_CGSRegisterNotifyProc" ) ) {
		//NSLog(@"No _CGSRegisterNotifyProc\n");
		goto done;
	}

	registerNotifyProc = NSAddressOfSymbol( NSLookupAndBindSymbol( "_CGSRegisterNotifyProc" ) );
	//NSLog(@"registerNotifyProc = 0x%08x", registerNotifyProc);

	// Must not work if we got here
	originalVersionShouldWork = NO;

	// We want to catch all the events that could possible indicate mouse movement and sum them up
	registerNotifyProc( CGFix_NotificationCallback, kCGSEventNotificationMouseMoved, NULL );
	registerNotifyProc( CGFix_NotificationCallback, kCGSEventNotificationLeftMouseDragged, NULL );
	registerNotifyProc( CGFix_NotificationCallback, kCGSEventNotificationRightMouseDragged, NULL );
	registerNotifyProc( CGFix_NotificationCallback, kCGSEventNotificationNotificationOtherMouseDragged, NULL );

done:
	[pool release];
}

void CGFix_GetLastMouseDelta( CGMouseDelta *dx, CGMouseDelta *dy ) {
	if ( originalVersionShouldWork ) {
		CGGetLastMouseDelta( dx, dy );
		return;
	}

	*dx = CGFix_Mouse_DeltaX;
	*dy = CGFix_Mouse_DeltaY;

	CGFix_Mouse_DeltaX = CGFix_Mouse_DeltaY = 0;
}

static void CGFix_NotificationCallback( CGSNotificationType note, CGSNotificationData data, CGSByteCount dataLength, CGSNotificationArg arg ) {
	CGSEventRecordPtr event;

	//fprintf(stderr, "CGFix_NotificationCallback(note=%d, date=0x%08x, dataLength=%d, arg=0x%08x)\n", note, data, dataLength, arg);

#ifdef DEBUG
	if ( ( note != kCGSEventNotificationMouseMoved &&
		   note != kCGSEventNotificationLeftMouseDragged &&
		   note != kCGSEventNotificationRightMouseDragged &&
		   note != kCGSEventNotificationNotificationOtherMouseDragged ) ||
		 dataLength != sizeof( CGSEventRecord ) ) {
		fprintf( stderr, "Unexpected arguments to callback function CGFix_NotificationCallback(note=%d, date=0x%08x, dataLength=%d, arg=0x%08x)\n", note, data, dataLength, arg );
	}
	abort();
}
#endif

	event = (CGSEventRecordPtr)data;

	CGFix_Mouse_DeltaX += event->data.move.deltaX;
	CGFix_Mouse_DeltaY += event->data.move.deltaY;
	//fprintf(stderr, "  dx += %d, dy += %d\n", event->data.move.deltaX, event->data.move.deltaY);
}
