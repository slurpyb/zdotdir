# Add login identity to z1's existing right prompt using native Zsh escapes.
RPROMPT="${RPROMPT:+$RPROMPT }%b%u%s%f%k%B%F{cyan}%n@%m%f%b"
