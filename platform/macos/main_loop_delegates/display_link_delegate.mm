/**************************************************************************/
/*  display_link_delegate.mm                                              */
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

#import "display_link_delegate.h"

#import "display_server_macos.h"
#include "main/main.h"
#import "os_macos.h"
#import <QuartzCore/CADisplayLink.h>

@implementation DisplaylinkMainLoopHandlerDelegate {
	OS_MacOS_NSApp *os;
	GodotWindow *window;
	DisplayServer *ds;
	DisplayServerMacOS *ds_mac;
	MainLoopRunner *main_loop;
	CADisplayLink *display_link API_AVAILABLE(macos(14.0));
}

- (instancetype)initWithOS:(OS_MacOS_NSApp *)p_os
		withMainLoopRunner:(MainLoopRunner *)p_main_loop {
	if (self = [super init]) {
		os = p_os;
		ds = DisplayServer::get_singleton();
		ds_mac = Object::cast_to<DisplayServerMacOS>(ds);
		main_loop = p_main_loop;

		ERR_FAIL_COND_V(!ds_mac->has_window(DisplayServer::MAIN_WINDOW_ID), nil);

		window = ds_mac->get_window(DisplayServer::MAIN_WINDOW_ID).window_object;

		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(windowFocusDidChange:)
													 name:NSWindowDidBecomeMainNotification
												   object:window];

		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(windowFocusDidChange:)
													 name:NSWindowDidResignMainNotification
												   object:window];

		[self startMainLoop];
	}
	return self;
}

- (void)stop {
	[display_link invalidate];
	display_link = nil;
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)windowFocusDidChange:(NSNotification *)notification {
	ERR_FAIL_COND(!display_link);

	if ([notification.name isEqualToString:NSWindowDidResignMainNotification]) {
		[self setLowPowerMode];
	} else {
		[self setNormalPowerMode];
	}
}

- (void)addFrameDelay:(bool)p_can_draw
		wakeForEvents:(bool)p_wake_for_events {
	// this is a nop since we are using CADisplayLink
}

- (void)startMainLoop {
	NSLog(@"starting display link");

	display_link = [window displayLinkWithTarget:self selector:@selector(iteration:)];

	ERR_FAIL_COND(!display_link);

	[self setNormalPowerMode];
	[display_link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];

	NSLog(@"display link started");
}

- (void)iteration:(CADisplayLink *)sender API_AVAILABLE(macos(14.0)) {
	[main_loop iteration];
}

+ (BOOL)doesPlatformSupport {
	if (@available(macOS 14.0, *)) {
		return YES;
	} else {
		return NO;
	}
}

- (void)setLowPowerMode {
	NSLog(@"set low power mode");
	// TODO: set these to some reasonable value
	[self setFrameRateRangeWithMin:5.0 max:10.0 preferred:8.0];
}

- (void)setNormalPowerMode {
	NSLog(@"set normal power mode");
	// TODO: set these to some reasonable value
	[self setFrameRateRangeWithMin:30.0 max:60.0 preferred:60.0];
}

- (void)setFrameRateRangeWithMin:(float)minFPS
							 max:(float)maxFPS
					   preferred:(float)preferredFPS {
	if (!display_link) {
		return;
	}

	if (@available(macOS 14.0, *)) {
		display_link.preferredFrameRateRange = CAFrameRateRangeMake(minFPS, maxFPS, preferredFPS);
	}
}

- (void)dealloc {
	NSLog(@"dealloc displaylink");
}
@end
