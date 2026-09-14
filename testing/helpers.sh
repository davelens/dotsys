#!/usr/bin/env bash
set -euo pipefail
root=$(cd "${BASH_SOURCE[0]%/*}/.." && pwd)
test_root=$(mktemp -d "$root/.tmp-helpers.XXXXXX")
trap 'rm -rf -- "$test_root"' EXIT
export HOME="$test_root/home" XDG_CONFIG_HOME="$test_root/config"
export XDG_DATA_HOME="$test_root/data" XDG_STATE_HOME="$test_root/state"
export XDG_CACHE_HOME="$test_root/cache" XDG_BIN_HOME="$test_root/bin-home"
export XDG_RUNTIME_DIR="$test_root/runtime" TMPDIR="$test_root"
python3 -I -B - "$root" "$test_root" <<'PY'
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

root, sandbox = map(Path, sys.argv[1:])
home = Path(os.environ['HOME'])
home.mkdir()
bin = sandbox/'bin'
bin.mkdir()
for tool in ('bash', 'python3', 'realpath', 'dirname', 'basename'):
    (bin/tool).symlink_to(shutil.which(tool))
spy = sandbox/'spy'
spy.write_text('''#!/usr/bin/env -S python3 -I -B
import json, os, sys
with open(os.environ['CALLS'], 'a') as f:
    f.write(json.dumps([os.path.basename(sys.argv[0]), *sys.argv[1:]]) + '\\n')
sys.exit(37 if os.path.basename(sys.argv[0]) == os.environ.get('FAIL_COMMAND') else 0)
''')
spy.chmod(0o755)
providers = ('systemctl', 'sv', 'loginctl', 'pg_ctl', 'mysql.server', 'uwsm',
             'swaymsg', 'turnstile-update-runit-env', 'dbus-update-activation-environment',
             'osascript', 'session-app')
for tool in providers:
    (bin/tool).symlink_to(spy)
# There is no fallthrough to host executables. Any provisioning call is fatal.
for tool in ('sudo', 'pacman', 'paru', 'brew', 'xbps-install', 'initdb', 'psql', 'mise', 'mysql_install_db'):
    p = bin/tool
    p.write_text('#!/usr/bin/env bash\nprintf forbidden >> "$HOME/forbidden"\nexit 99\n')
    p.chmod(0o755)
for p in (home/'.bashrc', home/'.bash_profile', Path(os.environ['XDG_CONFIG_HOME'])/'dots/env'):
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text('echo secret-helper-sentinel\nprintf sourced >> "$HOME/forbidden"\n')
calls = sandbox/'calls'
env = {k: v for k, v in os.environ.items() if k == 'HOME' or k.startswith('XDG_') or k == 'TMPDIR'}
env.update(PATH=str(bin), CALLS=str(calls), DOTSYS_PLATFORM='arch')
checks = 0

def run(command, *args, expected=None, failure=False, **overrides):
    global checks
    local = dict(env)
    for k, v in overrides.items():
        if v is None: local.pop(k, None)
        else: local[k] = str(v)
    calls.write_text('')
    path = root/'shared/utilities'/command if not str(command).startswith('/') else Path(command)
    result = subprocess.run([str(path), *args], env=local, cwd=home, capture_output=True)
    assert (result.returncode != 0) == failure, (command, result.returncode, result.stderr)
    assert b'secret-helper-sentinel' not in result.stdout + result.stderr
    assert not (home/'forbidden').exists(), command
    actual = [json.loads(line) for line in calls.read_text().splitlines()]
    assert actual == (expected or []), (command, actual, expected)
    if failure and not overrides.get('FAIL_COMMAND'):
        assert result.stderr, command
    checks += 1


def cluster(path):
    path.mkdir(parents=True, exist_ok=True)
    (path/'PG_VERSION').write_text('18\n')
    return path

explicit = cluster(home/'explicit cluster')
for platform in ('arch', 'wsl', 'void', 'macos'):
    for action in ('start', 'stop'):
        run('postgresql/'+action, PGDATA=explicit, DOTSYS_PLATFORM=platform,
            expected=[['pg_ctl', '-D', str(explicit), action]])
run('postgresql/start', 'ignored', PGDATA=explicit, failure=True)
run('postgresql/start', PGDATA='', failure=True)
run('postgresql/start', PGDATA='relative', failure=True)
run('postgresql/start', PGDATA=home/'missing', failure=True)
run('postgresql/start', failure=True)
# Empty data directories are not clusters; no runtime initialization.
(Path(env['XDG_DATA_HOME'])/'postgres/data').mkdir(parents=True)
run('postgresql/start', failure=True)
locations = [Path(env['XDG_DATA_HOME'])/'postgres/data', home/'.local/share/postgres/data',
             Path(env['XDG_DATA_HOME'])/'mise/installs/postgres/18.6/data',
             home/'.local/share/mise/installs/postgres/17.5/data',
             home/'custom mise/installs/postgres/18.6/data']
