#
# common-functions - Zsh functions
#

##? Show all extensions in current folder structure.
function allexts {
  find . -not \( -path '*/.git/*' -prune \) -type f -name '*.*' | sed 's|.*\.|\.|' | sort | uniq -c
}

##? Backup files or directories
function bak {
  local now f
  now=$(date +"%Y%m%d-%H%M%S")
  for f in "$@"; do
    if [[ ! -e "$f" ]]; then
      echo "file not found: $f" >&2
      continue
    fi
    cp -R "$f" "$f".$now.bak
  done
}

##? noext - Find files with no file extension
function noext {
  # for fun, rename with: noext -exec mv '{}' '{}.sql' \;
  find . -not \( -path '*/.git/*' -prune \) -type f ! -name '*.*'
}

##? optdiff - show a diff between set options and Zsh defaults
function optdiff {
  tmp1=$(mktemp)
  tmp2=$(mktemp)
  zsh -df -c "set -o" >| $tmp1
  set -o >| $tmp2
  gdiff --changed-group-format='%<' --unchanged-group-format='' $tmp2 $tmp1
  rm $tmp1 $tmp2
}

##? Remove zwc files
function rmzwc {
  if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    echo "rmzwc"
    echo "  removes zcompiled files"
    echo "options:"
    echo " -q         Quiet"
    echo " --dry-run  Dry run"
    echo " -h --help  Show help screen"
    return 0
  fi

  local findprint="-print"
  local finddel="-delete"
  if [[ "$1" == '-q' ]]; then
    findprint=""
  elif [[ "$1" == "--dry-run" ]]; then
    finddel=""
  fi

  if [[ -d "${ZDOTDIR}" ]]; then
    find "${ZDOTDIR:A}" -type f \( -name "*.zwc" -o -name "*.zwc.old" \) $findprint $finddel
  fi
  find "$HOME" -maxdepth 1 -type f \( -name "*.zwc" -o -name "*.zwc.old" \) $findprint $finddel
  find . -maxdepth 1 -type f \( -name "*.zwc" -o -name "*.zwc.old" \) $findprint $finddel
}

