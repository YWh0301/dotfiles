#!/usr/bin/env bash
# TUI installer selector for Arch notes (Bash + dialog)
# Requirements satisfied:
# - English-only UI/messages
# - Vim-like navigation: j/k move, h back, l or Enter to enter group, Space to toggle, Tab to switch top-level (##) tabs, q to quit
# - Structure:
#   - Tabs are level-2 headings (##); use Tab to cycle them
#   - On a tab page: show the tab group, its direct packages, all level-3 (###) groups expanded (their direct packages shown)
#   - Deeper groups (#### and deeper) appear collapsed; press l to enter them; deeper levels can be entered again with l
# - Toggle behavior:
#   - Space toggles package selection
#   - Space on a group toggles ALL/none for all packages under that group (descendants)
# - Status markers in labels: [ ] = none, [*] = partial, [x] = all/selected
# - Minimal output; no unnecessary prompts/messages
# - Install order: pacman first, then yay
# - Defaults: AUR unselected; anything under "Additional Packages" unselected

set -u
shopt -s extglob

err() { echo "Error: $*" >&2; }
need() { command -v "$1" >/dev/null 2>&1 || { err "missing dependency: $1"; exit 1; }; }

NOTE_FILE="${1:-../manual/packages.md}"
[[ -f "$NOTE_FILE" ]] || { err "file not found: $NOTE_FILE"; exit 1; }

need gawk
need dialog

