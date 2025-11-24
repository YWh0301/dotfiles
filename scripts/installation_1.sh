#!/usr/bin/env bash
# TUI installer selector for Arch notes (Bash + dialog)
# Features:
# - Parse Markdown headings as groups, lines like "- `pkg`(AUR)" as packages
# - Default: AUR unselected; anything under "Additional Packages" unselected
# - Group-level ALL/NONE/PART; per-package checklist
# - Install order: pacman then yay

set -u
shopt -s extglob

err() { echo "Error: $*" >&2; }
need() { command -v "$1" >/dev/null 2>&1 || { err "missing dependency: $1"; exit 1; }; }

if [[ $# -lt 1 ]]; then
  NOTE_FILE="../manual/packages.md"
else
  NOTE_FILE="$1"
fi

[[ -f "$NOTE_FILE" ]] || { err "文件不存在: $NOTE_FILE"; exit 1; }

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
      # register as child of parent
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

# Ensure root (0) exists logically
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

count_selected_in() {
  local gid="$1"
  local sel=0 total=0
  for pid in $(get_descendant_packages "$gid"); do
    [[ -z "$pid" ]] && continue
    (( total++ ))
    if [[ "${P_SEL[$pid]-0}" -eq 1 ]]; then (( sel++ )); fi
  done
  echo "$sel/$total"
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

set_group_selection() {
  local gid="$1" val="$2"
  for pid in $(get_descendant_packages "$gid"); do
    [[ -n "$pid" ]] && P_SEL["$pid"]="$val"
  done
}

repo_badge() {
  case "$1" in
    aur) echo "AUR" ;;
    archlinuxcn) echo "archlinuxcn" ;;
    *) echo "official" ;;
  esac
}

# ---------------- Dialog helpers ----------------
d_menu() {
  local title="$1" text="$2"; shift 2
  local -a items=("$@")
  local h=22 w=100 m=12
  dialog --clear --no-collapse --title "$title" --menu "$text" "$h" "$w" "$m" "${items[@]}" 2>&1 >/dev/tty
}

d_checklist() {
  local title="$1" text="$2"; shift 2
  local -a items=("$@")
  local h=22 w=110 m=12
  dialog --clear --no-collapse --separate-output --output-fd 1 --title "$title" --checklist "$text" "$h" "$w" "$m" "${items[@]}"
}

d_msg() {
  local title="$1" text="$2"
  dialog --clear --title "$title" --msgbox "$text" 12 80
}

d_yesno() {
  local title="$1" text="$2"
  dialog --clear --title "$title" --yesno "$text" 14 90
}

