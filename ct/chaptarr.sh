#!/usr/bin/env bash
_cs_boot="${COMMUNITY_SCRIPTS_CORE_DIR:-$(dirname "${BASH_SOURCE[0]}")/../../core}/core/build.func"
# shellcheck disable=SC1090 # Dynamic sourcing of core functions
source "$_cs_boot" 2>/dev/null || source <(curl -fsSL "${COMMUNITY_SCRIPTS_CORE_URL:-https://raw.githubusercontent.com/community-scripts/core/main}/core/build.func")
# Copyright (c) 2021-2026 community-scripts ORG
# Author: fcol95
# License: MIT | https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE
# Source: https://github.com/Chaptarr/chaptarr

APP="Chaptarr"
var_tags="${var_tags:-arr;audiobooks;ebooks;media}"
var_cpu="${var_cpu:-4}"
var_ram="${var_ram:-4096}"
var_disk="${var_disk:-8}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_arm64="${var_arm64:-no}" # m4b-tool and mp4v2 compiling can be problematic on ARM, keeping it no for now
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -d /opt/chaptarr ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  if GH_INCLUDE_PRERELEASE=1 check_for_gh_release "chaptarr" "Chaptarr/chaptarr"; then
    msg_info "Stopping Service"
    systemctl stop chaptarr
    msg_ok "Stopped Service"
    create_backup /opt/chaptarr_data

    GH_INCLUDE_PRERELEASE=1 CLEAN_INSTALL=1 fetch_and_deploy_gh_release "chaptarr" "Chaptarr/chaptarr" "tarball"

    restore_backup
    msg_info "Building Chaptarr"
    cd /opt/chaptarr/frontend || exit
    $STD yarn install --immutable
    $STD yarn build
    cd /opt/chaptarr || exit
    rm -rf /opt/chaptarr_app
    DOTNET_CLI_TELEMETRY_OPTOUT=1 $STD dotnet publish src/NzbDrone.Console/Chaptarr.Console.csproj -c Release -f net10.0 -o /opt/chaptarr_app /p:UseAppHost=false /p:Version="$(cat ~/.chaptarr)"
    cp -r /opt/chaptarr/_output/UI /opt/chaptarr_app/
    msg_ok "Built Chaptarr"

    msg_info "Starting Service"
    systemctl start chaptarr
    msg_ok "Started Service"
    msg_ok "Updated successfully!"
  fi
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW}Access it using the following URL:${CL}"
echo -e "${GATEWAY}${BGN}http://${IP}:8789${CL}"
echo -e "${INFO}${YW}Persistent data is stored in /opt/chaptarr_data${CL}"
