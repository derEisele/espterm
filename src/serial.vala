/*
 * ESPTerm - GTK Serial Port Terminal for ESP8266 WiFi SoC Development
 * Copyright (C) 2016 Jeija, Florian Euchner <florian.euchner@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

/*
 * This is a generic serial port implementation in vala. It is not specific to
 * the functionality ESPTerm uses, e.g. does not implement the control signal
 * sequence that is used to get the ESP8266 into flash boot mode. See espserial.vala
 * for the specifics.
 */

extern void serial_util_custombaud(int fd, int baud);

namespace Serial {
	const uint MAX_SERPORTS = 50;
	const int RECV_BUFFER_LEN = 256;

	public errordomain Error {
		FAILED_TO_OPEN
	}

	/*** Scan filesystem for serial port devices ***/
	private List<string> scanPorts() {
		List<string> deviceNames = new List<string>();
		deviceNames.append("/dev/ttyS");
		deviceNames.append("/dev/ttyUSB");
		deviceNames.append("/dev/ttyACM");

		List<string> found = new List<string>();
		foreach (string name in deviceNames) {
			for (uint i = 0; i < MAX_SERPORTS; i++) {
				string dev = "%s%u".printf(name, i);
				if (FileUtils.test(dev, FileTest.EXISTS))
					found.append(dev);
			}
		}

		return found;
	}

	public class Port {
		/*
		 * Constructor
		 * Also applies serial port settings by calling setSettings() with supplied parameters.
		 */
		public Port(string path, int baudrate, int databits, int parity, bool twostopbits) throws Error {
			m_fd = Posix.open(path, Posix.O_RDWR | Posix.O_NOCTTY | Posix.O_NONBLOCK);
			if (m_fd < 0)
				throw new Error.FAILED_TO_OPEN(Posix.strerror(Posix.errno));

			// Make backup of current termios
			Posix.tcgetattr(m_fd, out m_tio_restore);
			m_tio_saved = true;

			// Try to get exclusive lock on serial port, throw FAILED_TO_OPEN if that fails
			if (!lockFile()) {
				Posix.close(m_fd);
				throw new Error.FAILED_TO_OPEN("Another process already uses " + path);
			}

			setSettings(baudrate, databits, parity, twostopbits);

			// Setup onReceiveBytes callback as IOChannel
			IOChannel io = new IOChannel.unix_new(m_fd);
			io.set_close_on_unref(true);
			m_src = io.add_watch_full(Priority.DEFAULT, IOCondition.IN, onReceiveBytes);

			m_connected = true;
		}

		~Port() {
			close();
		}

		public bool getConnected() {
			return m_connected;
		}

		/*
		 * Public: Close serial port and clean up
		 * close() is also automatically called by the destructor
		 * in case the serial port goes out of reference.
		 */
		public void close() {
			if (!m_connected)
				return;

			if (m_tio_saved)
				Posix.tcsetattr(m_fd, Posix.TCSADRAIN, m_tio_restore);

			Posix.tcflush(m_fd, Posix.TCOFLUSH);
			Posix.tcflush(m_fd, Posix.TCIFLUSH);

			Source.remove(m_src);
			unlockFile();
			Posix.close(m_fd);

			m_connected = false;
			onclose();
		}

		/*
		 * Public: Send raw bytes of length size
		 * Returns true if succeeded, otherwise false.
		 */
		public bool sendBytes(uint8[] bytes, size_t size) {
			if (!m_connected)
				return false;

			if (Posix.write(m_fd, bytes, size) == -1)
				return false;
			Posix.tcdrain(m_fd);

			return true;
		}