# ---------------- Parse Markdown with gawk -> machine-readable lines ----------------
# G|gid|level|title|parent
# P|pid|name|repo|group|under_additional|default_selected
parse_output="$(gawk '
function trim(s){ sub(/^[ \t\r\n]+/,"",s); sub(/[ \t\r\n]+$/,"",s); return s; }
BEGIN{
  OFS="|";
  gid=0; pid=0;
  current[0]=0; # root group id
  titles[0]="ROOT";
  parents[0]=-1;
}
{
  line=$0
  # Headings
  if (match(line, /^(#{1,6})[[:space:]]+(.*)$/, m)) {
    level=length(m[1]);
    t=trim(m[2]);
    parent=( (level-1) in current ? current[level-1] : 0 );
    gid++;
    current[level]=gid;
    # clear deeper levels
    for (i=level+1; i<=10; i++) if (i in current) delete current[i];
    titles[gid]=t;
    parents[gid]=parent;
    print "G", gid, level, t, parent;
    next;
  }
  # Packages "- `name` (optional)"
  if (match(line, /^[[:space:]]*-[[:space:]]*`([^`]+)`[[:space:]]*(\(([^)]+)\))?/, m)) {
    name=trim(m[1]);
    annot=(m[3] ? m[3] : "");
    al=tolower(annot);
    repo="official";
    if (index(al,"aur")) repo="aur";
    else if (index(al,"archlinuxcn")) repo="archlinuxcn";
    # deepest current group
    maxl=0;
    for (k in current) if (k>maxl) maxl=k;
    g=(maxl in current ? current[maxl] : 0);
    # check if under Additional Packages
    ua=0;
    gg=g;
    while (gg!=0) {
      t=titles[gg];
      if (tolower(t)=="additional packages") { ua=1; break; }
      gg=parents[gg];
    }
    default_sel=(repo=="aur" || ua ? 0 : 1);
    pid++;
    print "P", pid, name, repo, g, ua, default_sel;
    next;
  }
}
' "$NOTE_FILE")"


# ---------------- Build in-memory structures ----------------
declare -A G_TITLE G_PARENT G_LEVEL G_CHILD_GROUPS
declare -A P_NAME P_REPO P_GROUP P_SEL
declare -A PIDS_BY_GROUP
GROUP_IDS=()
PACKAGE_IDS=()

while IFS='|' read -r typ a b c d e f; do
  case "$typ" in
    G)
      gid="$a"; level="$b"; title="$c"; parent="$d"
      G_TITLE["$gid"]="$title"
      G_PARENT["$gid"]="$parent"
      G_LEVEL["$gid"]="$level"
      G_CHILD_GROUPS["$parent"]="${G_CHILD_GROUPS[$parent]:-} $gid"
      GROUP_IDS+=("$gid")
      ;;
    P)
      pid="$a"; name="$b"; repo="$c"; group="$d"; under_add="$e"; default_sel="$f"
      P_NAME["$pid"]="$name"
      P_REPO["$pid"]="$repo"
      P_GROUP["$pid"]="$group"
      P_SEL["$pid"]="$default_sel"
      PIDS_BY_GROUP["$group"]="${PIDS_BY_GROUP[$group]:-} $pid"
      PACKAGE_IDS+=("$pid")
      ;;
  esac
done < <(printf "%s\n" "$parse_output")

# Ensure root (0)
G_TITLE[0]="ROOT"; G_PARENT[0]="-1"; G_LEVEL[0]=0

# ---------------- Helpers ----------------
esc_label() {
  local s=$1
  s=${s//$'\t'/ }
  s=${s//$'\n'/ }
  s=${s//\"/\\\"}
  echo "$s"
}

breadcrumb() {
  local gid="$1"
  local cur="$gid"
  local -a path=()
  while [[ "$cur" != "0" && "${G_PARENT[$cur]:-}" != "-1" ]]; do
    path+=("${G_TITLE[$cur]}")
    cur="${G_PARENT[$cur]}"
    [[ -z "$cur" ]] && break
  done
  local out=""
  for (( i=${#path[@]}-1; i>=0; i-- )); do
    [[ -n "$out" ]] && out+=" / "
    out+="${path[$i]}"
  done
  echo "${out:-ROOT}"
}

get_descendant_packages() {
  local gid="$1"
  local out=""
  for pid in ${PIDS_BY_GROUP[$gid]:-}; do
    [[ -n "$pid" ]] && out+="$pid "
  done
  for cg in ${G_CHILD_GROUPS[$gid]:-}; do
    [[ -n "$cg" ]] && out+="$(get_descendant_packages "$cg") "
  done
  echo "$out"
}

group_state() {
  local gid="$1"
  local sel=0 total=0
  for pid in $(get_descendant_packages "$gid"); do
    [[ -z "$pid" ]] && continue
    (( total++ ))
    if [[ "${P_SEL[$pid]-0}" -eq 1 ]]; then (( sel++ )); fi
  done
  if [[ $total -eq 0 ]]; then echo "EMPTY"
  elif [[ $sel -eq 0 ]]; then echo "NONE"
  elif [[ $sel -eq $total ]]; then echo "ALL"
  else echo "PART"
  fi
}

group_marker() {
  case "$(group_state "$1")" in
    ALL)  echo "[x]" ;;
    PART) echo "[*]" ;;
    NONE|EMPTY) echo "[ ]" ;;
  esac
}

pkg_marker() {
  local pid="$1"
  if [[ "${P_SEL[$pid]-0}" -eq 1 ]]; then echo "[x]"; else echo "[ ]"; fi
}

set_group_selection() {
  local gid="$1" val="$2"
  for pid in $(get_descendant_packages "$gid"); do
    [[ -n "$pid" ]] && P_SEL["$pid"]="$val"
  done
}

repo_badge() {
  case "$1" in
    aur) echo "{AUR}" ;;
    archlinuxcn) echo "{archlinuxcn}" ;;
    *) echo "" ;;
  esac
}

packages_direct_in_group() {
  local gid="$1"
  local out=""
  for pid in ${PIDS_BY_GROUP[$gid]:-}; do
    [[ -n "$pid" ]] && out+="$pid "
  done
  echo "$out"
}

# Top-level tabs (##)
L2_GIDS=()
for gid in "${GROUP_IDS[@]}"; do
  if [[ "${G_LEVEL[$gid]}" -eq 2 ]]; then
    L2_GIDS+=("$gid")
  fi
done
if [[ ${#L2_GIDS[@]} -eq 0 ]]; then
  L2_GIDS=(0)
fi

# ---------------- Dialog helpers ----------------
menu_dialog() {
  local title="$1" text="$2"; shift 2
  local -a items=("$@")
  local h=24 w=110 m=18

  local out
  out="$(
    dialog --clear --no-collapse \
      --title "$title" \
      --menu "$text" "$h" "$w" "$m" "${items[@]}" \
      --help-button --extra-button --stdout \
      --bindkey menu j down \
      --bindkey menu k up \
      --bindkey menu h cancel \
      --bindkey menu q cancel \
      --bindkey menu l ok \
      --bindkey menu " " extra \
      --bindkey menu TAB help
  )"
  local rc=$?
  printf "%s|%s" "$rc" "$out"
}

# ---------------- Page builder ----------------
build_page_items() {
  # stdout: sequence of tag + label for dialog --menu
  local tab_gid="$1" cur_gid="$2"

  # Optional command items (minimal)
  echo "CMD:INSTALL" "Install now"

  # Show current group header line (toggleable)
  local gmk="$(group_marker "$cur_gid")"
  local glabel="$(esc_label "$gmk ${G_TITLE[$cur_gid]}")"
  echo "G:$cur_gid" "$glabel"

  # Show packages directly under current group
  for pid in ${PIDS_BY_GROUP[$cur_gid]:-}; do
    [[ -z "$pid" ]] && continue
    local pmk="$(pkg_marker "$pid")"
    local badge="$(repo_badge "${P_REPO[$pid]}")"
    local label="$(esc_label "$pmk ${P_NAME[$pid]} ${badge}")"
    echo "P:$pid" "$label"
  done

  if [[ "$cur_gid" -eq "$tab_gid" ]]; then
    # Expand all immediate children (###)
    for cg in ${G_CHILD_GROUPS[$tab_gid]:-}; do
      [[ -z "$cg" ]] && continue
      local cmk="$(group_marker "$cg")"
      echo "G:$cg" "$(esc_label "$cmk ${G_TITLE[$cg]}")"
      # Packages directly under this ### group
      for pid in ${PIDS_BY_GROUP[$cg]:-}; do
        [[ -z "$pid" ]] && continue
        local pmk="$(pkg_marker "$pid")"
        local badge="$(repo_badge "${P_REPO[$pid]}")"
        echo "P:$pid" "$(esc_label "  $pmk ${P_NAME[$pid]} ${badge}")"
      done
      # Show deeper groups (####) as collapsed entries only (no packages)
      for d1 in ${G_CHILD_GROUPS[$cg]:-}; do
        [[ -z "$d1" ]] && continue
        local dmk="$(group_marker "$d1")"
        echo "G:$d1" "$(esc_label "  $dmk ${G_TITLE[$d1]}")"
      done
    done
  else
    # Inside a deeper group: list its child groups as collapsed entries (no packages)
    for cg in ${G_CHILD_GROUPS[$cur_gid]:-}; do
      [[ -z "$cg" ]] && continue
      local cmk="$(group_marker "$cg")"
      echo "G:$cg" "$(esc_label "$cmk ${G_TITLE[$cg]}")"
    done
  fi
}

# ---------------- Selection and actions ----------------
toggle_item() {
  local tag="$1"
  case "$tag" in
    P:*)
      local pid="${tag#P:}"
      if [[ "${P_SEL[$pid]-0}" -eq 1 ]]; then P_SEL["$pid"]=0; else P_SEL["$pid"]=1; fi
      ;;
    G:*)
      local gid="${tag#G:}"
      case "$(group_state "$gid")" in
        ALL) set_group_selection "$gid" 0 ;;
        PART|NONE|EMPTY) set_group_selection "$gid" 1 ;;
      esac
      ;;
  esac
}

collect_selected() {
  # stdout: two lines: PACMAN_PKGS (space-separated), AUR_PKGS (space-separated)
  declare -A seen=()
  local pac="" aur=""
  for pid in "${PACKAGE_IDS[@]}"; do
    [[ -z "$pid" ]] && continue
    if [[ "${P_SEL[$pid]-0}" -eq 1 ]]; then
      local name="${P_NAME[$pid]}"
      [[ -n "${seen[$name]:-}" ]] && continue
      seen["$name"]=1
      if [[ "${P_REPO[$pid]}" == "aur" ]]; then
        aur+="$name "
      else
        pac+="$name "
      fi
    fi
  done
  echo "$pac"
  echo "$aur"
}

run_install() {
  local pac="$1" aur="$2"
  clear
  set +e
  if [[ -n "${pac// /}" ]]; then
    sudo pacman -S --needed ${pac}
  fi
  if [[ -n "${aur// /}" ]]; then
    yay -S --needed ${aur}
  fi
  set -e
}

print_install_cmds() {
  local pac="$1" aur="$2"
  if [[ -n "${pac// /}" ]]; then
    echo "sudo pacman -S --needed ${pac}"
  fi
  if [[ -n "${aur// /}" ]]; then
    echo "yay -S --needed ${aur}"
  fi
}

# ---------------- Main UI loop ----------------
current_tab_idx=0
current_tab_gid="${L2_GIDS[$current_tab_idx]}"
current_gid="$current_tab_gid"

while true; do
  # Build tab line
  tabline=""
  for i in "${!L2_GIDS[@]}"; do
    gid="${L2_GIDS[$i]}"
    if [[ "$i" -eq "$current_tab_idx" ]]; then
      tabline+="[${G_TITLE[$gid]}] "
    else
      tabline+="${G_TITLE[$gid]} "
    fi
  done
  title="Arch package selector"
  text="Tabs (##): ${tabline}
Path: $(breadcrumb "$current_gid")
Keys: j/k move, l/Enter enter, h back, SPACE toggle, TAB next tab, q quit"

  # Build items array
  mapfile -t raw_items < <(build_page_items "$current_tab_gid" "$current_gid")
  # raw_items contains alternating lines: tag label
  items=()
  i=0
  while [[ $i -lt ${#raw_items[@]} ]]; do
    items+=("${raw_items[$i]}" "${raw_items[$((i+1))]}")
    i=$((i+2))
  done

  resp="$(menu_dialog "$title" "$text" "${items[@]}")"
  rc="${resp%%|*}"
  sel="${resp#*|}"

  case "$rc" in
    0) # OK (Enter or l)
      case "$sel" in
        CMD:INSTALL)
          mapfile -t arr < <(collect_selected)
          run_install "${arr[0]}" "${arr[1]}"
          ;;
        G:*)
          # Enter group
          gid="${sel#G:}"
          current_gid="$gid"
          ;;
        P:*)
          # Do nothing on OK for packages; space is the toggle
          ;;
        *) ;;
      esac
      ;;
    2) # HELP (TAB mapped here) -> next tab
      # cycle to next tab
      current_tab_idx=$(( (current_tab_idx + 1) % ${#L2_GIDS[@]} ))
      current_tab_gid="${L2_GIDS[$current_tab_idx]}"
      current_gid="$current_tab_gid"
      ;;
    3) # EXTRA (SPACE mapped here) -> toggle item
      toggle_item "$sel"
      ;;
    1|255) # CANCEL/ESC (h or q)
      # go back if possible, else quit
      if [[ "$current_gid" != "$current_tab_gid" ]]; then
        current_gid="${G_PARENT[$current_gid]}"
        [[ -z "$current_gid" ]] && current_gid="$current_tab_gid"
      else
        clear
        exit 0
      fi
      ;;
    *) ;;
  esac
done
