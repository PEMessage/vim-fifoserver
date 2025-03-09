if !has('python3')
    echo "Error: Requires Vim compiled with +python3"
    finish
endif

python3 << EOF
import vim
import os
import threading
import time
import stat
import json
import base64
from dataclasses import dataclass, asdict
from typing import List

def expand_path(path):
    return os.path.expanduser(os.path.expandvars(path))

#fifo_path = vim.eval('a:fifo_path').strip()
DEFAULT_FIFO = '~/.cache/vim/fifo/public.fifo'
#FIFO_PATH = expand_path(DEFAULT_FIFO)

@dataclass
class Context:
    pwd: str

@dataclass
class Message:
    mode: str
    context: Context
    arguments: List[str]

    def serialize(self) -> str:
        json_str = json.dumps(asdict(self))
        return base64.b64encode(json_str.encode('utf-8')).decode('utf-8')

    @classmethod
    def deserialize(cls, base64_str: str) -> 'Message':
        json_str = base64.b64decode(base64_str.encode('utf-8')).decode('utf-8')
        data = json.loads(json_str)
        print(data)
        return cls(**data)

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
        # Escape single quotes by doubling them
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

    # Process arguments
    escaped_args = []
    for arg in msg.arguments:
        escaped = escape_argument(arg)
        escaped_args.append(escaped)
    command = ' '.join(escaped_args)

    # Escape working directory
    print(msg.context["pwd"])
    safe_pwd = msg.context["pwd"].replace("'", "''")
    
    # Build command with directory context and revert
    vim_command = (
        f"lcd {safe_pwd} "    # Change to target directory
        f"| execute '{command}' "  # Execute command
        f"| lcd -"              # Revert directory
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
def start_fifo_server(fifo_path_arg):
    global _fifo_thread, _fifo_path

    if '_fifo_thread' in globals() and _fifo_thread.is_alive():
        stop_fifo_server()

    _fifo_path = expand_path(fifo_path_arg) if fifo_path_arg else expand_path(DEFAULT_FIFO)
    ensure_fifo(_fifo_path)
    
    _fifo_thread = threading.Thread(target=fifo_listener, daemon=True, kwargs={'fifo_path': _fifo_path })
    _fifo_thread.do_run = True
    _fifo_thread.start()

def stop_fifo_server():
    global _fifo_thread
    if '_fifo_thread' in globals() and _fifo_thread.is_alive():
        _fifo_thread.do_run = False
        _fifo_thread.join()
    if os.path.exists(_fifo_path):
        os.unlink(_fifo_path)

def restart_fifo_server():
    global _fifo_path
    if '_fifo_thread' in globals() and _fifo_thread.is_alive():
        current_path = _fifo_path
        stop_fifo_server()
        start_fifo_server(current_path)
    else:
        start_fifo_server(None)

# Start listener thread
#thread = threading.Thread(target=fifo_listener, daemon=True)
#thread.start()
EOF

" command! -nargs=? -complete=file FIFOStart call s:FIFOServerStart(<q-args>)

command! -nargs=? -complete=file FIFOStart py3 start_fifo_server(vim.eval('"<args>"'))
command! FIFOStop py3 stop_fifo_server()
command! FIFORestart py3 restart_fifo_server()
