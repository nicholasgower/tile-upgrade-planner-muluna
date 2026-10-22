#!/bin/bash
# SPDX-License-Identifier: LGPL-3.0-or-later WITH FUnit-CI-Exception
#
# Prepare the factoriotools/factorio container for the FUnit job.

set -euo pipefail

project_dir="${GITHUB_WORKSPACE:-${CI_PROJECT_DIR:-$PWD}}"
artifacts_dir="$project_dir/artifacts/${MOD_NAME}"

mkdir -p "${CONFIG:-/config}" "${MODS:-/mods}" /factorio/saves /factorio/scenarios /factorio/script-output /factorio

cp -a "$artifacts_dir/test/." /
cp "$artifacts_dir/test/server-settings.json" "${CONFIG:-/config}/server-settings.json"
cp "$project_dir"/artifacts/*/*.zip /
cp -a "$artifacts_dir/scenarios/." /factorio/scenarios/
cp "$artifacts_dir/scenario_names.txt" /scenario_names.txt

sed -i 's|^write-data=.*|write-data=/factorio|' /opt/factorio/config/config.ini