		/*
		 * Public: Change configuration of the serial port, config can be changed while
		 * port is open.
		 * 'baudrate':		Can be an arbitrary positive integer
		 * 'databits':		Can be 5, 6, 7 or 8
		 * 'parity':		Can be 0 (none), 1 (odd), 2 (even)
		 * 'twostopbits':	If true, use two stopbits instead of one
		 */
		public void setSettings(int baudrate, int databits, int parity, bool twostopbits) {
			Posix.termios tio;
			Posix.tcgetattr(m_fd, out tio);

			// Choose predefined baudrate or set custom baudrate
			switch (baudrate) {
				case 0: tio.c_cflag = Posix.B0; break;
				case 50: tio.c_cflag = Posix.B50; break;
				case 75: tio.c_cflag = Posix.B75; break;
				case 110: tio.c_cflag = Posix.B110; break;
				case 134: tio.c_cflag = Posix.B134; break;
				case 150: tio.c_cflag = Posix.B150; break;
				case 200: tio.c_cflag = Posix.B200; break;
				case 300: tio.c_cflag = Posix.B300; break;
				case 600: tio.c_cflag = Posix.B600; break;
				case 1200: tio.c_cflag = Posix.B1200; break;
				case 1800: tio.c_cflag = Posix.B1800; break;
				case 2400: tio.c_cflag = Posix.B2400; break;
				case 4800: tio.c_cflag = Posix.B4800; break;
				case 9600: tio.c_cflag = Posix.B9600; break;
				case 19200: tio.c_cflag = Posix.B19200; break;
				case 38400: tio.c_cflag = Posix.B38400; break;
				case 57600: tio.c_cflag = Posix.B57600; break;
				case 115200: tio.c_cflag = Posix.B115200; break;
				case 230400: tio.c_cflag = Posix.B230400; break;
				case 460800: tio.c_cflag = Linux.Termios.B460800; break;
				case 576000: tio.c_cflag = Linux.Termios.B576000; break;
				case 921600: tio.c_cflag = Linux.Termios.B921600; break;
				case 1000000: tio.c_cflag = Linux.Termios.B1000000; break;
				case 1152000: tio.c_cflag = Linux.Termios.B1152000; break;
				case 2000000: tio.c_cflag = Linux.Termios.B2000000; break;
				case 2500000: tio.c_cflag = Linux.Termios.B2500000; break;
				case 3000000: tio.c_cflag = Linux.Termios.B3000000; break;
				case 3500000: tio.c_cflag = Linux.Termios.B3500000; break;
				case 4000000: tio.c_cflag = Linux.Termios.B4000000; break;
				default:
					// Use baud rate aliasing
					serial_util_custombaud(m_fd, baudrate);
					tio.c_cflag |= Posix.B38400;
					break;
			}

			// Clear, then set databits:
			tio.c_cflag &= ~Posix.CSIZE;
			switch (databits) {
				case 5: tio.c_cflag |= Posix.CS5; break;
				case 6: tio.c_cflag |= Posix.CS6; break;
				case 7: tio.c_cflag |= Posix.CS7; break;
				case 8: tio.c_cflag |= Posix.CS8; break;
			}

			// Clear parity, then set even / odd if given
			tio.c_cflag &= ~(Posix.PARENB | Posix.PARODD);
			switch (parity) {
				case 1: tio.c_cflag |= Posix.PARODD | Posix.PARENB; break;
				case 2: tio.c_cflag |= Posix.PARENB; break;
				default: break;
			}

			// Set / clear second stopbit
			if (twostopbits)
				tio.c_cflag |= Posix.CSTOPB;
			else
				tio.c_cflag &= ~Posix.CSTOPB;

			// Enable hardware flow control, ignore modem lines, enable receiver
			// Ignore framing / parity errors, ignore break conditions
			// clear oflag (no output processing), set noncanonical mode settings
			// (no timer, get notified every 1 received character)
			tio.c_cflag |= Posix.CLOCAL | Posix.CREAD;
			tio.c_iflag = Posix.IGNPAR | Posix.IGNBRK;
			tio.c_oflag = 0;
			tio.c_lflag = 0;
			tio.c_cc[Posix.VTIME] = 0;
			tio.c_cc[Posix.VMIN] = 1;

			Posix.tcsetattr(m_fd, Posix.TCSADRAIN, tio);

			Posix.tcflush(m_fd, Posix.TCOFLUSH);
			Posix.tcflush(m_fd, Posix.TCIFLUSH);
		}

