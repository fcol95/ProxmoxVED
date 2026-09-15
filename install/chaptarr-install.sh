#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: fcol95
# License: MIT | https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE
# Source: https://github.com/Chaptarr/chaptarr

# shellcheck disable=SC1091 # Standard community scripts sourcing mechanism
source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt install -y build-essential python3-dev sqlite3 libsqlite3-0 wget
msg_ok "Installed Dependencies"

setup_ffmpeg
NODE_VERSION="22" NODE_MODULE="yarn" setup_nodejs
DOTNET_VERSION="10" DOTNET_TYPE="sdk" setup_dotnet
PHP_VERSION="8.3" PHP_MODULE="cli,mbstring,xml,curl,zip" setup_php

msg_info "Installing mp4v2 (m4b-tool dependency)"
cd /tmp || exit
wget -q https://github.com/sandreas/mp4v2/archive/refs/heads/master.tar.gz -O mp4v2.tar.gz
tar -xzf mp4v2.tar.gz
cd mp4v2-master || exit
$STD ./configure
$STD make
$STD make install
$STD ldconfig
cd ~ || exit
rm -rf /tmp/mp4v2-master /tmp/mp4v2.tar.gz
msg_ok "Installed mp4v2"

msg_info "Installing m4b-tool"
wget -qO /usr/local/bin/m4b-tool https://github.com/sandreas/m4b-tool/releases/download/v0.5.2/m4b-tool.phar
chmod +x /usr/local/bin/m4b-tool
msg_ok "Installed m4b-tool"

GH_INCLUDE_PRERELEASE=1 fetch_and_deploy_gh_release "chaptarr" "Chaptarr/chaptarr" "tarball"

msg_info "Building Chaptarr"
cd /opt/chaptarr/frontend || exit
$STD yarn install --immutable
$STD yarn build
cd /opt/chaptarr || exit
rm -rf /opt/chaptarr_app
DOTNET_CLI_TELEMETRY_OPTOUT=1 $STD dotnet publish src/NzbDrone.Console/Chaptarr.Console.csproj -c Release -f net10.0 -o /opt/chaptarr_app /p:UseAppHost=false /p:Version="$(cat ~/.chaptarr)" /p:NuGetAudit=false /p:TreatWarningsAsErrors=false
cp -r /opt/chaptarr/_output/UI /opt/chaptarr_app/
msg_ok "Built Chaptarr"

msg_info "Configuring Chaptarr"
mkdir -p /opt/chaptarr_data
chmod 750 /opt/chaptarr_data
msg_ok "Configured Chaptarr"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/chaptarr.service
[Unit]
Description=Chaptarr
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/chaptarr_app
Environment=DOTNET_CLI_TELEMETRY_OPTOUT=1
ExecStart=/usr/bin/dotnet /opt/chaptarr_app/Chaptarr.dll -nobrowser -data=/opt/chaptarr_data
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now chaptarr
msg_ok "Created Service"

motd_ssh
customize
cleanup_lxc
