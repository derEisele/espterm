#include <linux/serial.h>
#include <sys/ioctl.h>
#include <stdio.h>

void serial_util_custombaud(int fd, int baud)
{
	struct serial_struct port;

	ioctl(fd, TIOCGSERIAL, &port);
	port.custom_divisor = (port.baud_base + (baud / 2)) / baud;
	if (port.custom_divisor == 0)
		port.custom_divisor = 1;

	port.flags &= ~ASYNC_SPD_MASK;
	port.flags |= ASYNC_SPD_CUST;

	printf("Using arbitrary baudrate, closest rate is %i \n", port.baud_base / port.custom_divisor);

	ioctl(fd, TIOCSSERIAL, &port);
}
