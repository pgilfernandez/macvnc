#pragma once

#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct macvnc_options_t
{
	int port;               /* TCP port to listen on */
	const char* password;   /* optional VNC password, nullptr for none */
	bool view_only;         /* disallow input events */
	bool prevent_dimming;   /* keep display from dimming */
	bool prevent_sleep;     /* keep machine awake */
	int display;            /* display index, -1 for primary */
} macvnc_options_t;

void macvnc_default_options( macvnc_options_t* options );
bool macvnc_start( const macvnc_options_t* options, char* error_buffer, size_t error_buffer_size );
bool macvnc_is_running( void );
void macvnc_stop( void );
void macvnc_get_last_error( char* buffer, size_t buffer_size );

#ifdef __cplusplus
}
#endif
