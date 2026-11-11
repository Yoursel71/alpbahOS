#!/bin/sh
# alpbahOS (D123, D164): apt, apt-get, apt-cache, aptitude, dnf, yum, pacman and zypper are not package managers on
# alpbahOS. /usr/bin/<name> is a link to this script so the hint also reaches 'sudo apt ...' (sudo looks the command up
# itself; a shell command_not_found handler never runs there). It only prints where packages come from and exits 1;
# it never installs or runs anything.
prog=${0##*/}
cmd=
case "$prog" in
  pacman)
    case "${1:-}" in
      -S|-Sy) cmd=install ;; -R|-Rs|-Rns) cmd=remove ;; -Ss|-Si) cmd=search ;; -Syu|-Su|-Syyu) cmd=upgrade ;;
    esac ;;
  *)
    case "${1:-}" in
      install|in|reinstall) cmd=install ;;
      remove|purge|erase|uninstall|rm|autoremove) cmd=remove ;;
      search|se|show|info|policy) cmd=search ;;
      update|upgrade|full-upgrade|dist-upgrade|refresh|up|makecache|check-update) cmd=upgrade ;;
    esac ;;
esac
[ $# -gt 0 ] && shift
{
  echo "alpbahOS'ta '$prog' yok: paketler alp ile kurulur."
  n=0
  for a in "$@"; do
    case "$a" in -*) continue ;; esac
    n=$((n + 1))
    case "$cmd" in
      install) echo "  sudo alp install $a" ;;
      remove) echo "  sudo alp remove $a" ;;
      search) echo "  alp search $a" ;;
    esac
  done
  case "$cmd" in
    upgrade) echo "  sudo alp update && sudo alp upgrade" ;;
    install|remove|search) [ "$n" -gt 0 ] || echo "  alp help" ;;
    *) echo "  alp help" ;;
  esac
  echo "alp'de olmayan uygulamalar Flathub'dan, Debian paketleri kullanıcının Debian kutusundan (apt) gelir:"
  echo "'sudo alp install <paket>' ikisini de sırayla dener."
  echo "Sürücüler (örneğin NVIDIA) kutudan gelemez; alp paketi olarak gelir: alp search nvidia"
} >&2
exit 1
