#!/usr/bin/env bash
set -euo pipefail
root=$(cd "${BASH_SOURCE[0]%/*}/.." && pwd)
test_root=$(mktemp -d "$root/.tmp-helper-registration.XXXXXX")
trap 'rm -rf -- "$test_root"' EXIT
export HOME="$test_root/home" XDG_CONFIG_HOME="$test_root/config"
export XDG_DATA_HOME="$test_root/data" XDG_STATE_HOME="$test_root/state"
export XDG_CACHE_HOME="$test_root/cache" XDG_BIN_HOME="$test_root/bin-home"
export XDG_RUNTIME_DIR="$test_root/runtime" TMPDIR="$test_root"
# Explicit read-only engine checkout; fixtures never register into that checkout.
dotfiles=${DOTSYS_TEST_DOTFILES_ROOT:-${root%/*}/dotfiles}
python3 -I -B - "$root" "$test_root" "$dotfiles" <<'PY'
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

root, sandbox, engine = map(Path, sys.argv[1:])
assert (engine/'setup/managed.py').is_file(), 'Set DOTSYS_TEST_DOTFILES_ROOT to the PORT-OWN checkout.'
assert (engine/'dotbot/src/dotbot/plugins/link.py').is_file(), 'Pinned Dotbot is required.'
Path(os.environ['HOME']).mkdir()
bin = sandbox/'bin'
bin.mkdir()
for tool in ('bash', 'python3', 'realpath', 'dirname'):
    (bin/tool).symlink_to(shutil.which(tool))
for tool in ('sudo', 'systemctl', 'sv', 'loginctl', 'uwsm', 'pacman', 'brew', 'xbps-install', 'mise', 'initdb'):
    p = bin/tool
    p.write_text('#!/usr/bin/env bash\nprintf forbidden >> "$HOME/forbidden"\nexit 99\n')
    p.chmod(0o755)
env = {k: v for k, v in os.environ.items() if k == 'HOME' or k.startswith('XDG_') or k == 'TMPDIR'}
env.update(PATH=str(bin), DOTSYS_PLATFORM='arch')
checks = 0
categories = ('postgresql', 'mariadb', 'desktop-session', 'kanshi', 'quickshell', 'power')

def fixture(name):
    checkout = sandbox/name/'dotfiles'
    (checkout/'setup').mkdir(parents=True)
    (checkout/'setup/managed.py').symlink_to(engine/'setup/managed.py')
    destination = checkout/'bin/utilities'
    destination.mkdir(parents=True)
    state = sandbox/name/'state'
    return checkout, destination, state


def run(checkout, state, action, *args, failure=False, platform='arch', script=None, default_state=False):
    global checks
    local = dict(env, DOTSYS_PLATFORM=platform)
    command = [str(script or root/'shared/register-helpers'), action, '--dotfiles-root', str(checkout)]
    if not default_state:
        command += ['--state-root', str(state)]
    result = subprocess.run(command+list(map(str, args)), env=local, cwd=env['HOME'], capture_output=True)
    assert (result.returncode != 0) == failure, (action, result.returncode, result.stdout, result.stderr)
    assert b'secret-registration-sentinel' not in result.stdout+result.stderr
    assert not (Path(env['HOME'])/'forbidden').exists()
    if failure: assert result.stderr
    checks += 1


def snapshot(path):
    entries = {}
    for parent, dirs, files in os.walk(path, followlinks=False):
        for name in dirs+files:
            p = Path(parent)/name
            s = p.lstat()
            content = os.readlink(p) if p.is_symlink() else p.read_bytes() if p.is_file() else None
            entries[str(p)] = (s.st_ino, s.st_mode, s.st_mtime_ns, content)
    return entries


def ledger(state):
    return json.loads((state/'managed.json').read_text())

# Fresh check is read-only, apply registers the entire set, repeats are stable.
checkout, dest, state = fixture('fresh')
(dest/'private').mkdir()
(dest/'private/config').write_text('secret-registration-sentinel')
(dest/'tmux').mkdir()
(dest/'tmux/custom').write_text('keep tmux')
before = snapshot(checkout)
run(checkout, state, 'check')
assert snapshot(checkout) == before and not state.exists()
run(checkout, state, 'apply')
for category in categories:
    assert os.readlink(dest/category) == str(root/'shared/utilities'/category)
assert os.readlink(dest/'arch') == str(root/'arch/bin')
before, saved = snapshot(checkout), (state/'managed.json').read_bytes()
run(checkout, state, 'check')
run(checkout, state, 'apply')
assert snapshot(checkout) == before and (state/'managed.json').read_bytes() == saved
# Switching platform drops only unchanged owned Arch, not other categories.
run(checkout, state, 'apply', platform='void')
assert not os.path.lexists(dest/'arch')
assert all((dest/c).is_symlink() for c in categories)
assert (dest/'private/config').read_text() == 'secret-registration-sentinel'
run(checkout, state, 'apply', platform='wsl')
assert (dest/'arch').is_symlink()
run(checkout, state, 'remove', '--path', dest/'postgresql')
assert not os.path.lexists(dest/'postgresql') and (dest/'mariadb').is_symlink()
run(checkout, state, 'apply')
run(checkout, state, 'remove', '--path', dest/'private', failure=True)
run(checkout, state, 'remove')
assert all(not os.path.lexists(dest/c) for c in (*categories, 'arch'))
assert (dest/'private/config').read_text() == 'secret-registration-sentinel'
assert (dest/'tmux/custom').read_text() == 'keep tmux'
assert (state/'backups').is_dir() and (root/'shared/register-helpers').is_file()

# No implicit enrollment of matching links; named adoption preserves identity.
checkout, dest, state = fixture('adopt')
p = dest/'postgresql'
p.symlink_to(root/'shared/utilities/postgresql')
before = p.lstat()
run(checkout, state, 'apply', failure=True)
run(checkout, state, 'check', '--adopt', p)
run(checkout, state, 'apply', '--adopt', p)
assert p.lstat() == before
run(checkout, state, 'remove')
assert not os.path.lexists(p)

# Every category conflict is preflighted before any link/state mutation.
for kind in ('file', 'directory', 'symlink', 'broken-link'):
    checkout, dest, state = fixture('conflict-'+kind)
    p = dest/'power'
    if kind == 'file': p.write_text('secret-registration-sentinel')
    elif kind == 'directory':
        p.mkdir()
        (p/'private').write_text('keep')
    else:
        target = checkout/'referent'
        if kind == 'symlink': target.write_text('secret-registration-sentinel')
        p.symlink_to(target)
    before = snapshot(checkout)
    run(checkout, state, 'check', failure=True)
    run(checkout, state, 'apply', failure=True)
    run(checkout, state, 'apply', '--adopt', p, failure=True)
    assert snapshot(checkout) == before and not state.exists()
    if kind == 'directory':
        run(checkout, state, 'apply', '--replace', p, failure=True)
        assert snapshot(checkout) == before
    else:
        original = p.lstat()
        run(checkout, state, 'apply', '--replace', p)
        key = ledger(state)['artifacts'][str(p)]['backups'][0]
        backup = state/'backups'/key/'original'
        assert backup.lstat().st_ino == original.st_ino
        assert os.readlink(p) == str(root/'shared/utilities/power')
        if kind == 'symlink': assert target.read_text() == 'secret-registration-sentinel'
        run(checkout, state, 'restore', '--backup', key, failure=True)
        run(checkout, state, 'restore', '--backup', key, '--replace', p)
        assert p.lstat().st_ino == original.st_ino
        if kind == 'file': assert p.read_text() == 'secret-registration-sentinel'
        else: assert os.readlink(p) == str(target)
        run(checkout, state, 'remove')
        assert os.path.lexists(p)  # Restored originals are not enrolled.

# User-retargeted links block repeat and survive explicit cleanup.
checkout, dest, state = fixture('retarget')
run(checkout, state, 'apply')
p = dest/'postgresql'
p.rename(dest/'old-postgresql')
p.symlink_to(checkout/'custom-db')
before = p.lstat()
run(checkout, state, 'check', failure=True)
run(checkout, state, 'apply', failure=True)
run(checkout, state, 'remove', failure=True)
assert p.lstat() == before and os.readlink(p) == str(checkout/'custom-db')
assert (dest/'old-postgresql').is_symlink()
# Exact replacement is the only route to renew ownership of that category.
run(checkout, state, 'apply', '--replace', p)
assert os.readlink(p) == str(root/'shared/utilities/postgresql')
run(checkout, state, 'remove')
assert (dest/'old-postgresql').is_symlink()

# Non-Arch registration preserves an unrelated Arch category untouched.
checkout, dest, state = fixture('macos')
(dest/'arch').mkdir()
(dest/'arch/custom').write_text('keep')
run(checkout, state, 'apply', platform='macos')
run(checkout, state, 'remove', platform='macos')
assert (dest/'arch/custom').read_text() == 'keep'

# Corrupt/missing ownership never grants cleanup authority.
checkout, dest, state = fixture('corrupt')
run(checkout, state, 'apply')
(state/'managed.json').write_text('{invalid')
before = snapshot(checkout)
run(checkout, state, 'apply', failure=True)
run(checkout, state, 'remove', failure=True)
assert snapshot(checkout) == before
checkout, dest, state = fixture('no-ledger')
(dest/'postgresql').symlink_to(root/'shared/utilities/postgresql')
run(checkout, state, 'remove', failure=True)
assert (dest/'postgresql').is_symlink() and not state.exists()

# Missing engine/source capability fails before registration, not partial links.
checkout, dest, state = fixture('missing')
run(checkout/'absent', state, 'apply', failure=True)
partial = sandbox/'partial-dotsys'
(partial/'shared').mkdir(parents=True)
for name in ('register-helpers', 'helper-env.sh'):
    shutil.copy2(root/'shared'/name, partial/'shared'/name)
for category in categories:
    if category == 'power': continue
    (partial/'shared/utilities'/category).parent.mkdir(parents=True, exist_ok=True)
    (partial/'shared/utilities'/category).symlink_to(root/'shared/utilities'/category)
before = snapshot(checkout)
run(checkout, state, 'apply', script=partial/'shared/register-helpers', failure=True)
assert snapshot(checkout) == before and not state.exists()
# Missing destination checkout layout is not silently provisioned.
shutil.rmtree(dest)
run(checkout, state, 'apply', failure=True)
assert not dest.exists() and not state.exists()

checkout, dest, state = fixture('default-state')
state = Path(env['XDG_STATE_HOME'])/'dotsys'
run(checkout, state, 'apply', default_state=True)
assert (state/'managed.json').stat().st_mode & 0o077 == 0
run(checkout, state, 'remove', default_state=True)
assert (state/'backups').is_dir()
assert not (Path(env['HOME'])/'forbidden').exists()
assert not Path(env['XDG_RUNTIME_DIR']).exists()
print(f'helper registration: {checks} fixture checks passed (real PORT-OWN/Dotbot, sandbox links only)')
PY