for location in locations:
    cluster(location)
    options = {'MISE_DATA_DIR': home/'custom mise'} if 'custom mise' in str(location) else {}
    for action in ('start', 'stop'):
        run('postgresql/'+action, expected=[['pg_ctl', '-D', str(location), action]], **options)
    (location/'PG_VERSION').unlink()
first, second = map(cluster, locations[:2])
run('postgresql/start', failure=True)
run('postgresql/stop', failure=True)
run('postgresql/start', PGDATA=explicit, expected=[['pg_ctl', '-D', str(explicit), 'start']])
(first/'PG_VERSION').unlink()
(second/'PG_VERSION').unlink()
first, second = map(cluster, [locations[2], locations[2].parent.parent/'19.0/data'])
run('postgresql/start', failure=True)
shutil.rmtree(second.parent)
# Aliases of the same cluster are not ambiguous.
(first.parent.parent/'current').symlink_to(first.parent)
run('postgresql/start', expected=[['pg_ctl', '-D', str(first), 'start']])
run('postgresql/stop', PGDATA=explicit, FAIL_COMMAND='pg_ctl', failure=True,
    expected=[['pg_ctl', '-D', str(explicit), 'stop']])
(bin/'pg_ctl').unlink()
run('postgresql/start', PGDATA=explicit, failure=True)
(bin/'pg_ctl').symlink_to(spy)

service = home/'prepared MariaDB'
service.mkdir()
(service/'run').write_text('not executed')
(service/'run').chmod(0o755)
for platform in ('arch', 'wsl', 'void', 'macos'):
    for action in ('start', 'stop'):
        expected = (['systemctl', action, 'mariadb'] if platform in ('arch', 'wsl') else
                    ['mysql.server', action] if platform == 'macos' else
                    ['sv', 'up' if action == 'start' else 'down', str(service)])
        run('mariadb/'+action, DOTSYS_PLATFORM=platform, DOTSYS_MARIADB_SERVICE=service, expected=[expected])
run('mariadb/start', DOTSYS_PLATFORM='void', failure=True)
run('mariadb/stop', 'extra', failure=True)

for platform in ('arch', 'wsl', 'void', 'macos'):
    args = ['session-app', 'space and \'quote', '$not-code;']
    expected = ['uwsm', 'app', '--', *args] if platform in ('arch', 'wsl') else args
    run('desktop-session/launch', *args, DOTSYS_PLATFORM=platform, expected=[expected])
    if platform != 'macos':
        run('desktop-session/stop', DOTSYS_PLATFORM=platform,
            expected=[['swaymsg', 'exit'] if platform == 'void' else ['uwsm', 'stop']])
run('desktop-session/launch', failure=True)
run('desktop-session/launch', 'missing-app', failure=True)
run('desktop-session/stop', 'extra', failure=True)
run('desktop-session/stop', DOTSYS_PLATFORM='macos', failure=True)
run('desktop-session/finalize', DOTSYS_PLATFORM='macos', failure=True)
for platform in ('arch', 'wsl'):
    run('desktop-session/finalize', DOTSYS_PLATFORM=platform,
        expected=[['uwsm', 'finalize'], ['systemctl', '--user', 'restart', 'xdg-desktop-portal.service']])
run('desktop-session/finalize', FAIL_COMMAND='uwsm', failure=True, expected=[['uwsm', 'finalize']])
variables = ['DISPLAY', 'I3SOCK', 'SWAYSOCK', 'WAYLAND_DISPLAY', 'XCURSOR_SIZE', 'XCURSOR_THEME', 'XDG_CURRENT_DESKTOP']
run('desktop-session/finalize', DOTSYS_PLATFORM='void',
    expected=[['turnstile-update-runit-env', *variables], ['dbus-update-activation-environment', *variables]])
run('desktop-session/finalize', DOTSYS_PLATFORM='void', FAIL_COMMAND='turnstile-update-runit-env', failure=True,
    expected=[['turnstile-update-runit-env', *variables]])
# All prerequisites are checked before the first finalize operation.
for platform, tool in [('arch', 'systemctl'), ('void', 'dbus-update-activation-environment')]:
    (bin/tool).unlink()
    run('desktop-session/finalize', DOTSYS_PLATFORM=platform, failure=True)
    (bin/tool).symlink_to(spy)