		/*
		 * Public DTR / RTS signal control functions
		 * A 'false' state translates to a high voltage at the pin,
		 * 'true' is 0V at the pin.
		 */
		public void setDTR(bool state) {
			int sig;
			Linux.ioctl(m_fd, Linux.Termios.TIOCMGET, out sig);
			if (state)
				sig |= Linux.Termios.TIOCM_DTR;
			else
				sig &= ~Linux.Termios.TIOCM_DTR;
			Linux.ioctl(m_fd, Linux.Termios.TIOCMSET, out sig);
		}

		public void setRTS(bool state) {
			int sig;
			Linux.ioctl(m_fd, Linux.Termios.TIOCMGET, out sig);
			if (state)
				sig |= Linux.Termios.TIOCM_RTS;
			else
				sig &= ~Linux.Termios.TIOCM_RTS;
			Linux.ioctl(m_fd, Linux.Termios.TIOCMSET, out sig);
		}

		public bool getDTR() {
			uint sig;
			Linux.ioctl(m_fd, Linux.Termios.TIOCMGET, out sig);
			return (sig & Linux.Termios.TIOCM_DTR) != 0;
		}

		public bool getRTS() {
			uint sig;
			Linux.ioctl(m_fd, Linux.Termios.TIOCMGET, out sig);
			return (sig & Linux.Termios.TIOCM_RTS) != 0;
		}

		/*
		 * Public signals:
		 * 'receive' fires when new data was recieved from serial port
		 * 'onclose' fires when port is manually closed by calling close()
		 * 		or if port is closed because serial device was removed
		 */
		public signal void receive(uint8[] data, int len);
		public signal void onclose();

		/* 
		 * Internal: File Locking / Unlocking
		 * Make sure that no other process also wants to use this
		 * serial port at the same time.
		 */
		private bool lockFile() {
			m_lock = Posix.Flock();
			m_lock.l_type = Posix.F_WRLCK;
			m_lock.l_whence = Posix.SEEK_SET;
			m_lock.l_start = 0;
			m_lock.l_len = 0;

			return (Posix.fcntl(m_fd, Posix.F_SETLK, m_lock) != -1);
		}

		private void unlockFile() {
			m_lock.l_type = Posix.F_UNLCK;
			m_lock.l_whence = Posix.SEEK_SET;
			m_lock.l_start = 0;
			m_lock.l_len = 0;
			Posix.fcntl(m_fd, Posix.F_SETLK, m_lock);
		}

		/*
		 * Internal: Handler for input data from serial port.
		 * Must close port when port was unexpectedly removed.
		 * Therefore, check if file descriptor is still valid
		 * (serial device has not just been unplugged).
		 */
		private bool onReceiveBytes(IOChannel src, IOCondition condition) {
			Posix.Stat s;
			Posix.fstat(m_fd, out s);
			if (s.st_nlink < 1) {
				close();
				return Source.REMOVE;
			}

			uint8[] input = {};
			int totlen = 0;

			int len = 0;
			uint8[] recv_buf = new uint8[RECV_BUFFER_LEN];

			do {
				len = (int)Posix.read(m_fd, recv_buf, RECV_BUFFER_LEN);

				if (len > 0) {
					for (uint i = 0; i < len; ++i)
						input += recv_buf[i];
					totlen += len;
				} else if (len == -1) {
					warning("onReceiveBytes: Posix.read failed: " + Posix.strerror(Posix.errno));
				}
			} while (len == RECV_BUFFER_LEN);

			receive(input, totlen);

			return Source.CONTINUE;
		}

		/*** Private variables ***/
		private int m_fd;
		private Posix.Flock m_lock;
		private bool m_connected = false;

		// Delete input data receive callback when closing port
		private uint m_src;

		// Save serial port configuration before opening and restore when closing
		private Posix.termios m_tio_restore;
		private bool m_tio_saved;
	}
}
