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

[GtkTemplate (ui = "/org/gtk/espterm/mainwindow.ui")]
public class App : Gtk.Window {
	const string FLASH_COMMAND = "make flash";
	const int FLASH_BUF_LEN = 1024;

	public App() {
		// Generate and add new VTE Terminal
		m_term = new Vte.Terminal();

		m_term.set_color_foreground({1, 1, 1, 1});
		m_term.set_color_highlight({1, 1, 1, 1});
		m_term.set_color_highlight_foreground({0, 0, 0, 0});
		vte_container.add(m_term);

		// Scan Serial Ports and display them
		updatePorts();

		// Setup keyboard shortcuts, modify switch to activate callbacks
		// for toggling serial port connection
		// F5 = flash, F6 = connect, F7 = disconnect, Ctrl+Shift+L = clearscreen
		// Ctrl+Shift+C = copy to clipboard, Ctrl+Shift+V = paste from clipboard
		// Ctrl+Shift+O = select project folder
		Gtk.AccelGroup accel = new Gtk.AccelGroup();
		accel.connect(Gdk.Key.F5, 0, Gtk.AccelFlags.VISIBLE, () => {
			startFlash();
			return true;
		});
		accel.connect(Gdk.Key.F6, 0, Gtk.AccelFlags.VISIBLE, () => {
			connect_switch.active = true;
			return true;
		});
		accel.connect(Gdk.Key.F7, 0, Gtk.AccelFlags.VISIBLE, () => {
			connect_switch.active = false;
			return true;
		});
		accel.connect(Gdk.Key.L, Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.SHIFT_MASK, Gtk.AccelFlags.VISIBLE, () => {
			m_term.reset(true, true);
			return true;
		});
		accel.connect(Gdk.Key.C, Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.SHIFT_MASK, Gtk.AccelFlags.VISIBLE, () => {
			m_term.copy_clipboard();
			return true;
		});
		accel.connect(Gdk.Key.V, Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.SHIFT_MASK, Gtk.AccelFlags.VISIBLE, () => {
			m_term.paste_clipboard();
			return true;
		});
		accel.connect(Gdk.Key.O, Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.SHIFT_MASK, Gtk.AccelFlags.VISIBLE, () => {
			chooseProjectFolder();
			return true;
		});
		this.add_accel_group(accel);

		// Connect events and show window
		m_term.commit.connect(onUserInput);
		this.show_all();
	}

	/*
	 * Handle keyboard input data
	 * Send through serial port if port is open, replacing
	 * \n with \r\n if CR LF mode is active.
	 */
	private void onUserInput(string text, uint size) {
		string text_owned = text;
		if (crlf_toggle.active)
			text_owned = text_owned.replace("\r", "\r\n");

		if (!m_flash_mode && m_serial_port != null)
			m_serial_port.sendBytes(text_owned.data, text_owned.length);
	}

	/*
	 * Get selected baudrate from combo box
	 * Return false if baudrate is invalid (too large, negative, not a number)
	 */
	private bool getSelectedBaud(out int baud) {
		baud = -1;

		uint64 baud64;
		if (!uint64.try_parse(baud_combo.get_active_text(), out baud64))
			return false;

		if (baud64 > int.MAX)
			return false;

		baud = (int)baud64;
		return true;
	}

	/*
	 * Open serial port with error handling
	 * Sets up callbacks for new data and other events
	 * Returns false if port could not be opened
	 */
	private bool openPort() {
		if (m_serial_port != null && m_serial_port.getConnected())
			return true;

		string port = ports_combo.get_active_text();

		// Get baudrate and handle invalid strings
		int baud;
		if (!getSelectedBaud(out baud)) {
			Gtk.MessageDialog dialog = new Gtk.MessageDialog(this, Gtk.DialogFlags.MODAL,
				Gtk.MessageType.ERROR, Gtk.ButtonsType.CLOSE, "Invalid baudrate!");

			dialog.response.connect ((res) => {
				if (res == Gtk.ResponseType.CLOSE)
					dialog.destroy();
			});

			dialog.show();
			return false;
		}

		// Clear terminal window to display port / boot status
		clearTerminal();
		printTerminalMessage("Opening " + port + "...");

		// Try to open serial port and handle errors
		try {
			m_serial_port = new ESPSerial.Port(port, baud, 8, 0, false);
		} catch (Serial.Error ex) {
			string msg = "Error opening port: " + ex.message;
			Gtk.MessageDialog dialog = new Gtk.MessageDialog(this, Gtk.DialogFlags.MODAL,
				Gtk.MessageType.ERROR, Gtk.ButtonsType.CLOSE, msg);

			dialog.response.connect ((res) => {
				if (res == Gtk.ResponseType.CLOSE)
					dialog.destroy();
			});

			dialog.show();
			return false;
		}

		// Connect serial port event signals
		m_serial_port.onbootcfg.connect(() => {
			printTerminalMessage("Flash boot mode entered...");
		});
		m_serial_port.onboot.connect(() => {
			printTerminalMessage("Starting up ESP8266...");
		});
		m_serial_port.onclose.connect(() => {
			if (m_flash_mode) return;
			printTerminalMessage("\r\nClosed " + port);
			connect_switch.active = false;
		});
		m_serial_port.receive.connect((data, len) => {
			m_term.feed(data);
		});

		return true;
	}