##? Substitutes string parts with environment variables
function substenv {
  if (( $# == 0 )); then
    subenv ZDOTDIR | subenv HOME
  else
    local sedexp="s|${(P)1}|\$$1|g"
    shift
    sed "$sedexp" "$@"
  fi
}

##? Better tail -f
function tailf {
  local nl
  tail -f $2 | while read j; do
    print -n "$nl$j"
    nl="\n"
  done
}

##? Makes any dirs recursively and then touches a file if it doesn't exist
function touchf {
  if [[ -n "$1" ]] && [[ ! -f "$1" ]]; then
    mkdir -p "$1:h" && touch "$1"
  fi
}

##? What's the weather?
function weather {
  curl "http://wttr.in/$1"
}

##? Compile Zsh files in a directory
function zcompiledir {
  emulate -L zsh; setopt localoptions extendedglob globdots globstarshort nullglob rcquotes
  autoload -U zrecompile

  local f
  local flag_clean=false
  [[ "$1" == "-c" ]] && flag_clean=true && shift
  if [[ -z "$1" ]] || [[ ! -d "$1" ]]; then
    echo "Bad or missing directory $1" && return 1
  fi

  if [[ $flag_clean == true ]]; then
    for f in "$1"/**/*.zwc(.N) "$1"/**/*.zwc.old(.N); do
      echo "removing $f" && command rm -f "$f"
    done
  else
    for f in "$1"/**/*.zsh{,-theme}; do
      echo "compiling $f" && zrecompile -pq "$f"
    done
  fi
}

##? Echo to stderror
function echoerr {
  echo >&2 "$@"
}

##? Pass thru for copy/paste markdown
function $ { $@ }

##? Find file under the current directory
function ff {
  /usr/bin/find . -name "$@"
}

##? Find file whose name starts with a given string
function ffs () {
  /usr/bin/find . -name "$@"'*'
}

##? Find file whose name ends with a given string
function ffe () {
  /usr/bin/find . -name '*'"$@"
}

findPid () { lsof -t -c "$@" ; }

function ssh_expose() {
    emulate -L zsh
    local TARGET_HOST=$1
    local TARGET_PORT=$2
    local LOCAL_PORT=$3

    local HELP_MESSAGE="ssh_expose - syntax: ssh_expose TARGET_HOST TARGET_PORT LOCAL_PORT - ssh_expose example@host 80 8080"

    if [[ -z $TARGET_HOST ]]; then
        echo $HELP_MESSAGE
        return 1
    fi
    if [[ -z $TARGET_PORT ]]; then
        echo $HELP_MESSAGE
        return 1
    fi
    if [[ -z $LOCAL_PORT ]]; then
        echo $HELP_MESSAGE
        return 1
    fi

    echo "Redirecting $TARGET_HOST:$TARGET_PORT -> localhost:$LOCAL_PORT"
    echo "SSH tunnel will automatically close after 30 minutes"
    timeout 1800 ssh -L "$LOCAL_PORT"':localhost:'"$TARGET_PORT" "$TARGET_HOST"
    local EXIT_CODE=$?
    if [[ $EXIT_CODE -eq 124 ]]; then
        echo "SSH tunnel closed due to 30-minute timeout"
    else
        echo "done!"
    fi
}


domain_audit() {
    local domain="$1"
    if [[ -z "$domain" ]]; then
      echo "Usage: domain_audit <domain>"
      return 1
    fi

    # Helper: trim and fit values into a fixed-width column
    local __da_width=54
    __da_trim() { sed 's/^[[:space:]]*//; s/[[:space:]]*$//'; }
    __da_fit() {
      local s="$1" max="$2"
      if (( ${#s} > max )); then
        printf "%s..." "${s[1,$((max-3))]}"
      else
        printf "%s" "$s"
      fi
    }

    # DNS lookups
    local a_records="$(dig +short A "$domain" | tr '\n' ' ' | __da_trim)"
    local aaaa_records="$(dig +short AAAA "$domain" | tr '\n' ' ' | __da_trim)"
    local cname="$(dig +short CNAME "$domain" | sed 's/\.$//' | head -n1 | __da_trim)"
    local ns_records="$(dig +short NS "$domain" | tr '\n' ' ' | __da_trim)"
    local mx_records="$(dig +short MX "$domain" | awk '{print $2}' | tr '\n' ' ' | __da_trim)"
    local txt_spf="$(dig +short TXT "$domain" | tr '\n' ' ' | sed 's/"//g' | grep -i 'v=spf1' | head -n1 | __da_trim)"

    # rDNS for first A record
    local first_ip="$(echo "$a_records" | awk '{print $1}')"
    local rdns=""
    if [[ -n "$first_ip" ]]; then
      rdns="$(nslookup "$first_ip" 2>/dev/null | awk -F'= ' '/name =/ {print $2}' | sed 's/\.$//' | head -n1 | __da_trim)"
    fi

    # HTTP/S details
    local scheme="https"
    local head="$(curl -Is --max-time 6 "https://$domain" 2>/dev/null)"
    if [[ -z "$head" ]]; then
      scheme="http"
      head="$(curl -Is --max-time 6 "http://$domain" 2>/dev/null)"
    fi
    local url="$scheme://$domain"
    local status="$(echo "$head" | awk 'NR==1{print $2}' | head -n1 | __da_trim)"
    local server="$(echo "$head" | awk -F': ' 'tolower($1)=="server"{print $2}' | head -n1 | __da_trim)"
    local location="$(echo "$head" | awk -F': ' 'tolower($1)=="location"{print $2}' | head -n1 | __da_trim)"
    local content_type="$(echo "$head" | awk -F': ' 'tolower($1)=="content-type"{print $2}' | head -n1 | __da_trim)"
    local final_url="$(curl -Ls -o /dev/null -w '%{url_effective}' --max-time 8 "$url" 2>/dev/null | __da_trim)"

    # Title from final URL
    local title="$(curl -Ls --max-time 8 "${final_url:-$url}" 2>/dev/null \
      | tr '\n' ' ' \
      | sed -n 's/.*<title[^>]*>\(.*\)<\/title>.*/\1/ip' \
      | head -n1 | __da_trim)"
    title="${title:-"(no title found)"}"

    # TLS certificate info (best-effort)
    local tls_subject="" tls_issuer="" tls_not_before="" tls_not_after=""
    local tls_meta="$(printf '' | openssl s_client -servername "$domain" -connect "$domain:443" 2>/dev/null \
      | openssl x509 -noout -subject -issuer -dates 2>/dev/null)"
    tls_subject="$(echo "$tls_meta" | sed -n 's/^subject=//p' | head -n1 | __da_trim)"
    tls_issuer="$(echo "$tls_meta" | sed -n 's/^issuer=//p' | head -n1 | __da_trim)"
    tls_not_before="$(echo "$tls_meta" | sed -n 's/^notBefore=//p' | head -n1 | __da_trim)"
    tls_not_after="$(echo "$tls_meta" | sed -n 's/^notAfter=//p' | head -n1 | __da_trim)"

    # WHOIS info (best-effort)
    local registrar="" created="" updated="" expires=""
    if command -v whois >/dev/null 2>&1; then
      local whois_raw="$(whois "$domain" 2>/dev/null)"
      registrar="$(echo "$whois_raw" | awk -F': ' 'tolower($1)=="registrar"{print $2; exit}' | __da_trim)"
      created="$(echo "$whois_raw" | awk -F': ' 'tolower($1)~/creation date|created/{print $2; exit}' | __da_trim)"
      updated="$(echo "$whois_raw" | awk -F': ' 'tolower($1)~/updated date|updated on|last updated/{print $2; exit}' | __da_trim)"
      expires="$(echo "$whois_raw" | awk -F': ' 'tolower($1)~/expiry date|expiration date|registry expiry date/{print $2; exit}' |
  __da_trim)"
    else
      registrar="(whois not installed)"
    fi

    # Hosting guess (simple heuristics)
    local host_guess="Unknown"
    local sig="$cname $rdns $a_records $ns_records"
    if echo "$sig" | grep -qi 'cloudflare'; then host_guess="Cloudflare"
    elif echo "$sig" | grep -qi 'fastly'; then host_guess="Fastly"
    elif echo "$sig" | grep -qi 'akamai'; then host_guess="Akamai"
    elif echo "$sig" | grep -qi 'amazonaws\|amazon'; then host_guess="AWS"
    elif echo "$sig" | grep -qi 'azure\|microsoft'; then host_guess="Azure"
    elif echo "$sig" | grep -qi 'google\|goog'; then host_guess="Google Cloud"
    elif echo "$sig" | grep -qi 'vercel'; then host_guess="Vercel"
    elif echo "$sig" | grep -qi 'netlify'; then host_guess="Netlify"
    elif echo "$sig" | grep -qi 'github\.io'; then host_guess="GitHub Pages"
    fi

    # Table output
    local sep="+----------------------+--------------------------------------------------------+"
    printf "%s\n" "$sep"
    printf "| %-20s | %-54s |\n" "Field" "Value"
    printf "%s\n" "$sep"
    printf "| %-20s | %-54s |\n" "Domain" "$(__da_fit "$domain" $__da_width)"
    printf "| %-20s | %-54s |\n" "A Records" "$(__da_fit "${a_records:-"(none)"}" $__da_width)"
    printf "| %-20s | %-54s |\n" "AAAA Records" "$(__da_fit "${aaaa_records:-"(none)"}" $__da_width)"
    printf "| %-20s | %-54s |\n" "CNAME" "$(__da_fit "${cname:-"(none)"}" $__da_width)"
    printf "| %-20s | %-54s |\n" "NS" "$(__da_fit "${ns_records:-"(none)"}" $__da_width)"
    printf "| %-20s | %-54s |\n" "MX" "$(__da_fit "${mx_records:-"(none)"}" $__da_width)"
    printf "| %-20s | %-54s |\n" "SPF" "$(__da_fit "${txt_spf:-"(none)"}" $__da_width)"
    printf "| %-20s | %-54s |\n" "rDNS (1st A)" "$(__da_fit "${rdns:-"(none)"}" $__da_width)"
    printf "| %-20s | %-54s |\n" "Hosting Guess" "$(__da_fit "$host_guess" $__da_width)"
    printf "| %-20s | %-54s |\n" "HTTP Status" "$(__da_fit "${status:-"(none)"}" $__da_width)"
    printf "| %-20s | %-54s |\n" "Final URL" "$(__da_fit "${final_url:-"(none)"}" $__da_width)"
    printf "| %-20s | %-54s |\n" "Redirect" "$(__da_fit "${location:-"(none)"}" $__da_width)"
    printf "| %-20s | %-54s |\n" "Server" "$(__da_fit "${server:-"(none)"}" $__da_width)"
    printf "| %-20s | %-54s |\n" "Content-Type" "$(__da_fit "${content_type:-"(none)"}" $__da_width)"
    printf "| %-20s | %-54s |\n" "Root Title" "$(__da_fit "$title" $__da_width)"
    printf "| %-20s | %-54s |\n" "TLS Subject" "$(__da_fit "${tls_subject:-"(none)"}" $__da_width)"
    printf "| %-20s | %-54s |\n" "TLS Issuer" "$(__da_fit "${tls_issuer:-"(none)"}" $__da_width)"
    printf "| %-20s | %-54s |\n" "TLS Not Before" "$(__da_fit "${tls_not_before:-"(none)"}" $__da_width)"
    printf "| %-20s | %-54s |\n" "TLS Not After" "$(__da_fit "${tls_not_after:-"(none)"}" $__da_width)"
    printf "| %-20s | %-54s |\n" "Registrar" "$(__da_fit "${registrar:-"(none)"}" $__da_width)"
    printf "| %-20s | %-54s |\n" "Created" "$(__da_fit "${created:-"(none)"}" $__da_width)"
    printf "| %-20s | %-54s |\n" "Updated" "$(__da_fit "${updated:-"(none)"}" $__da_width)"
    printf "| %-20s | %-54s |\n" "Expires" "$(__da_fit "${expires:-"(none)"}" $__da_width)"
    printf "%s\n" "$sep"
}
