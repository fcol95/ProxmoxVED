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
$STD apt install -y build-essential python3-dev
msg_ok "Installed Dependencies"

setup_ffmpeg
NODE_VERSION="22" NODE_MODULE="yarn" setup_nodejs
DOTNET_VERSION="10" DOTNET_TYPE="sdk" setup_dotnet

fetch_and_deploy_gh_release "chaptarr" "Chaptarr/chaptarr" "tarball"

msg_info "Building Chaptarr"
cd /opt/chaptarr/frontend || exit
$STD yarn install --immutable
$STD yarn build
cd /opt/chaptarr || exit
rm -rf /opt/chaptarr_app
DOTNET_CLI_TELEMETRY_OPTOUT=1 $STD dotnet publish src/NzbDrone.Console/Chaptarr.Console.csproj -c Release -f net10.0 -o /opt/chaptarr_app /p:UseAppHost=false /p:Version="$(cat ~/.chaptarr)"
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
ExecStart=/usr/bin/dotnet /opt/chaptarr_app/Chaptarr.dll --data=/opt/chaptarr_data
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