	/*
	 * Close Serial Port (if open)
	 */
	private void closePort() {
		if (m_serial_port != null)
			m_serial_port.close();
	}

	/*
	 * Print colored message to Terminal
	 * Feeds ANSI escape codes to VTE Terminal to set colors
	 */
	private void printTerminalMessage(string msg) {
		uint8[] setred = "\x1b[31;1m".data;
		uint8[] setwhite = "\x1b[37;0m".data;
		uint8[] newline = "\r\n".data;

		m_term.feed(setred);
		m_term.feed(msg.data);
		m_term.feed(newline);
		m_term.feed(setwhite);
	}

	/*
	 * Update serial port list combo box
	 * Grays out combo box if no serial ports were found.
	 */
	private void updatePorts() {
		List<string> ports = Serial.scanPorts();

		Gtk.ListStore store = new Gtk.ListStore(1, typeof(string));
		Gtk.TreeIter iter;

		uint active_item;

		// No ports found: Display that
		if (ports.length() == 0) {
			store.append(out iter);
			store.set(iter, 0, "No Ports Found");
			ports_combo.sensitive = false;
			active_item = 0;

		// Ports detected, add to combo box
		} else {
			ports_combo.sensitive = true;
			foreach (string p in ports) {
				store.append(out iter);
				store.set(iter, 0, p);
			}
			active_item = ports.length() - 1;
		}

		ports_combo.model = store;
		ports_combo.active = (int)active_item;
	}

	/*
	 * Choose project folder. Either triggered by pressing flash
	 * button for the first time or pressing Ctrl+O.
	 * Returns true if folder was chosen.
	 */
	private bool chooseProjectFolder() {
		Gtk.FileChooserDialog chooser = new Gtk.FileChooserDialog(
			"Select project folder", this, Gtk.FileChooserAction.SELECT_FOLDER,
			"Cancel", Gtk.ResponseType.CANCEL, "Select", Gtk.ResponseType.OK);
		chooser.set_default_response(Gtk.ResponseType.OK);

		bool success = false;
		if (chooser.run() == Gtk.ResponseType.OK) {
			m_project_folder = chooser.get_filename();
			success = true;
		}

		chooser.destroy();
		return success;
	}

	/*
	 * Gray out / activate port / baud / refresh controls
	 * at bottom of window.
	 */
	private void setSettingsSensitive(bool sensitive) {
		ports_combo.sensitive = sensitive;
		baud_combo.sensitive = sensitive;
		ports_refresh_button.sensitive = sensitive;
	}

	/*
	 * Kill flash process with SIGKILL in case it is running (SIGINT is not
	 * reliable here).
	 */
	private void killFlashProcess() {
		if (m_flash_pid != -1) {
			if (Posix.kill(m_flash_pid, Posix.SIGTERM) != 0)
				warning(Posix.strerror(Posix.errno));
			m_flash_pid = -1;

			Source.remove(m_flash_stdout_src);
			Source.remove(m_flash_stderr_src);
		}
	}

