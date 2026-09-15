#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
sandbox=$(mktemp -d "$root/.tmp-preparation.XXXXXX")
trap 'rm -rf -- "$sandbox"' EXIT
export HOME="$sandbox/home" XDG_CONFIG_HOME="$sandbox/config" XDG_DATA_HOME="$sandbox/data"
export XDG_STATE_HOME="$sandbox/state" XDG_CACHE_HOME="$sandbox/cache" XDG_BIN_HOME="$sandbox/bin-home"
export XDG_RUNTIME_DIR="$sandbox/runtime" TMPDIR="$sandbox"
python3 -I -B - "$root" "$sandbox" <<'PY'
from pathlib import Path
import os, shutil, subprocess, sys
root, sandbox = map(Path, sys.argv[1:])
commands = sandbox/'commands'; commands.mkdir()
for name in ('bash', 'python3', 'dirname', 'mkdir', 'chmod', 'cat', 'cmp', 'ln', 'readlink', 'realpath', 'grep', 'sed', 'rm', 'mktemp', 'awk'):
    (commands/name).symlink_to(shutil.which(name))
def script(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text('#!/usr/bin/env bash\nset -e\n'+text+'\n'); path.chmod(0o755)
script(commands/'id', 'echo 1000')
script(commands/'lsmod', 'exit 0')
for name in ('qs', 'autotiling', 'turnstile-update-runit-env', 'uwsm'):
    script(commands/name, 'exit 99')  # Presence checks only; never run sessions.
for name in ('pacman', 'xbps-install', 'systemctl', 'sv', 'loginctl', 'gpg-agent', 'ssh-agent', 'curl', 'brew'):
    script(commands/name, 'printf "forbidden %s\\n" "$0 $*" >> "$EVENTS"; exit 99')
script(commands/'sudo', '''[[ $1 == cat ]] || { printf 'forbidden sudo %s\\n' "$*" >> "$EVENTS"; exit 99; }
case $2 in
/usr/share/examples/turnstile/dbus.run|/usr/share/examples/turnstile/dbus.check) printf '#!/bin/sh\\nexit 0\\n';;
/etc/turnstile/backend/runit.conf) printf 'services_dir="$HOME/.config/service"\\n';;
*) exit 99;; esac''')
script(commands/'gpg', '''[[ $1 == --batch && $2 == --no-autostart && $3 == --homedir && $4 == "$GNUPGHOME" && $5 == --list-keys ]] || exit 99
printf 'gpg\\n' >> "$EVENTS"''')
script(commands/'mise', '''[[ $MISE_NO_CONFIG == 1 && $MISE_NO_ENV == 1 && $MISE_NO_HOOKS == 1 ]] || exit 99
[[ $PWD == "$HOME" && $MISE_GLOBAL_CONFIG_FILE == /dev/null ]] || exit 99
printf '%s\\n' "$*" >> "$EVENTS"
case "$1 $2" in
'config get') [[ $3 == tools && $4 == --file && $5 == "$CANDIDATE_CONFIG" ]] || exit 99
  if [[ ${DECLARATIONS+x} ]]; then printf '%s\\n' "$DECLARATIONS"; else printf 'nodejs = "26.7.0"\\npostgres = "18.6"\\n'; fi;;
'install --yes') [[ ${FAIL_INSTALL:-} != yes ]] || exit 71;;
*) exit 99;; esac''')
base = {k:v for k,v in os.environ.items() if k == 'HOME' or k.startswith('XDG_') or k == 'TMPDIR'}
base.update(PATH=str(commands), USER='tester', DOTSYS_PLATFORM='void', EVENTS=str(sandbox/'events'),
            GIT_CONFIG_NOSYSTEM='1', GIT_CONFIG_GLOBAL='/dev/null',
            GIT_AUTHOR_NAME='fixture', GIT_AUTHOR_EMAIL='fixture@example.invalid',
            GIT_COMMITTER_NAME='fixture', GIT_COMMITTER_EMAIL='fixture@example.invalid')
for key in ('HOME', 'XDG_CONFIG_HOME', 'XDG_DATA_HOME', 'XDG_STATE_HOME', 'XDG_CACHE_HOME', 'XDG_BIN_HOME', 'XDG_RUNTIME_DIR'):
    Path(base[key]).mkdir()
events = Path(base['EVENTS'])
checks = 0
def run(path, *args, failure=False, env=None):
    global checks
    result = subprocess.run(['bash',str(path),*map(str,args)], env=env or base, cwd=base['HOME'], capture_output=True)
    assert (result.returncode != 0) == failure, (path,args,result.returncode,result.stdout,result.stderr)
    assert b'private-preparation-sentinel' not in result.stdout+result.stderr
    assert not events.exists() or 'forbidden' not in events.read_text()
    checks += 1
    return result

def snapshot(path):
    result = {}
    for parent, dirs, files in os.walk(path, followlinks=False):
        for name in dirs+files:
            p = Path(parent)/name; s = p.lstat()
            result[str(p)] = (s.st_ino, s.st_mode, None if p.is_dir() and not p.is_symlink() else s.st_mtime_ns,
                             os.readlink(p) if p.is_symlink() else p.read_bytes() if p.is_file() else None)
    return result

# Actual service preparation, with only privileged reads replaced by fixtures.
shell = sandbox/'dotshell'
script(shell/'setup/dotshell.run', '''cat >"$launcher" <<EOF
#!/bin/sh
export QSG_RHI_BACKEND="\\${QSG_RHI_BACKEND:-vulkan}"
exec /usr/bin/quickshell -p "$HOME/.config/dotshell"
EOF''')
base['DOTSYS_DOTSHELL_ROOT'] = str(shell)
for platform, services in (('arch', ('sway','greetd','kanshi')), ('void', ('sway','greetd','kanshi','turnstile','pipewire'))):
    local = dict(base, DOTSYS_PLATFORM=platform, XDG_STATE_HOME=str(sandbox/platform/'state'),
                 XDG_CONFIG_HOME=str(sandbox/platform/'config space'))
    for service in services:
        path = root/platform/'init.d'/f'{service}.sh'
        run(path, '--prepare', env=local)
        before = snapshot(sandbox/platform)
        run(path, '--prepare', env=local)
        assert snapshot(sandbox/platform) == before, service
    prepared = Path(local['XDG_STATE_HOME'])/'dotsys/prepared'
    assert (prepared/'greetd.toml').is_file()
    assert not (Path(local['XDG_CONFIG_HOME'])/'service').exists()
    assert not (Path(local['XDG_CONFIG_HOME'])/'systemd').exists()
    assert not events.exists(), 'Preparation must never control services/packages/agents'
    if platform == 'void':
        assert 'QSG_RHI_BACKEND' not in (prepared/'quickshell/run').read_text()
        assert 'exec qs -p "$XDG_CONFIG_HOME/dotshell"' in (prepared/'quickshell/run').read_text()
        assert local['XDG_CONFIG_HOME'] in (prepared/'runit.conf').read_text()
    # A changed prepared definition fails without clobbering it or activating.
    p = prepared/'greetd.toml'; p.write_text('private-preparation-sentinel')
    before = snapshot(sandbox/platform)
    run(root/platform/'init.d/greetd.sh', '--prepare', env=local, failure=True)
    assert snapshot(sandbox/platform) == before

# GnuPG requires the configuration-owned directory; it never starts an agent.
base['GNUPGHOME'] = str(sandbox/'configured-gnupg')
run(root/'shared/gnupg/init.sh', failure=True)
p = Path(base['GNUPGHOME']); p.mkdir(mode=0o755)
run(root/'shared/gnupg/init.sh')
assert p.stat().st_mode & 0o777 == 0o700 and events.read_text() == 'gpg\n'
p.rmdir(); p.symlink_to(Path(base['XDG_DATA_HOME']))
run(root/'shared/gnupg/init.sh', failure=True)
assert p.is_symlink() and events.read_text() == 'gpg\n'
events.unlink()

# Candidate tools-only preparation preserves active links, choices and both Git
# revisions; all tool installation is fake and no candidate hooks are sourced.
git = shutil.which('git')
def git_run(*args):
    return subprocess.run([git,*map(str,args)],env=base,capture_output=True,check=True).stdout.strip()
active, candidate = sandbox/'active', sandbox/'candidate'
for repo in (active, candidate):
    repo.mkdir(); git_run('init','-q',repo)
    (repo/'config/mise').mkdir(parents=True)
    (repo/'config/mise/config.toml').write_text('[tools]\nnodejs = "26.7.0"\npostgres = "18.6"\n[hooks]\nenter = "exit 99"\n')
    git_run('-C',repo,'add','.'); git_run('-C',repo,'commit','-qm','fixture')
config = Path(base['XDG_CONFIG_HOME'])
(config/'mise').symlink_to(active/'config/mise')
(config/'dots').mkdir(); (config/'dots/env').write_text('DOTS_SELECTION=sway\n# private-preparation-sentinel\n')
base['CANDIDATE_CONFIG'] = str(candidate/'config/mise/config.toml')
before = {p:snapshot(p) for p in (active,candidate,config)}
revisions = [git_run('-C',p,'rev-parse','HEAD') for p in (active,candidate)]
run(root/'shared/mise/init.sh', '--config', base['CANDIDATE_CONFIG'])
assert events.read_text().splitlines() == ['config get tools --file '+base['CANDIDATE_CONFIG'], 'install --yes nodejs@26.7.0 postgres@18.6']
for value in ('nodejs = "prefix:26"', 'nodejs = "26"', 'nodejs = "26.7.0.1"', 'nodejs = ["26.7.0"]', 'nodejs = "$(touch forbidden)"'):
    events.unlink()
    run(root/'shared/mise/init.sh','--config',base['CANDIDATE_CONFIG'],env=dict(base,DECLARATIONS=value),failure=True)
    assert len(events.read_text().splitlines()) == 1
run(root/'shared/mise/init.sh', '--config', base['CANDIDATE_CONFIG'], env=dict(base,FAIL_INSTALL='yes'), failure=True)
run(root/'shared/mise/init.sh', failure=True)
run(root/'shared/mise/init.sh', '--config', 'relative.toml', failure=True)
run(root/'shared/mise/init.sh', '--config', sandbox/'absent', failure=True)
assert {p:snapshot(p) for p in before} == before
assert [git_run('-C',p,'rev-parse','HEAD') for p in (active,candidate)] == revisions

# Safe acquisition never advances existing sources or converts unrelated paths.
(commands/'git').symlink_to(git)
destination = sandbox/'acquired'
run(root/'shared/repositories.sh','acquire','dotvim',destination,active)
revision = git_run('-C',destination,'rev-parse','HEAD')
(destination/'private').write_text('private-preparation-sentinel')
run(root/'shared/repositories.sh','acquire','dotvim',destination,active)
assert git_run('-C',destination,'rev-parse','HEAD') == revision
assert (destination/'private').read_text() == 'private-preparation-sentinel'
run(root/'shared/repositories.sh','acquire','dotvim',destination,candidate,failure=True)
unrelated = sandbox/'unrelated'; unrelated.mkdir(); (unrelated/'keep').write_text('keep')
run(root/'shared/repositories.sh','acquire','dotvim',unrelated,active,failure=True)
assert (unrelated/'keep').read_text() == 'keep'
link = sandbox/'repo-link'; link.symlink_to(destination)
run(root/'shared/repositories.sh','acquire','dotvim',link,active,failure=True)
run(root/'shared/repositories.sh','acquire','dotvim',sandbox/'new','https://example.invalid/unverified',failure=True)
assert not (sandbox/'new').exists()
# Native package lists and repaired shared delegates use only controlled spies.
script(commands/'sudo', 'exec "$@"')
for name in ('pacman','xbps-install','paru','cargo'):
    script(commands/name, 'printf "%s %s\\n" "${0##*/}" "$*" >> "$EVENTS"')
script(commands/'gh', '''printf 'gh %s\\n' "$*" >> "$EVENTS"
[[ "$1 $2" != 'auth status' || ${GH_AUTH:-yes} == yes ]]''')
for platform in ('arch','void'):
    events.unlink(missing_ok=True)
    local = dict(base,DOTSYS_PLATFORM=platform)
    run(root/platform/'packages/init.sh','--bootstrap',env=local)
    packages = events.read_text().split()
    for required in ('bash','git','coreutils','sed','tmux','mise','neovim','gnupg'):
        assert required in packages
    assert ('python' if platform == 'arch' else 'python3') in packages
    assert not any(p in packages for p in ('steam','mariadb','postgresql','sway'))
    run(root/platform/'init.d/sway.sh','--packages',env=local)
    packages = events.read_text().split()
    for required in ('sway','swayidle','swaylock','ghostty','foot','wl-clipboard','wl-clip-persist','cliphist','kanshi','quickshell'):
        assert required in packages
    assert ('autotiling-rs' if platform == 'arch' else 'autotiling') in packages
for name in ('cargo','gh'):
    events.unlink()
    run(root/'shared'/name/'init.sh')
    shared = events.read_text(); events.unlink()
    run(root/'arch/packages'/name/'init.sh')
    assert events.read_text() == shared
    assert (root/'arch/packages'/name/('packages' if name == 'cargo' else 'extensions')).resolve() == root/'shared'/name/('packages' if name == 'cargo' else 'extensions')
events.unlink()
run(root/'shared/gh/init.sh', env=dict(base,GH_AUTH='no'), failure=True)
assert events.read_text() == 'gh auth status\n'

# Homebrew's official installer is replaced with a tiny local payload. Redirect
# absolute native lookup roots in this copy, never execute a host Homebrew.
brew_fixture = sandbox/'brew-fixture/shared/brew/init.sh'
brew_fixture.parent.mkdir(parents=True)
brew_fixture.write_text((root/'shared/brew/init.sh').read_text()
                        .replace('/opt/homebrew',str(sandbox/'native/homebrew'))
                        .replace('/home/linuxbrew/.linuxbrew',str(sandbox/'native/linuxbrew')))
(commands/'brew').unlink()
script(commands/'curl', '''[[ $1 == -fsSL && $2 == https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh && $3 == -o ]] || exit 99
[[ $4 == "$XDG_CACHE_HOME"/dotsys/homebrew.* ]] || exit 99
[[ ${DOWNLOAD_FAIL:-} != yes ]] || exit 71
printf '#!/bin/bash\\nprintf "fake-installer\\\\n" >> "$EVENTS"\\n' > "$4"''')
events.unlink()
run(brew_fixture,'--skip-bundles')
assert events.read_text() == 'fake-installer\n'
assert not list((Path(base['XDG_CACHE_HOME'])/'dotsys').glob('homebrew.*'))
events.unlink()
run(brew_fixture,'--skip-bundles',env=dict(base,DOWNLOAD_FAIL='yes'),failure=True)
assert not events.exists()
script(commands/'brew', 'printf "brew %s\\n" "$*" >> "$EVENTS"')
script(commands/'uname', 'echo Darwin')
run(brew_fixture,'--skip-bundles'); assert not events.exists()
run(brew_fixture,'--no-confirm')
assert events.read_text().splitlines() == ['brew bundle --file='+str(brew_fixture.parents[2]/'shared/brew/Brewfile.default'),
                                         'brew bundle --file='+str(brew_fixture.parents[2]/'macos/Brewfile')]
print(f'preparation: {checks} controlled checks passed (no real installation or activation)')
PY
