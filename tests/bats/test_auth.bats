#!/usr/bin/env bats
# Tests for API key resolution.

load 'helpers/setup'

setup() {
    rf_test::isolated_home
    export NO_COLOR=1
    # shellcheck disable=SC1091
    source "$RF_REPO_ROOT/installer/lib/common.sh"
    # shellcheck disable=SC1091
    source "$RF_REPO_ROOT/installer/lib/json_io.sh"
    # shellcheck disable=SC1091
    source "$RF_REPO_ROOT/installer/lib/auth.sh"
}

teardown() {
    rf_test::cleanup_home
}

@test "auth: --api-key flag takes precedence" {
    export ROBOFLOW_API_KEY=from_env
    RF_OPT_API_KEY=from_flag
    rf::auth::resolve
    [ "$RF_API_KEY" = "from_flag" ]
    [[ "$RF_API_KEY_SOURCE" == *"flag"* ]]
}

@test "auth: \$ROBOFLOW_API_KEY used when no flag" {
    export ROBOFLOW_API_KEY=from_env
    RF_OPT_API_KEY=""
    rf::auth::resolve
    [ "$RF_API_KEY" = "from_env" ]
    [[ "$RF_API_KEY_SOURCE" == *"env"* ]]
}

@test "auth: --auth-skip yields empty key" {
    RF_OPT_AUTH_SKIP=1
    rf::auth::resolve
    [ -z "$RF_API_KEY" ]
    [[ "$RF_API_KEY_SOURCE" == "skipped" ]]
}

@test "auth: SDK config single workspace resolves key" {
    mkdir -p "$HOME/.config/roboflow"
    cat >"$HOME/.config/roboflow/config.json" <<EOF
{
  "workspaces": {
    "https://app.roboflow.com/my-workspace": {
      "url": "https://app.roboflow.com/my-workspace",
      "name": "my-workspace",
      "apiKey": "rf_from_sdk"
    }
  },
  "RF_WORKSPACE": "https://app.roboflow.com/my-workspace"
}
EOF
    RF_OPT_API_KEY=""
    unset ROBOFLOW_API_KEY
    rf::auth::resolve
    [ "$RF_API_KEY" = "rf_from_sdk" ]
    [[ "$RF_API_KEY_SOURCE" == *"sdk-config"* ]]
}

@test "auth: SDK config multiple workspaces with --yes uses default" {
    mkdir -p "$HOME/.config/roboflow"
    cat >"$HOME/.config/roboflow/config.json" <<EOF
{
  "workspaces": {
    "https://app.roboflow.com/ws-a": {
      "url": "https://app.roboflow.com/ws-a",
      "name": "ws-a",
      "apiKey": "rf_a"
    },
    "https://app.roboflow.com/ws-b": {
      "url": "https://app.roboflow.com/ws-b",
      "name": "ws-b",
      "apiKey": "rf_b"
    }
  },
  "RF_WORKSPACE": "https://app.roboflow.com/ws-b"
}
EOF
    RF_OPT_API_KEY=""
    unset ROBOFLOW_API_KEY
    RF_YES=1
    rf::auth::resolve
    [ "$RF_API_KEY" = "rf_b" ]
}

@test "auth: SDK config respects --workspace flag" {
    mkdir -p "$HOME/.config/roboflow"
    cat >"$HOME/.config/roboflow/config.json" <<EOF
{
  "workspaces": {
    "https://app.roboflow.com/ws-a": {
      "url": "https://app.roboflow.com/ws-a",
      "name": "ws-a",
      "apiKey": "rf_a"
    },
    "https://app.roboflow.com/ws-b": {
      "url": "https://app.roboflow.com/ws-b",
      "name": "ws-b",
      "apiKey": "rf_b"
    }
  }
}
EOF
    RF_OPT_API_KEY=""
    unset ROBOFLOW_API_KEY
    RF_OPT_WORKSPACE="https://app.roboflow.com/ws-a"
    rf::auth::resolve
    [ "$RF_API_KEY" = "rf_a" ]
}

@test "auth: ROBOFLOW_CONFIG_DIR override" {
    mkdir -p "$HOME/custom-config"
    cat >"$HOME/custom-config/config.json" <<EOF
{
  "workspaces": {
    "https://app.roboflow.com/ws": {
      "url": "https://app.roboflow.com/ws",
      "name": "ws",
      "apiKey": "rf_custom"
    }
  }
}
EOF
    export ROBOFLOW_CONFIG_DIR="$HOME/custom-config"
    RF_OPT_API_KEY=""
    unset ROBOFLOW_API_KEY
    rf::auth::resolve
    [ "$RF_API_KEY" = "rf_custom" ]
}

@test "auth: --yes with no key sources yields empty key (warning)" {
    RF_OPT_API_KEY=""
    unset ROBOFLOW_API_KEY
    RF_YES=1
    rf::auth::resolve
    [ -z "$RF_API_KEY" ]
}