(bin/'uwsm').unlink()
run('desktop-session/launch', 'session-app', failure=True)
run('desktop-session/stop', failure=True)
(bin/'uwsm').symlink_to(spy)

for category in ('kanshi', 'quickshell'):
    for platform in ('arch', 'wsl'):
        run(category+'/restart', DOTSYS_PLATFORM=platform,
            expected=[['systemctl', '--user', 'restart', category+'.service']])
    run(category+'/restart', DOTSYS_PLATFORM='void', failure=True)
    service = Path(env['XDG_CONFIG_HOME'])/'service'/category
    service.mkdir(parents=True)
    (service/'run').write_text('not executed')
    (service/'run').chmod(0o755)
    run(category+'/restart', DOTSYS_PLATFORM='void', expected=[['sv', 'restart', str(service)]])
    run(category+'/restart', DOTSYS_PLATFORM='macos', failure=True)
    run(category+'/restart', 'extra', failure=True)

for platform in ('arch', 'wsl', 'void'):
    for action in ('poweroff', 'shutdown', 'reboot', 'hibernate', 'suspend', 'lock', 'logout'):
        native = 'poweroff' if action == 'shutdown' else action
        expected = (['loginctl', 'lock-session'] if action == 'lock' else
                    ['loginctl', 'terminate-session', 'session-7'] if action == 'logout' else
                    ['loginctl' if platform == 'void' else 'systemctl', native])
        run('power/control', action, DOTSYS_PLATFORM=platform, XDG_SESSION_ID='session-7', expected=[expected])
run('power/control', 'logout', failure=True)
run('power/control', 'logout', XDG_SESSION_ID='--all', failure=True)
for action, operation in [('poweroff', 'shut down'), ('shutdown', 'shut down'), ('reboot', 'restart'), ('suspend', 'sleep'), ('logout', 'log out')]:
    run('power/control', action, DOTSYS_PLATFORM='macos',
        expected=[['osascript', '-e', 'tell application "System Events" to '+operation]])
for action in ('lock', 'hibernate'):
    run('power/control', action, DOTSYS_PLATFORM='macos', failure=True)
for args in ([], ['unknown'], ['reboot', 'extra']):
    run('power/control', *args, failure=True)
run('power/control', 'reboot', DOTSYS_PLATFORM='unsupported', failure=True)
run('power/control', 'reboot', DOTSYS_PLATFORM='', failure=True)
run('power/control', 'reboot', XDG_CONFIG_HOME='relative', failure=True)
# No initialized shell or runtime directory; discover native macOS via uname.
uname = bin/'uname'
uname.write_text('#!/usr/bin/env bash\nprintf "Darwin\\n"\n')
uname.chmod(0o755)
run('mariadb/start', DOTSYS_PLATFORM=None, XDG_RUNTIME_DIR=None, expected=[['mysql.server', 'start']])
# The registered category path resolves back to the checkout, not its parent.
link = home/'postgresql'
link.symlink_to(root/'shared/utilities/postgresql')
run(link/'stop', PGDATA=explicit, expected=[['pg_ctl', '-D', str(explicit), 'stop']])
arch = home/'arch'
arch.symlink_to(root/'arch/bin')
for helper in ('flatpak', 'paru', 'mariadb'):
    run(arch/helper, '--help')
# Default XDG lookup agrees with the existing explicit provisioner's cluster.
legacy = cluster(home/'.local/share/postgres/data')
run('postgresql/start', XDG_DATA_HOME=None, expected=[['pg_ctl', '-D', str(legacy), 'start']])
assert 'PGDATA="${PGDATA:-$HOME/.local/share/postgres/data}"' in (root/'arch/init.d/postgres.sh').read_text()
# Missing native providers never fall through to another platform or provisioning.
for tool, command, args, platform in [
        ('sv', 'mariadb/start', [], 'void'),
        ('mysql.server', 'mariadb/start', [], 'macos'),
        ('loginctl', 'power/control', ['reboot'], 'void'),
        ('osascript', 'power/control', ['reboot'], 'macos'),
        ('systemctl', 'kanshi/restart', [], 'arch')]:
    (bin/tool).unlink()
    run(command, *args, DOTSYS_PLATFORM=platform, failure=True)
    (bin/tool).symlink_to(spy)
# Runtime helpers cannot reach the existing explicit provisioning commands.
assert not (home/'forbidden').exists()
assert not Path(env['XDG_STATE_HOME']).exists()
assert not Path(env['XDG_RUNTIME_DIR']).exists()
print(f'helpers: {checks} fixture checks passed (no native service/provisioning calls)')
PY
