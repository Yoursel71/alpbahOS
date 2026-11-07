# REBUILD-R3 test-skip shim. run-chroot.sh prepends this text to a chroot script when
# R3_SKIP_TESTS=1. Only test targets are skipped (each skip is logged); build steps are unchanged.
# The suites already ran in REBUILD-R2 (verification notes in docs/verification/).
_r3_skip_note() { echo "R3-SKIP test not run in REBUILD-R3: $*"; }
make() {
    local a
    for a in "$@"; do
        case $a in
            check|test|tests) _r3_skip_note make "$@"; return 0 ;;
        esac
    done
    command make "$@"
}
ninja() {
    case ${1:-} in
        test|check) _r3_skip_note ninja "$@"; return 0 ;;
    esac
    command ninja "$@"
}
meson() {
    if [ "${1:-}" = test ]; then _r3_skip_note meson "$@"; return 0; fi
    command meson "$@"
}
python3() {
    if [ "${1:-}" = -m ] && { [ "${2:-}" = test ] || [ "${2:-}" = pytest ]; }; then
        _r3_skip_note python3 "$@"; return 0
    fi
    command python3 "$@"
}
pytest() { _r3_skip_note pytest "$@"; return 0; }
ctest() { _r3_skip_note ctest "$@"; return 0; }
