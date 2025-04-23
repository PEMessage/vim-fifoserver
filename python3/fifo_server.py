# python3/fifo_server.py
import vim
import os
import threading
import time
import stat
import json
import base64
from typing import List

def expand_path(path):
    return os.path.expanduser(os.path.expandvars(path))

DEFAULT_FIFO = '~/.cache/vim/fifo/public.fifo'

class Context:
    def __init__(self, pwd: str):
        self.pwd = pwd

class Message:
    def __init__(self, mode: str, context: Context, arguments: List[str]):
        self.mode = mode
        self.context = context
        self.arguments = arguments

    def serialize(self) -> str:
        data = {
            'mode': self.mode,
            'context': self.context.__dict__,
            'arguments': self.arguments
        }
        json_str = json.dumps(data)
        return base64.b64encode(json_str.encode('utf-8')).decode('utf-8')

    @classmethod
    def deserialize(cls, base64_str: str) -> 'Message':
        json_str = base64.b64decode(base64_str.encode('utf-8')).decode('utf-8')
        data = json.loads(json_str)
        context = Context(pwd=data['context']['pwd'])
        return cls(
            mode=data['mode'],
            context=context,
            arguments=data['arguments']
        )

def ensure_fifo(fifo_path):
    fifo_dir = os.path.dirname(fifo_path)
    os.makedirs(fifo_dir, exist_ok=True)
    
    if os.path.exists(fifo_path):
        if not stat.S_ISFIFO(os.stat(fifo_path).st_mode):
            os.unlink(fifo_path)
            os.mkfifo(fifo_path)
    else:
        os.mkfifo(fifo_path)

def escape_argument(arg):
    """Escape single argument for Vim's command line"""
    if not arg:
        return "''"
    if ' ' in arg or '\t' in arg or arg[0] in ('"', "'"):
        escaped = arg.replace("'", "''")
        return f"'{escaped}'"
    return arg

def handle_command(encoded_message):
    try:
        msg = Message.deserialize(encoded_message)
    except Exception as e:
        print(f"Invalid message format: {e}")
        return

    if msg.mode != 'vim-exe':
        print(f"Unsupported mode: {msg.mode}")
        return

    escaped_args = []
    for arg in msg.arguments:
        escaped = escape_argument(arg)
        escaped_args.append(escaped)
    command = ' '.join(escaped_args)

    safe_pwd = msg.context.pwd.replace("'", "''")
    
    vim_command = (
        f"lcd {safe_pwd} "
        f"| execute '{command}' "
        f"| lcd -"
    )
    
    try:
        vim.command(vim_command)
    except Exception as e:
        print(f"Command execution failed: {e}")

def fifo_listener(fifo_path):
    while getattr(threading.current_thread(), "do_run", True):
        try:
            ensure_fifo(fifo_path)
            with open(fifo_path, 'r') as fifo:
                while True:
                    line = fifo.readline().strip()
                    if line:
                        handle_command(line)
                    else:
                        break
        except Exception as e:
            print(f"FIFO error: {e}")
            time.sleep(1)

_fifo_thread = None
_fifo_path = None

def start_fifo_server(fifo_path_arg):
    global _fifo_thread, _fifo_path

    if _fifo_thread and _fifo_thread.is_alive():
        stop_fifo_server()

    _fifo_path = expand_path(fifo_path_arg) if fifo_path_arg else expand_path(DEFAULT_FIFO)
    ensure_fifo(_fifo_path)
    
    _fifo_thread = threading.Thread(target=fifo_listener, daemon=True, kwargs={'fifo_path': _fifo_path})
    _fifo_thread.do_run = True
    _fifo_thread.start()

def stop_fifo_server():
    global _fifo_thread
    if _fifo_thread and _fifo_thread.is_alive():
        _fifo_thread.do_run = False
        _fifo_thread.join()
    if _fifo_path and os.path.exists(_fifo_path):
        os.unlink(_fifo_path)

def restart_fifo_server():
    global _fifo_path
    if _fifo_thread and _fifo_thread.is_alive():
        current_path = _fifo_path
        stop_fifo_server()
        start_fifo_server(current_path)
    else:
        start_fifo_server(None)
