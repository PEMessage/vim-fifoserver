# Vim FIFO Server Plugin

This plugin enables communication with a running Vim instance via a named pipe (FIFO). It allows external processes to send commands to Vim for execution, making it useful for automation, scripting, and integration with other tools.


## Requirements

- Vim compiled with `+python3` support.
- Python 3 installed on your system.

To check if your Vim supports Python 3, run the following command in Vim:

```vim
:echo has('python3')
