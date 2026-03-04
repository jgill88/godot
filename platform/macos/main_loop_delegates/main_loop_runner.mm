/**************************************************************************/
/*  main_loop_runner.mm                                   	  			  */
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

#ifdef SDL_ENABLED
#include "drivers/sdl/joypad_sdl.h"
#endif

#import "display_server_macos.h"
#include "main/main.h"
#import "main_loop_delegates/display_link_delegate.h"
#import "main_loop_delegates/free_running_main_loop_delegate.h"
#import "main_loop_runner.h"
#import "os_macos.h"

#ifdef SDL_ENABLED
class JoypadSDL;
#endif

@implementation MainLoopRunner {
	DisplayServer *ds;
	DisplayServerMacOS *ds_mac;
	OS_MacOS_NSApp *os;
	bool *should_terminate;
	id<MainLoopHandlerDelegate> __strong delegate;

#ifdef SDL_ENABLED
	JoypadSDL *joypad_sdl;
#endif
}

- (instancetype)initWithOS:(OS_MacOS_NSApp *)p_os
		 withDisplayServer:(DisplayServer *)p_ds
		   shouldTerminate:(bool *)p_should_terminate
#ifdef SDL_ENABLED
				withJoypad:(JoypadSDL *)p_joypad_sdl
#endif
{
	if (self = [super init]) {
		os = p_os;
		ds = p_ds;
		should_terminate = p_should_terminate;
		ds_mac = Object::cast_to<DisplayServerMacOS>(ds);
#ifdef SDL_ENABLED
		joypad_sdl = p_joypad_sdl;
#endif

		if (![self createMainLoop]) {
			return nil;
		}
	}
	return self;
}

- (bool)createMainLoop {
	if (delegate) {
		NSLog(@"re-creating main loop delegate");
		[delegate stop];
		delegate = nil;
	} else {
		NSLog(@"creating main loop delegate");
	}

	if (ds->window_get_vsync_mode(DisplayServer::MAIN_WINDOW_ID) == DisplayServer::VSyncMode::VSYNC_ENABLED) {
		if ([DisplaylinkMainLoopHandlerDelegate doesPlatformSupport]) {
			delegate = [[DisplaylinkMainLoopHandlerDelegate alloc]
							initWithOS:os
					withMainLoopRunner:self];
		}
	}

	// fallback
	if (!delegate) {
		delegate = [[FreerunningMainLoopDelegate alloc]
						initWithOS:os
				withMainLoopRunner:self];
	}

	return !!delegate;
}

- (void)addFrameDelay:(bool)p_can_draw
		wakeForEvents:(bool)p_wake_for_events {
	if (delegate) {
		[delegate addFrameDelay:p_can_draw wakeForEvents:p_wake_for_events];
	}
}

- (void)iteration {
	@autoreleasepool {
		@try {
			if (ds_mac) {
				ds_mac->_process_events(false);
			} else if (ds) {
				ds->process_events();
			}

#ifdef SDL_ENABLED
			if (joypad_sdl) {
				joypad_sdl->process_events();
			}
#endif
			bool should_quit = Main::iteration();

			if (should_quit || *should_terminate) {
				os->_terminate();
			}
		} @catch (NSException *exception) {
			ERR_PRINT("NSException: " + String::utf8([exception reason].UTF8String));
		}
	}
}
@end
