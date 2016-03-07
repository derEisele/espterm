// System
#include "ets_sys.h"
#include "osapi.h"
#include "gpio.h"
#include "os_type.h"
#include "user_interface.h"

// Configuration
#include "user_config.h"

os_timer_t info_timer;

int count = 0;
void ICACHE_FLASH_ATTR info_timer_cb() {
	os_printf("Counting: %i\r\n", count++);
}

void ICACHE_FLASH_ATTR user_init(void)
{
	uart_div_modify(0, UART_CLK_FREQ / BAUD);
	os_printf("ESP8266 starting up with baudrate %d\r\n", BAUD);

	os_timer_setfn(&info_timer, (os_timer_func_t *)info_timer_cb, NULL);
	os_timer_arm(&info_timer, 200, 1);
}
