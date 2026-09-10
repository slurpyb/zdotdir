# Add login identity to z1's existing right prompt using native Zsh escapes.
RPROMPT="${RPROMPT:+$RPROMPT }%b%u%s%f%k%n@%m"
