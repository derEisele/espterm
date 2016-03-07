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

namespace ESPSerial {
	public class Port : Serial.Port {
		/*
		 * Same as Serial.Port, but makes some sane configuration
		 * assumptions and performs DTR / RTS sequency to get
		 * ESP8266 to boot by calling rebootESP8266()
		 */
		public Port(string path, int baudrate, int databits, int parity, bool twostopbits) throws Serial.Error {
			base(path, baudrate, databits, parity, twostopbits);
			rebootESP8266();
		}

		/*
		 * Public signals:
		 * 'onbootcfg' fires when boot config pin (DTR) was set false
		 * 'onboot' fires when ESP8266 is started by setting RTS to false
		 */
		public signal void onbootcfg();
		public signal void onboot();

		/*
		 * Use DTR / RTS data lines to get ESP8266 in flash boot mode
		 * Connect RTS to CH_PD and DTR to GPIO0
		 * This is compatible with the pin configuration of esptool.py
		 */
		private void rebootESP8266() {
			// First set both DTR and RTS true = logic low level voltage
			setDTR(true);
			setRTS(true);

			// After 100ms set DTR false = logic high level voltage
			// Enables normal boot operation from flash
			TimeoutSource bootcfg = new TimeoutSource(100);
			bootcfg.set_callback (() => {
				if (!getConnected())
					return Source.REMOVE;

				onbootcfg();
				setDTR(false);
				return Source.REMOVE;
			});
			bootcfg.attach(null);

			// After 300ms set RTS false = logic high level voltage
			// Starts up ESP8266
			TimeoutSource startesp = new TimeoutSource(300);
			startesp.set_callback (() => {
				if (!getConnected())
					return Source.REMOVE;

				onboot();
				setRTS(false);
				return Source.REMOVE;
			});
			startesp.attach(null);
		}
	}
}
