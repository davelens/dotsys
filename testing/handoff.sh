#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
sandbox=$(mktemp -d "$root/.tmp-handoff.XXXXXX")
trap 'rm -rf -- "$sandbox"' EXIT
export HOME="$sandbox/home" XDG_CONFIG_HOME="$sandbox/config" XDG_DATA_HOME="$sandbox/data"
export XDG_STATE_HOME="$sandbox/state" XDG_CACHE_HOME="$sandbox/cache" XDG_BIN_HOME="$sandbox/bin-home"
export XDG_RUNTIME_DIR="$sandbox/runtime" TMPDIR="$sandbox"
python3 -I -B - "$root" "$sandbox" <<'PY'
from pathlib import Path
import os, shutil, subprocess, sys
root, sandbox = map(Path, sys.argv[1:])
bin = sandbox/'commands'; bin.mkdir()
real_git = shutil.which('git')
for name in ('bash', 'python3', 'dirname', 'mkdir', 'chmod', 'cat', 'awk', 'grep', 'sed', 'tr', 'rm', 'mktemp'):
    (bin/name).symlink_to(shutil.which(name))
def script(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text('#!/usr/bin/env bash\nset -e\n'+text+'\n'); path.chmod(0o755)
# No command fallback to host package managers, services or acquisition tools.
script(bin/'event', '''printf '%s\\n' "$*" >> "$EVENTS"
[[ ${FAIL_AT:-} != "$1" ]] || exit 71''')
script(bin/'id', '''case "$1" in -u) echo "${TEST_UID:-1000}";; -un) echo tester;; *) exit 99;; esac''')
script(bin/'uname', '''case "$1" in
-s) [[ $TEST_PLATFORM != macos ]] && echo Linux || echo Darwin;;
-m) [[ $TEST_PLATFORM != macos ]] && echo x86_64 || echo arm64;;
-r) [[ $TEST_PLATFORM != wsl ]] && echo linux || echo Microsoft-WSL2;; esac''')
script(bin/'systemctl', '''[[ ${PROVIDER_FAIL:-} != yes ]] || exit 72
[[ $1 == --system ]] || event forbidden-service "$@"''')
script(bin/'sv', 'event forbidden-service "$@"')
for name in ('nvim','qs'): script(bin/name, 'event forbidden-session; exit 99')
script(bin/'xbps-uhelper', 'echo "${VOID_ARCH:-x86_64}"')
for name in ('pacman','xbps-install','paru'):
    script(bin/name, '''case " $* " in *' bash '*) event bootstrap "$@";; *) event packages "$@";; esac''')
script(bin/'sudo', 'exec "$@"')
script(bin/'brew', '''case "$1" in
install) case " $* " in *' bash '*) event bootstrap "$@";; *) event packages "$@";; esac;;
services) event activate-macos "$@";;
*) event forbidden-brew "$@"; exit 99;; esac''')
script(bin/'open', 'event activate-macos "$@"')
script(bin/'gpg', '''[[ -d $GNUPGHOME && -f $HOME/config-installed ]] || exit 99
event gnupg "$@"''')
script(bin/'mise', '''[[ -f $HOME/config-installed ]] || exit 99
[[ $MISE_NO_CONFIG == 1 && $MISE_NO_ENV == 1 && $MISE_NO_HOOKS == 1 ]] || exit 99
case "$1 $2" in
'config get') event runtime-query "$@"; printf 'nodejs = "26.7.0"\\nrust = "latest"\\n';;
'install --yes') event runtime "$@";; *) exit 99;; esac''')
script(bin/'git', '''if [[ $1 == clone ]]; then
  destination=${@: -1}; event "acquire-${destination##*/}" "$@"
  [[ ${@: -2:1} == /* ]] || exit 99
fi
exec '''+real_git+' "$@"')
base = {k:v for k,v in os.environ.items() if k == 'HOME' or k.startswith('XDG_') or k == 'TMPDIR'}
base.update(PATH=str(bin), USER='tester', GIT_CONFIG_NOSYSTEM='1', GIT_CONFIG_GLOBAL='/dev/null',
            GIT_AUTHOR_NAME='fixture', GIT_AUTHOR_EMAIL='fixture@example.invalid',
            GIT_COMMITTER_NAME='fixture', GIT_COMMITTER_EMAIL='fixture@example.invalid')
# Local public sources only. No legacy setup entrypoint may be executed.
sources = sandbox/'sources'
for name in ('dotfiles','dotvim','dotshell'):
    p=sources/name; p.mkdir(parents=True)
    subprocess.run([real_git,'init','-q',str(p)],env=base,check=True)
    (p/'sentinel').write_text(name)
    if name == 'dotvim': (p/'init.lua').write_text('-- fixture')
    if name == 'dotshell':
        (p/'shell.qml').write_text('// fixture')
        script(p/'bin/dshell', 'exit 99')
    if name == 'dotfiles':
        script(p/'setup/common.sh', '''dots_bootstrap() {
  shift 2
  DOTS_SELECTION=${DOTS_INSTALL_SELECTION-${SAVED_SELECTION:-}}
  DOTS_WEZTERM_DESTINATION=${DOTS_INSTALL_WEZTERM_DESTINATION-${SAVED_DESTINATION:-}}
  DOTS_SAVE=0
  while [[ $# -gt 0 ]]; do
    case $1 in --select) DOTS_SELECTION=$2; shift 2;; --wezterm-destination) DOTS_WEZTERM_DESTINATION=$2; shift 2;; --save) DOTS_SAVE=1; shift;; *) return 99;; esac
  done
  export GNUPGHOME="$XDG_DATA_HOME/gnupg" MISE_DATA_DIR="$XDG_DATA_HOME/mise"
}''')
        script(p/'setup/check', '''event "$1" "$@"
[[ $HOME == "$EXPECTED_HOME" && $USER == tester && $DOTFILES_REPO_HOME == "$EXPECTED_DOTFILES" ]] || exit 99
[[ $XDG_CONFIG_HOME == "$EXPECTED_CONFIG" && $DOTSYS_REPO_HOME == "$EXPECTED_DOTSYS" ]] || exit 99
for key in XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME XDG_BIN_HOME XDG_RUNTIME_DIR; do
  expected=EXPECTED_$key
  [[ ${!key} == "${!expected}" ]] || exit 99
done
[[ " $* " != *' --save '* ]] || exit 99''')
        script(p/'setup/install', '''event install "$@"
mkdir -p "${GNUPGHOME:-$XDG_DATA_HOME/gnupg}"
printf installed > "$HOME/config-installed"''')
        (p/'setup/managed.py').write_text('# Fixture registration engine marker')
        (p/'config/mise').mkdir(parents=True); (p/'config/mise/config.toml').write_text('[tools]\nnodejs = "26.7.0"\n')
        script(p/'bin/autoload/dots', 'event RECURSION; exit 99')
    subprocess.run([real_git,'-C',str(p),'add','.'],env=base,check=True)
    subprocess.run([real_git,'-C',str(p),'commit','-qm','fixture'],env=base,check=True)

# Exercise the actual handoff, platform entrypoints, native bootstrap lists,
# mise/GnuPG and source acquisition. F install/check and service stage boundaries
# are deliberately fake; actual preparation scripts are covered separately.
fixture_s = sandbox/'dotsys'; fixture_s.mkdir()
owned = ['shared/install.sh','shared/repositories.sh','shared/helper-env.sh','shared/mise/init.sh','shared/gnupg/init.sh','shared/brew/init.sh',
         'arch/packages/init.sh','void/packages/init.sh']
owned += [p+'/init.sh' for p in ('arch','void','macos','wsl')]
for name in owned:
    p=fixture_s/name; p.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(root/name,p)
    # Redirect native Homebrew lookup roots too: real macOS/Linuxbrew installs
    # must never outrank fixture commands on a developer's machine.
    if name in ('shared/install.sh','shared/brew/init.sh'):
        p.write_text(p.read_text().replace('/opt/homebrew',str(sandbox/'native/homebrew'))
                     .replace('/home/linuxbrew/.linuxbrew',str(sandbox/'native/linuxbrew')))
script(fixture_s/'shared/register-helpers', '''[[ $1 == apply && $2 == --dotfiles-root && $3 == "$EXPECTED_DOTFILES" ]] || exit 99
event registration "$@"''')
script(fixture_s/'arch/preflight.sh', '[[ ${1:-} == --aur ]] || event full-preflight')
for service in ('amdgpu-brightness','wifi','bluetooth','kanata','power-profiles'):
    script(fixture_s/'arch/init.d'/f'{service}.sh', 'event full-'+service)
script(fixture_s/'arch/misc.sh', 'event full-misc')
for platform in ('arch','void'):
    for service in ('sway','greetd','kanshi','turnstile','pipewire'):
        script(fixture_s/platform/'init.d'/f'{service}.sh', 'event "${1#--}-'+service+'" "$@"')

checks=0
def run(name, platform='arch', selection='sway', fail='', extra=(), changes=None, failure=False, alias=False, setup_flags=None, explicit_paths=False):
    global checks
    d=sandbox/name; d.mkdir()
    env=dict(base, TEST_PLATFORM=platform, FAIL_AT=fail, EVENTS=str(d/'events'))
    for key, leaf in (('HOME','home'),('XDG_CONFIG_HOME','config space'),('XDG_DATA_HOME','data'),('XDG_STATE_HOME','state'),('XDG_CACHE_HOME','cache'),('XDG_BIN_HOME','bin-home'),('XDG_RUNTIME_DIR','runtime')):
        env[key]=str(d/leaf); Path(env[key]).mkdir()
    env.update(EXPECTED_HOME=env['HOME'], EXPECTED_CONFIG=env['XDG_CONFIG_HOME'], EXPECTED_DOTFILES=str(d/'dotfiles'), EXPECTED_DOTSYS=str(fixture_s))
    env.update({'EXPECTED_'+key:env[key] for key in ('XDG_DATA_HOME','XDG_STATE_HOME','XDG_CACHE_HOME','XDG_BIN_HOME','XDG_RUNTIME_DIR')})
    env.update({f'DOTSYS_{p.upper()}_SOURCE':str(sources/p) for p in ('dotfiles','dotvim','dotshell')})
    if changes: env.update(changes)
    args=['--dotfiles-root',str(d/'dotfiles'),'--dotvim-root',str(d/'dotvim'),'--dotshell-root',str(d/'dotshell')]
    if selection is not None: args+=['--select',selection]
    if explicit_paths:
        for key in ('HOME','XDG_CONFIG_HOME','XDG_DATA_HOME','XDG_STATE_HOME','XDG_CACHE_HOME','XDG_BIN_HOME'):
            args+=['--'+key.lower().replace('_','-'),env[key]]
            env[key]=str(d/'unused-inherited'/key)
        args+=['--user','tester']
    if setup_flags is not None:
        subprocess.run([real_git,'clone','-q',str(sources/'dotfiles'),str(d/'dotfiles')],env=env,check=True)
        command=['bash',str(fixture_s/'shared/install.sh'),'setup','--platform',platform,*setup_flags]
    elif alias: command=['bash',str(fixture_s/'shared/install.sh'),'setup','--'+platform]
    else: command=['bash',str(fixture_s/platform/'init.sh')]
    result=subprocess.run(command+args+list(extra),env=env,cwd=fixture_s,capture_output=True)
    assert (result.returncode != 0) == (bool(fail) or failure), (name,result.returncode,result.stdout,result.stderr)
    events=(d/'events').read_text().splitlines() if (d/'events').exists() else []
    assert not any('RECURSION' in x or 'forbidden' in x for x in events), events
    if fail:
        assert b'dependent stages stopped' in result.stderr, result.stderr
        assert events[-1].split()[0] == fail, (name,events)
        if not fail.startswith('activate-'): assert not any(x.startswith('activate-') for x in events)
    checks+=1
    return d,events

_, events=run('arch-success', extra=('--save','--user','tester','--wezterm-destination','', '--adopt',str(sandbox/'approval')))
labels=[x.split()[0] for x in events]
expected=['bootstrap','acquire-dotfiles','packages-sway','prerequisites','install','runtime-query','runtime','gnupg','acquire-dotvim','acquire-dotshell','registration','prepare-sway','prepare-greetd','prepare-kanshi','readiness','activate-sway','activate-kanshi','activate-greetd']
assert labels == expected, events
assert '--save' in next(x for x in events if x.startswith('install '))
assert '--config' not in next(x for x in events if x.startswith('runtime '))
assert 'nodejs@26.7.0 rust@latest' in next(x for x in events if x.startswith('runtime '))
# Every boundary, including activation failure, stops dependent work.
for index, label in enumerate(expected): run('fail-'+str(index),fail=label)
_, events=run('void',platform='void')
labels=[x.split()[0] for x in events]
assert labels.index('prepare-turnstile') < labels.index('readiness') < labels.index('activate-turnstile')
assert labels[-1] == 'activate-greetd'
assert '--void-autotiling' in next(x for x in events if x.startswith('registration '))
for label in ('prepare-turnstile','prepare-pipewire','activate-turnstile','activate-pipewire'):
    run('void-fail-'+label, platform='void', fail=label)
_,events=run('full-arch',extra=('--full-machine',))
labels=[x.split()[0] for x in events]
assert labels.index('readiness') < labels.index('full-preflight') < labels.index('full-misc') < labels.index('activate-sway')
assert labels[-1] == 'activate-greetd'
run('full-failure',extra=('--full-machine',),fail='full-misc')
for platform, selection in (('macos','macos-desktop'),('wsl','wsl-integration')):
    _,events=run(platform,platform=platform,selection=selection,extra=('--wezterm-destination','C:\\Users\\fixture name\\wezterm.lua') if platform=='wsl' else ())
    assert not any('prepare-sway' in x for x in events)
    if platform=='macos': assert next(i for i,x in enumerate(events) if x.startswith('activate-macos')) > next(i for i,x in enumerate(events) if x.startswith('readiness'))
run('explicit-paths', explicit_paths=True, changes={'DOTFILES_REPO_HOME':str(sandbox/'stale-dotfiles'), 'DOTSYS_REPO_HOME':str(sandbox/'stale-dotsys')})
_,events=run('empty',selection='',changes={'DOTS_INSTALL_SELECTION':'sway'},extra=('--dotfiles','--dotvim'))
assert not any('shell' in x or 'activate-' in x for x in events)
_,events=run('explicit-shell',selection='',extra=('--dotshell',))
assert any(x.startswith('acquire-dotshell') for x in events) and not any(x.startswith('activate-') for x in events)
_,events=run('alias',selection=None,alias=True)
assert any(x.startswith('acquire-dotshell') for x in events)
_,events=run('saved',selection=None,changes={'SAVED_SELECTION':'sway'})
assert any(x.startswith('acquire-dotshell') for x in events)
_,events=run('root-reject',changes={'TEST_UID':'0'},failure=True); assert not events
_,events=run('provider-reject',changes={'PROVIDER_FAIL':'yes'},failure=True); assert not events
_,events=run('void-musl',platform='void',changes={'VOID_ARCH':'x86_64-musl'},failure=True); assert not events
_,events=run('user-reject',extra=('--user','someone-else'),failure=True); assert not events
_,events=run('relative-reject',extra=('--dotfiles-root','relative'),failure=True); assert not events
for flag, expected in (('--dotvim',['acquire-dotvim','registration']), ('--dotshell',['acquire-dotshell','registration']),
                       ('--dotfiles',['install'])):
    _,events=run('tool-only-'+flag,selection=None,setup_flags=(flag,))
    assert [x.split()[0] for x in events] == expected, events
_,events=run('tool-only-both',selection=None,setup_flags=('--dotvim','--dotshell'))
assert [x.split()[0] for x in events] == ['acquire-dotvim','acquire-dotshell','registration']
assert '--dotvim-root' in events[-1] and '--dotshell-root' in events[-1]
_,events=run('tool-choice-reject',selection='sway',setup_flags=('--dotvim',),failure=True)
assert not events
print(f'handoff: {checks} controlled fixture runs passed (not real-platform acceptance)')
PY