	/*
	 * Called by clicking flash download button or F5.
	 * Either close serial port connection and `make flash` or
	 * open project folder chooser dialog if no project has been
	 * chosen yet.
	 * Spawn flash process as child and not in VTE terminal with spawn_sync
	 * Vte.Terminal.spawn_sync doesn't seem to output anything if the child
	 * exits soon after starting up, therefore manually feed terminal.
	 *
	 * The flash command as well as any commands that are called by the
	 * flash command must be in the PATH!
	 */
	private void startFlash() {
		killFlashProcess();

		if (m_project_folder == null)
			if (!chooseProjectFolder())
				return;

		string[] argv = null;
		try {
			Shell.parse_argv(FLASH_COMMAND, out argv);
		} catch (ShellError ex) {
			error(ex.message);
		}

		m_flash_mode = true;
		closePort();
		connect_switch.active = false;
		clearTerminal();
		printTerminalMessage("Executing " + FLASH_COMMAND + " in " + m_project_folder);

		string[] envvars = { "PORT=" + ports_combo.get_active_text(),
				"PATH=" + Environment.get_variable("PATH") };
		int stdout, stderr;
		try {
			Process.spawn_async_with_pipes(m_project_folder, argv, envvars,
					SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,
					null, out m_flash_pid, null, out stdout, out stderr);
		} catch (SpawnError ex) {
			printTerminalMessage("Running " + FLASH_COMMAND + " failed: " + ex.message);
		}

		// Watch stdout / stderr and print to terminal
		IOChannel stdout_channel = new IOChannel.unix_new(stdout);
		IOChannel stderr_channel = new IOChannel.unix_new(stderr);
		m_flash_stdout_src = stdout_channel.add_watch_full(Priority.DEFAULT, IOCondition.IN, handleFlashOutput);
		m_flash_stderr_src = stderr_channel.add_watch_full(Priority.DEFAULT, IOCondition.IN, handleFlashOutput);

		// Handle flash process exiting
		ChildWatch.add(m_flash_pid, onFlashExit);

		setSettingsSensitive(false);
	}

	/*
	 * Callback for whenever the flash process outputs something to
	 * stdout or stderr. Display output in VTE terminal.
	 * Unfortunately, IOChannel.read_line seems to block the main loop,
	 * therefore use Posix.read.
	 */
	private bool handleFlashOutput(IOChannel channel) {
		size_t len = 0;
		do {
			uint8[] flash_buf = new uint8[FLASH_BUF_LEN];
			len = Posix.read(channel.unix_get_fd(), flash_buf, FLASH_BUF_LEN);

			if (len > 0) {
				flash_buf[len] = '\0';
				string bufstr = (string)flash_buf;

				// VTE uses \r\n as newline character, but flash process propably
				// only \n. Therefore, replace all \n with \r\n.
				m_term.feed(bufstr.replace("\n", "\r\n").data);
			}
		} while (len == FLASH_BUF_LEN);

		return Source.CONTINUE;
	}

	/*
	 * Callback for m_term.child_exited signal, invoked whenever
	 * the flash process finishes. Clean up, evaluate flash command
	 * exit status and connect to serial port if successful, otherwise
	 * display error.
	 */
	private void onFlashExit(Pid pid, int status) {
		if (pid != m_flash_pid)
			return;

		if (!m_flash_mode)
			return;

		m_flash_mode = false;
		m_flash_pid = -1;
		setSettingsSensitive(true);

		Source.remove(m_flash_stdout_src);
		Source.remove(m_flash_stderr_src);

		if (status == 0) {
			clearTerminal();
			connect_switch.active = true;
		} else {
			printTerminalMessage("Flash command failed!");
		}
	}

	/*
	 * Use ANSI escape codes to clear terminal without deleting
	 * the history.
	 */
	private void clearTerminal() {
		m_term.feed("\033[H\033[2J".data);
	}

	/**************************/
	/*   UI Signal handlers   */
	/**************************/

	/*
	 * Toggle serial port, switch callback
	 * Callback is also invoked by F6 / F7 shortcuts since those
	 * callbacks just manually move the slider.
	 */
	[GtkCallback]
	private void onSwitchToggle() {
		killFlashProcess();

		if (connect_switch.active) {
			if (!openPort())
				connect_switch.active = false;
			else
				setSettingsSensitive(false);
		} else {
			closePort();
			setSettingsSensitive(true);
		}
	}

	[GtkCallback]
	private void onFlashClick() {
		startFlash();
	}

	[GtkCallback]
	private void onDestroy() {
		Gtk.main_quit();
	}

	[GtkCallback]
	private void onRefreshClick() {
		updatePorts();
	}

	/*
	 * Private variables
	 * Use composite templates to directly import widgets
	 * from Gtk.Builder UI file
	 */
	private Vte.Terminal m_term;
	private ESPSerial.Port m_serial_port;
	private string m_project_folder;
	private bool m_flash_mode = false;
	private Pid m_flash_pid = -1;
	private uint m_flash_stdout_src = -1;
	private uint m_flash_stderr_src = -1;

	[GtkChild] private Gtk.ComboBoxText ports_combo;
	[GtkChild] private Gtk.ComboBoxText baud_combo;
	[GtkChild] private Gtk.Switch connect_switch;
	[GtkChild] private Gtk.Button ports_refresh_button;
	[GtkChild] private Gtk.ToggleButton crlf_toggle;
	[GtkChild] private Gtk.ScrolledWindow vte_container;
}

class Main {
	public static int main(string[] args) {
		Gtk.init(ref args);
		new App();
		Gtk.main();

		return 0;
	}
}
