/**************************************************************************/
/*  free_running_main_loop_delegate.mm                                    */
/**************************************************************************/
/*                         This file is part of:                          */
/*                             GODOT ENGINE                               */
/*                        https://godotengine.org                         */
/**************************************************************************/
/* Copyright (c) 2014-present Godot Engine contributors (see AUTHORS.md). */
/* Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.                  */
/*                                                                        */
/* Permission is hereby granted, free of charge, to any person obtaining  */
/* a copy of this software and associated documentation files (the        */
/* "Software"), to deal in the Software without restriction, including    */
/* without limitation the rights to use, copy, modify, merge, publish,    */
/* distribute, sublicense, and/or sell copies of the Software, and to     */
/* permit persons to whom the Software is furnished to do so, subject to  */
/* the following conditions:                                              */
/*                                                                        */
/* The above copyright notice and this permission notice shall be         */
/* included in all copies or substantial portions of the Software.        */
/*                                                                        */
/* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,        */
/* EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF     */
/* MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. */
/* IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY   */
/* CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,   */
/* TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE      */
/* SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                 */
/**************************************************************************/

#import "free_running_main_loop_delegate.h"
#import "display_server_macos.h"
#include "main/main.h"

@implementation FreerunningMainLoopDelegate {
	OS_MacOS_NSApp *os;
	DisplayServer *ds;
	DisplayServerMacOS *ds_mac;
	MainLoopRunner *main_loop;
	CFRunLoopTimerRef wait_timer;
	CFRunLoopRef run_loop;
	CFRunLoopObserverRef pre_wait_observer;
}

- (instancetype)initWithOS:(OS_MacOS_NSApp *)p_os
		withMainLoopRunner:(MainLoopRunner *)p_main_loop {
	if (self = [super init]) {
		ds = DisplayServer::get_singleton();
		ds_mac = Object::cast_to<DisplayServerMacOS>(ds);
		os = p_os;
		main_loop = p_main_loop;
		[self startMainLoop];
	}
	return self;
}

- (void)stop {
	[self shutdown];
}

- (void)shutdown {
	ERR_FAIL_COND(!pre_wait_observer);
	CFRunLoopRef loop = run_loop;
	CFRunLoopObserverRef observer = pre_wait_observer;

	pre_wait_observer = NULL;

	CFRunLoopPerformBlock(loop, kCFRunLoopCommonModes, ^{
		CFRunLoopObserverInvalidate(observer);
		CFRelease(observer);

		if (wait_timer) {
			CFRunLoopTimerInvalidate(wait_timer);
			CFRelease(wait_timer);
			wait_timer = nil;
		}
		NSLog(@"free running loop is shut down.");
	});
}

+ (BOOL)doesPlatformSupport {
	return YES;
}

- (void)addFrameDelay:(bool)p_can_draw
		wakeForEvents:(bool)p_wake_for_events {
	if (p_wake_for_events) {
		[self addDelayTimer:p_can_draw];
		return;
	}

	os->_unix_add_frame_delay(p_can_draw, p_wake_for_events);
}

- (void)addDelayTimer:(bool)p_can_draw {
	uint64_t delay = os->_unix_get_frame_delay(p_can_draw);
	if (delay == 0) {
		return;
	}

	// TODO: this is expensive
	if (wait_timer) {
		CFRunLoopTimerInvalidate(wait_timer);
		CFRelease(wait_timer);
	}

	wait_timer = CFRunLoopTimerCreateWithHandler(kCFAllocatorDefault, CFAbsoluteTimeGetCurrent() + (double(delay) / 1000000.0), 0, 0, 0,
			^(CFRunLoopTimerRef timer) {
				CFRunLoopTimerInvalidate(wait_timer);
				CFRelease(wait_timer);
				wait_timer = nil;
			});

	CFRunLoopAddTimer(run_loop, wait_timer, kCFRunLoopCommonModes);
	return;
}

- (void)startMainLoop {
	NSLog(@"starting free running main loop");

	run_loop = CFRunLoopGetCurrent();

	pre_wait_observer = CFRunLoopObserverCreateWithHandler(kCFAllocatorDefault, kCFRunLoopBeforeWaiting, true, 0, ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
		[main_loop iteration];

		if (wait_timer == nil) {
			CFRunLoopWakeUp(run_loop); // Prevent main loop from sleeping.
		}
	});

	CFRunLoopAddObserver(run_loop, pre_wait_observer, kCFRunLoopCommonModes);
	NSLog(@"freerunning loop started");
}
@end