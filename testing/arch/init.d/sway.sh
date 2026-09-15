#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
sandbox=$(mktemp -d "$root/.tmp-sway.XXXXXX")
trap 'rm -rf -- "$sandbox"' EXIT
export HOME="$sandbox/home" XDG_CONFIG_HOME="$sandbox/config" XDG_DATA_HOME="$sandbox/data"
export XDG_STATE_HOME="$sandbox/state" XDG_CACHE_HOME="$sandbox/cache" XDG_BIN_HOME="$sandbox/bin-home"
export XDG_RUNTIME_DIR="$sandbox/runtime" TMPDIR="$sandbox"
python3 -I -B - "$root" "$sandbox" <<'PY'
from pathlib import Path
import os, shutil, subprocess, sys
root, sandbox = map(Path, sys.argv[1:])
commands = sandbox/'commands'; commands.mkdir()
for name in ('bash','python3','dirname','mkdir','chmod','cat','cmp','ln','readlink','realpath','grep','rm','mktemp'):
    (commands/name).symlink_to(shutil.which(name))
def script(name, text):
    p = commands/name; p.write_text('#!/usr/bin/env bash\nset -e\n'+text+'\n'); p.chmod(0o755)
script('id', 'echo 1000')
script('lsmod', '[[ ${NVIDIA:-} != yes ]] || echo "nvidia 123 0"; exit 0')
for name in ('qs', 'uwsm'): script(name, 'exit 99')
script('sudo', '''[[ $1 == install && $2 == -Dm755 && $4 == /usr/local/bin/dotsys-sway-session ]] || exit 99
[[ -x $3 ]] || exit 99
printf 'install-wrapper\\n' >> "$EVENTS"''')
script('systemctl', 'printf "%s\\n" "$*" >> "$EVENTS"')
for name in ('pacman','paru','sv','loginctl'):
    script(name, 'printf "forbidden\\n" >> "$EVENTS"; exit 99')
base = {k:v for k,v in os.environ.items() if k == 'HOME' or k.startswith('XDG_') or k == 'TMPDIR'}
base.update(PATH=str(commands), DOTSYS_PLATFORM='arch', USER='tester')
checks = 0
for gpu in ('none','nvidia'):
    d = sandbox/gpu; d.mkdir()
    env = dict(base, NVIDIA='yes' if gpu=='nvidia' else 'no', EVENTS=str(d/'events'))
    for key, leaf in (('HOME','home'),('XDG_CONFIG_HOME','config space'),('XDG_DATA_HOME','data'),('XDG_STATE_HOME','state')):
        env[key] = str(d/leaf); Path(env[key]).mkdir()
    def run(phase, failure=False, extra=None):
        global checks
        result = subprocess.run(['bash',str(root/'arch/init.d/sway.sh'),phase],env=dict(env,**(extra or {})),capture_output=True)
        assert (result.returncode != 0) == failure, (result.stdout,result.stderr)
        checks += 1
    run('--prepare')
    state = Path(env['XDG_STATE_HOME'])/'dotsys/prepared'
    config, data = Path(env['XDG_CONFIG_HOME']), Path(env['XDG_DATA_HOME'])
    assert (state/'default-id').read_text() == 'sway.desktop\n'
    assert (state/'sway.desktop').exists() == (gpu == 'nvidia')
    assert not (config/'uwsm/default-id').exists() and not (data/'wayland-sessions').exists()
    assert not Path(env['EVENTS']).exists(), 'No service operations during preparation'
    assert env['XDG_CONFIG_HOME'] in (state/'dotsys-sway-session').read_text()
    before = (state/'default-id').stat()
    run('--prepare'); assert (state/'default-id').stat() == before
    run('--activate')
    assert os.readlink(config/'uwsm/default-id') == str(state/'default-id')
    if gpu == 'nvidia':
        assert os.readlink(data/'wayland-sessions/sway.desktop') == str(state/'sway.desktop')
        assert 'Exec=sway --unsupported-gpu' in (state/'sway.desktop').read_text()
    events = Path(env['EVENTS']).read_text().splitlines()
    assert events == ['install-wrapper','--user daemon-reload','--user enable '+str(state/'quickshell.service')]
    run('--activate', extra={'SWAYSOCK':str(d/'fixture-sway.sock')})
    assert Path(env['EVENTS']).read_text().splitlines()[-1] == '--user restart quickshell.service'
    # Retargeted session choices are preserved, not force linked.
    p = config/'uwsm/default-id'; p.unlink(); p.write_text('custom.desktop\n')
    run('--activate', failure=True)
    assert p.read_text() == 'custom.desktop\n'
print(f'Arch Sway: {checks} fixture checks passed (no real packages/services)')
PY
