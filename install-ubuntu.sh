#!/usr/bin/env bash
set -Eeuo pipefail

APP_NAME="sub2api"
SERVICE_NAME="${SERVICE_NAME:-sub2api}"
SERVICE_USER="${SERVICE_USER:-sub2api}"
INSTALL_DIR="${INSTALL_DIR:-/opt/sub2api}"
CONFIG_DIR="${CONFIG_DIR:-/etc/sub2api}"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
ENV_FILE="${CONFIG_DIR}/${SERVICE_NAME}.env"
PACKAGE_DIR="${PACKAGE_DIR:-}"
SERVER_HOST="${SERVER_HOST:-0.0.0.0}"
SERVER_PORT="${SERVER_PORT:-1122}"
TIMEZONE="${TIMEZONE:-Asia/Shanghai}"
COMMAND="install"
YES=0
PURGE=0
FORCE_CONFIG=0
OPEN_FIREWALL=0

info() { printf '[INFO] %s\n' "$*"; }
ok() { printf '[OK] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
die() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Sub2API Ubuntu release installer

Usage:
  sudo bash deploy/linux/install-ubuntu.sh [install|upgrade] [options]
  sudo bash deploy/linux/install-ubuntu.sh [status|restart|logs]
  sudo bash deploy/linux/install-ubuntu.sh uninstall [--purge]

Options:
  --package-dir <dir>  Release archive root (auto-detected by default)
  --install-dir <dir> Installation directory (default: /opt/sub2api)
  --host <address>    Listen address (default: 0.0.0.0)
  --port <port>       Listen port (default: 1122)
  --timezone <name>   Timezone (default: Asia/Shanghai)
  --force-config      Replace config.yaml after backing it up
  --open-firewall     Add a UFW TCP rule for the selected port when UFW is active
  --purge             Remove data, backups, configuration, and the service account
  -y, --yes           Skip confirmation prompts
  -h, --help          Show this help

The release binary contains the frontend. No Go, Node.js, pnpm, or reverse proxy is
installed by this script. The service listens directly on the selected host and port.
EOF
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      install|upgrade|update|status|restart|logs|uninstall|remove)
        COMMAND="$1"; shift ;;
      --package-dir) PACKAGE_DIR="${2:-}"; shift 2 ;;
      --package-dir=*) PACKAGE_DIR="${1#*=}"; shift ;;
      --install-dir) INSTALL_DIR="${2:-}"; shift 2 ;;
      --install-dir=*) INSTALL_DIR="${1#*=}"; shift ;;
      --host) SERVER_HOST="${2:-}"; shift 2 ;;
      --host=*) SERVER_HOST="${1#*=}"; shift ;;
      --port) SERVER_PORT="${2:-}"; shift 2 ;;
      --port=*) SERVER_PORT="${1#*=}"; shift ;;
      --timezone) TIMEZONE="${2:-}"; shift 2 ;;
      --timezone=*) TIMEZONE="${1#*=}"; shift ;;
      --force-config) FORCE_CONFIG=1; shift ;;
      --open-firewall) OPEN_FIREWALL=1; shift ;;
      --purge) PURGE=1; shift ;;
      -y|--yes) YES=1; shift ;;
      -h|--help) usage; exit 0 ;;
      *) die "Unknown argument: $1" ;;
    esac
  done
}

require_root() {
  [ "$(id -u)" -eq 0 ] || die "Run this command as root, for example: sudo bash deploy/linux/install-ubuntu.sh";
}

require_systemd() {
  command -v systemctl >/dev/null 2>&1 || die "systemctl is required; this release targets Ubuntu systemd hosts";
  [ -d /run/systemd/system ] || warn "systemd is not running in this shell; installation can continue, but start the service after booting normally";
}

