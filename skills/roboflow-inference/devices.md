# Device provisioning, checks and configuration

Use the live tool schemas for parameters and permissions. Device changes require
user authorization; an accepted command or saved patch does not prove it is live.

## Secure gateways

`devices_create` accepts `runtime` and `secure_gateway_id`. Creating a device of
`device_type="secure-gateway"` requires `runtime="docker"`. Attaching a device to
a gateway requires an existing ready gateway. Do not combine `secure_gateway_id`
with offline QR provisioning: the QR payload cannot carry gateway trust. Gateway
enrollment and trust management belong in the Roboflow app.

## Network checks

Use `devices_send_command(action="network_probe", data={...})` for one ping, DNS,
TCP or HTTP probe. `data` needs `kind` (`ping`, `dns`, `tcp`, `http`) and a hostname
or IP `target`, not a URL. `count` is 1-10 and `timeout_s` is 1-15; TCP also needs
`port` (1-65535). HTTP optionally takes `port` and `scheme` (`http` or `https`).
The returned `id` means queued. The device reports the result later in monitoring
under `network_probes[id]`, shown on the device's Networking page in the Roboflow
app. The public tools do not provide a dedicated probe-result read. If that
result is unavailable, report the probe as queued and unverified; do not report
the connection healthy from enqueueing.

## Approval and maintenance windows

Read `devices_get_config` before changing a device. A `devices_update_config`
response with `staged: true` and `configProposal` means the change is waiting for
approval, not active. Maintenance-window `deferred` and `pendingUpdates` are
separate. Unapproved changes remain held through a window, and apply-pending can
return 409 until approval. The same applies to Workflow pins changed by a publish.
Have an eligible person approve in the Roboflow app, then read configuration
again. MCP cannot approve proposals; do not force a change around that approval.

## Captured frames

`devices_streams_capture_frame` can return `status="screening"`. The frame is
held for upload screening; project details identify the requested destination,
not an image already available there. Follow the [image-screening guidance](../roboflow-data-management/SKILL.md#images-held-for-upload-screening)
and use `images_screening_status` when an image ID is available.
