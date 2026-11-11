# alpbahOS (D164): commands that 'alp install' exports from the Debian box are in ~/.local/bin. Appended to PATH, so a
# system command of the same name always wins. Not for root.
if [ -n "${HOME:-}" ] && [ "$(id -u)" != 0 ]; then
    case ":$PATH:" in
        *":$HOME/.local/bin:"*) ;;
        *) PATH="$PATH:$HOME/.local/bin"; export PATH ;;
    esac
fi