safe_install_path() {
  local path="$1"
  [ -n "$path" ] || die "Install path cannot be empty"
  [[ "$path" = /* ]] || die "Install path must be absolute: $path"
  [[ "$path" =~ ^[A-Za-z0-9._/-]+$ ]] || die "Install path contains unsupported characters: $path"
  case "$path" in
    /|/bin|/boot|/dev|/etc|/home|/lib|/lib64|/media|/mnt|/opt|/proc|/root|/run|/sbin|/srv|/sys|/tmp|/usr|/var)
      die "Refusing unsafe install path: $path" ;;
  esac
}

resolve_package_dir() {
  if [ -z "$PACKAGE_DIR" ]; then
    local script_dir legacy_dir
    script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || die "Cannot locate release directory"
    if [ -f "$script_dir/sub2api" ]; then
      PACKAGE_DIR="$script_dir"
    else
      legacy_dir="$(cd -- "$script_dir/../.." 2>/dev/null && pwd)" || die "Cannot locate release directory"
      PACKAGE_DIR="$legacy_dir"
    fi
  else
    PACKAGE_DIR="$(cd -- "$PACKAGE_DIR" 2>/dev/null && pwd)" || die "Package directory does not exist: $PACKAGE_DIR"
  fi
  [ -f "$PACKAGE_DIR/sub2api" ] || die "Missing release binary: $PACKAGE_DIR/sub2api"
}

validate_settings() {
  safe_install_path "$INSTALL_DIR"
  [[ "$SERVER_PORT" =~ ^[0-9]+$ ]] || die "Port must be numeric: $SERVER_PORT"
  [ "$SERVER_PORT" -ge 1 ] && [ "$SERVER_PORT" -le 65535 ] || die "Port must be between 1 and 65535"
  SERVER_HOST="${SERVER_HOST//$'\r'/}"
  SERVER_HOST="${SERVER_HOST#"${SERVER_HOST%%[![:space:]]*}"}"
  SERVER_HOST="${SERVER_HOST%"${SERVER_HOST##*[![:space:]]}"}"
  [ -n "$SERVER_HOST" ] || die "Host cannot be empty"
  case "$SERVER_HOST" in
    \[*\]) ;;
    *[!A-Za-z0-9._:%-]*) die "Host contains unsupported characters: $(printf '%q' "$SERVER_HOST")" ;;
  esac
  [ -n "$TIMEZONE" ] || die "Timezone cannot be empty"
}

detect_arch() {
  case "$(uname -m)" in
    x86_64|amd64) printf 'amd64\n' ;;
    aarch64|arm64) printf 'arm64\n' ;;
    *) die "Unsupported CPU architecture: $(uname -m)" ;;
  esac
}

validate_binary_architecture() {
  local arch expected magic machine
  command -v od >/dev/null 2>&1 || die "od is required to validate the release binary"
  arch="$(detect_arch)"
  magic="$(od -An -N4 -tx1 "$PACKAGE_DIR/sub2api" | tr -d ' \n')"
  [ "$magic" = "7f454c46" ] || die "The release binary is not an ELF executable"
  machine="$(od -An -j18 -N2 -tu2 "$PACKAGE_DIR/sub2api" | tr -d ' \n')"
  case "$arch:$machine" in
    amd64:62|arm64:183) ;;
    *) die "Release binary architecture does not match this host ($arch, ELF machine $machine)" ;;
  esac
}

confirm_install() {
  [ "$YES" -eq 1 ] && return
  printf 'Package: %s\nInstall: %s\nListen: %s:%s\n' "$PACKAGE_DIR" "$INSTALL_DIR" "$SERVER_HOST" "$SERVER_PORT"
  read -r -p 'Continue? [y/N] ' answer
  [[ "$answer" =~ ^[Yy]$ ]] || exit 0
}

create_service_user() {
  getent group "$SERVICE_USER" >/dev/null 2>&1 || groupadd --system "$SERVICE_USER"
  id "$SERVICE_USER" >/dev/null 2>&1 || useradd --system --gid "$SERVICE_USER" --home-dir "$INSTALL_DIR" --shell /usr/sbin/nologin "$SERVICE_USER"
}

prune_backups() {
  local pattern="$1" keep="$2" file
  mapfile -t files < <(find "$INSTALL_DIR/backups" -maxdepth 1 -type f -name "$pattern" -printf '%T@ %p\n' 2>/dev/null | sort -nr | awk '{ $1=""; sub(/^ /, ""); print }')
  [ "${#files[@]}" -le "$keep" ] && return 0
  for file in "${files[@]:$keep}"; do rm -f -- "$file"; done
}

backup_current_files() {
  local stamp database backup
  stamp="$(date +%Y%m%d-%H%M%S)"
  if [ -f "$INSTALL_DIR/sub2api" ]; then
    cp -a "$INSTALL_DIR/sub2api" "$INSTALL_DIR/backups/sub2api.$stamp"
    prune_backups 'sub2api.[0-9]*' 5
  fi
  if [ -f "$INSTALL_DIR/config.yaml" ]; then
    cp -a "$INSTALL_DIR/config.yaml" "$INSTALL_DIR/backups/config.yaml.$stamp"
    prune_backups 'config.yaml.[0-9]*' 5
  fi
  database="$INSTALL_DIR/data/sub2api.db"
  if [ -f "$database" ]; then
    backup="$INSTALL_DIR/backups/sub2api-db.$stamp.sqlite3"
    if command -v sqlite3 >/dev/null 2>&1; then
      sqlite3 "$database" ".timeout 10000" ".backup '$backup'" || cp -a "$database" "$backup"
    else
      cp -a "$database" "$backup"
      warn "sqlite3 is not installed; the upgrade backup is a stopped-file copy"
    fi
    prune_backups 'sub2api-db.[0-9]*.sqlite3' 7
  fi
}

generate_jwt_secret() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 32
  elif [ -r /dev/urandom ] && command -v od >/dev/null 2>&1; then
    od -An -N32 -tx1 /dev/urandom | tr -d ' \n'
  else
    date +%s
  fi
}

write_config() {
  local config_file="$INSTALL_DIR/config.yaml" secret
  if [ -f "$config_file" ] && [ "$FORCE_CONFIG" -eq 0 ]; then
    chown "$SERVICE_USER:$SERVICE_USER" "$config_file"
    chmod 640 "$config_file"
    return 0
  fi
  if [ -f "$config_file" ]; then
    cp -a "$config_file" "$INSTALL_DIR/backups/config.yaml.$(date +%Y%m%d-%H%M%S)"
    prune_backups 'config.yaml.[0-9]*' 5
  fi
  secret="$(generate_jwt_secret)"
  cat > "$config_file" <<EOF
run_mode: lightweight
timezone: $TIMEZONE

server:
  host: $SERVER_HOST
  port: $SERVER_PORT
  mode: release

database:
  driver: sqlite
  file: data/sub2api.db
  busy_timeout_ms: 5000
  max_open_conns: 1
  max_idle_conns: 1

lightweight:
  virtual_token_price_cny: 1

jwt:
  secret: "$secret"
  expire_hour: 24

dashboard_aggregation:
  enabled: false
EOF
  chown "$SERVICE_USER:$SERVICE_USER" "$config_file"
  chmod 640 "$config_file"
}

write_environment() {
  install -d -m 755 "$CONFIG_DIR"
  umask 077
  cat > "$ENV_FILE" <<EOF
RUN_MODE=lightweight
GIN_MODE=release
DATA_DIR=$INSTALL_DIR
SERVER_HOST=$SERVER_HOST
SERVER_PORT=$SERVER_PORT
EOF
  chown root:root "$ENV_FILE"
  chmod 600 "$ENV_FILE"
}

install_assets() {
  install -d -m 755 "$INSTALL_DIR" "$INSTALL_DIR/deploy/linux" "$INSTALL_DIR/data" "$INSTALL_DIR/logs" "$INSTALL_DIR/backups"
  install -m 755 -o root -g root "$PACKAGE_DIR/sub2api" "$INSTALL_DIR/sub2api.new"
  mv -f "$INSTALL_DIR/sub2api.new" "$INSTALL_DIR/sub2api"
  if [ -f "$PACKAGE_DIR/deploy/linux/install-ubuntu.sh" ]; then
    install -m 755 -o root -g root "$PACKAGE_DIR/deploy/linux/install-ubuntu.sh" "$INSTALL_DIR/deploy/linux/install-ubuntu.sh"
  fi
  [ -f "$PACKAGE_DIR/LICENSE" ] && install -m 644 -o root -g root "$PACKAGE_DIR/LICENSE" "$INSTALL_DIR/LICENSE"
  chown "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR/data" "$INSTALL_DIR/logs"
  chmod 750 "$INSTALL_DIR/data" "$INSTALL_DIR/logs" "$INSTALL_DIR/backups"
}

install_service() {
  cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Sub2API Ubuntu direct API gateway
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/sub2api
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal
SyslogIdentifier=sub2api
EnvironmentFile=-$ENV_FILE
NoNewPrivileges=true
PrivateTmp=true
ProtectHome=true
ProtectSystem=strict
ReadWritePaths=$INSTALL_DIR/data $INSTALL_DIR/logs $INSTALL_DIR/backups $INSTALL_DIR/config.yaml

[Install]
WantedBy=multi-user.target
EOF
  chown root:root "$SERVICE_FILE"
  chmod 644 "$SERVICE_FILE"
  systemctl daemon-reload
  systemctl enable "$SERVICE_NAME" >/dev/null
  systemctl restart "$SERVICE_NAME"
  for _ in $(seq 1 10); do
    systemctl is-active --quiet "$SERVICE_NAME" && return 0
    sleep 1
  done
  systemctl status "$SERVICE_NAME" --no-pager || true
  die "Service failed to start"
}

remove_backup_timer() {
  systemctl disable --now "${SERVICE_NAME}-backup.timer" >/dev/null 2>&1 || true
  rm -f "/etc/systemd/system/${SERVICE_NAME}-backup.timer" "/etc/systemd/system/${SERVICE_NAME}-backup.service"
  rm -f "$INSTALL_DIR/backup-sqlite.sh"
  systemctl daemon-reload
}

install_backup_timer() {
  local backup_script="$INSTALL_DIR/backup-sqlite.sh"
  remove_backup_timer
  if ! command -v sqlite3 >/dev/null 2>&1; then
    warn "sqlite3 is not installed; daily SQLite backup timer was not enabled"
    return 0
  fi
  cat > "$backup_script" <<EOF
#!/usr/bin/env bash
set -Eeuo pipefail
database="$INSTALL_DIR/data/sub2api.db"
backup_dir="$INSTALL_DIR/backups"
[ -f "\$database" ] || exit 0
mkdir -p "\$backup_dir"
backup="\$backup_dir/sub2api-db.\$(date +%Y%m%d-%H%M%S).sqlite3"
sqlite3 "\$database" ".timeout 10000" ".backup '\$backup'"
chown root:root "\$backup"
chmod 640 "\$backup"
find "\$backup_dir" -maxdepth 1 -type f -name 'sub2api-db.*.sqlite3' -printf '%T@ %p\n' | sort -nr | awk 'NR > 7 { \$1=""; sub(/^ /, ""); print }' | xargs -r rm -f --
EOF
  chmod 750 "$backup_script"
  chown root:root "$backup_script"
  cat > "/etc/systemd/system/${SERVICE_NAME}-backup.service" <<EOF
[Unit]
Description=Backup Sub2API SQLite database
After=$SERVICE_NAME.service

[Service]
Type=oneshot
ExecStart=$backup_script
EOF
  cat > "/etc/systemd/system/${SERVICE_NAME}-backup.timer" <<EOF
[Unit]
Description=Daily Sub2API SQLite backup

[Timer]
OnCalendar=*-*-* 03:15:00
Persistent=true
RandomizedDelaySec=300

[Install]
WantedBy=timers.target
EOF
  systemctl daemon-reload
  systemctl enable --now "${SERVICE_NAME}-backup.timer" >/dev/null
}

open_firewall() {
  [ "$OPEN_FIREWALL" -eq 1 ] || return 0
  if ! command -v ufw >/dev/null 2>&1; then
    warn "--open-firewall was requested, but ufw is not installed; no firewall changes were made"
    return 0
  fi
  if ufw status 2>/dev/null | grep -qi '^Status: active'; then
    ufw allow "$SERVER_PORT/tcp"
    ok "Allowed TCP port $SERVER_PORT in UFW"
  else
    warn "UFW is installed but inactive; no firewall changes were made"
  fi
}

install_or_upgrade() {
  resolve_package_dir
  validate_settings
  require_systemd
  detect_arch >/dev/null
  confirm_install
  create_service_user
  validate_binary_architecture
  install -d -m 755 "$INSTALL_DIR" "$INSTALL_DIR/backups"
  systemctl stop "$SERVICE_NAME" >/dev/null 2>&1 || true
  backup_current_files
  install_assets
  write_config
  write_environment
  install_service
  install_backup_timer
  open_firewall
  ok "Sub2API is installed and listening directly on http://$SERVER_HOST:$SERVER_PORT"
  printf 'Status: systemctl status %s\n' "$SERVICE_NAME"
  printf 'Logs:   journalctl -u %s -f\n' "$SERVICE_NAME"
  printf 'Login:  complete the first-run setup or use the lightweight default admin (123456@admin.com / 123456)\n'
}

uninstall_app() {
  validate_settings
  require_systemd
  if [ "$YES" -eq 0 ]; then
    printf 'Service: %s\nInstall: %s\n' "$SERVICE_NAME" "$INSTALL_DIR"
    [ "$PURGE" -eq 1 ] && printf 'This will permanently delete data, config, and backups.\n'
    read -r -p 'Continue? [y/N] ' answer
    [[ "$answer" =~ ^[Yy]$ ]] || exit 0
  fi
  remove_backup_timer
  systemctl disable --now "$SERVICE_NAME" >/dev/null 2>&1 || true
  rm -f "$SERVICE_FILE" "$ENV_FILE"
  rmdir "$CONFIG_DIR" 2>/dev/null || true
  systemctl daemon-reload
  if [ "$PURGE" -eq 1 ]; then
    safe_install_path "$INSTALL_DIR"
    rm -rf -- "$INSTALL_DIR"
    userdel "$SERVICE_USER" >/dev/null 2>&1 || true
    groupdel "$SERVICE_USER" >/dev/null 2>&1 || true
    ok "Service and all Sub2API files were removed"
  else
    rm -f "$INSTALL_DIR/sub2api"
    ok "Service and binary removed; data, config, and backups remain in $INSTALL_DIR"
  fi
}

main() {
  parse_args "$@"
  require_root
  case "$COMMAND" in
    install|upgrade|update) install_or_upgrade ;;
    status) require_systemd; systemctl status "$SERVICE_NAME" --no-pager ;;
    restart) require_systemd; systemctl restart "$SERVICE_NAME" ;;
    logs) require_systemd; journalctl -u "$SERVICE_NAME" -f ;;
    uninstall|remove) uninstall_app ;;
  esac
}

main "$@"