# ---------------- UI flows ----------------
edit_group_packages() {
  local gid="$1"
  local pids=($(get_descendant_packages "$gid"))
  if [[ ${#pids[@]} -eq 0 ]]; then
    d_msg "空组" "这个组下没有可选的包。"
    return
  fi
  local -a items=()
  local idx=0
  for pid in "${pids[@]}"; do
    [[ -z "$pid" ]] && continue
    ((idx++))
    local g="${P_GROUP[$pid]}"
    local path="$(breadcrumb "$g")"
    local label="$(esc_label "${P_NAME[$pid]} [$(repo_badge "${P_REPO[$pid]}")]  (${path})")"
    local state=$([[ "${P_SEL[$pid]-0}" -eq 1 ]] && echo on || echo off)
    items+=("$pid" "$label" "$state")
  done
  local title="选择包"
  local text="组: $(breadcrumb "$gid")  空格切换; 回车确认"
  local sel
  if ! sel="$(d_checklist "$title" "$text" "${items[@]}")"; then
    return
  fi
  # First turn all off, then turn selected on
  for pid in "${pids[@]}"; do
    [[ -n "$pid" ]] && P_SEL["$pid"]=0
  done
  while read -r pid; do
    [[ -n "${pid:-}" ]] && P_SEL["$pid"]=1
  done <<< "$sel"
}

group_menu() {
  local gid="$1"
  while true; do
    local state="$(group_state "$gid")"
    local cnt="$(count_selected_in "$gid")"
    local header="组: $(breadcrumb "$gid")\n状态: [$state]  已选 $cnt"
    local -a items=()
    # Subgroups
    for cg in ${G_CHILD_GROUPS[$gid]:-}; do
      [[ -z "$cg" ]] && continue
      items+=("g:$cg" "进入子组: ${G_TITLE[$cg]} [$(group_state "$cg")] $(count_selected_in "$cg")")
    done
    # Actions
    items+=("sel_all" "将本组(含子组)全部标记为 安装")
    items+=("sel_none" "将本组(含子组)全部标记为 不安装")
    items+=("edit_pkgs" "编辑本组内所有包（含子组）")
    if [[ "$gid" == "0" ]]; then
      items+=("proceed" "开始安装")
      items+=("print" "仅打印安装命令（不执行）")
    fi
    items+=("back" $([[ "$gid" == "0" ]] && echo "退出" || echo "返回上一层"))
    local choice
    if ! choice="$(d_menu "选择组/操作" "$header" "${items[@]}")"; then
      [[ "$gid" == "0" ]] && return 2 || return 0
    fi
    case "$choice" in
      g:*)
        local tgt="${choice#g:}"
        group_menu "$tgt"
        local rc=$?
        [[ $rc -eq 1 || $rc -eq 3 ]] && return $rc
        ;;
      sel_all) set_group_selection "$gid" 1 ;;
      sel_none) set_group_selection "$gid" 0 ;;
      edit_pkgs) edit_group_packages "$gid" ;;
      proceed) return 1 ;;
      print) return 3 ;;
      back) [[ "$gid" == "0" ]] && return 2 || return 0 ;;
    esac
  done
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
  if [[ -z "${pac// /}" && -z "${aur// /}" ]]; then
    d_msg "提示" "没有选择需要安装的包。"
    return
  fi
  local msg="将执行以下命令（先 pacman 后 yay）：\n\n"
  if [[ -n "${pac// /}" ]]; then
    msg+="sudo pacman -S --needed ${pac}\n\n"
  fi
  if [[ -n "${aur// /}" ]]; then
    msg+="yay -S --needed ${aur}\n\n"
  fi
  msg+="继续执行吗？"
  if d_yesno "确认安装" "$msg"; then
    clear
    if [[ -n "${pac// /}" ]]; then
      sudo pacman -S --needed ${pac}
    fi
    if [[ -n "${aur// /}" ]]; then
      yay -S --needed ${aur}
    fi
    read -rp "安装流程结束，按回车返回。"
  fi
}

print_install_cmds() {
  local pac="$1" aur="$2"
  clear
  if [[ -n "${pac// /}" ]]; then
    echo "# pacman 安装（官方 + archlinuxcn 等仓库）"
    echo "sudo pacman -S --needed ${pac}"
    echo
  fi
  if [[ -n "${aur// /}" ]]; then
    echo "# yay 安装（AUR）"
    echo "yay -S --needed ${aur}"
    echo
  fi
  if [[ -z "${pac// /}" && -z "${aur// /}" ]]; then
    echo "# 没有选择需要安装的包"
  fi
  read -rp "已打印命令，按回车返回。"
}

# ---------------- Main UI ----------------
# 根菜单（组ID=0，显示其子组）
rc=0
while true; do
  group_menu 0
  rc=$?
  if [[ $rc -eq 1 ]]; then
    mapfile -t arr < <(collect_selected)
    run_install "${arr[0]}" "${arr[1]}"
  elif [[ $rc -eq 3 ]]; then
    mapfile -t arr < <(collect_selected)
    d_msg "提示" "命令将打印到当前终端。按回车后查看。"
    print_install_cmds "${arr[0]}" "${arr[1]}"
  else
    break
  fi
done
