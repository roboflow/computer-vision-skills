# Vision Events

Events are production inference records grouped into use cases. Discover a use
case with `vision_events_use_cases_list`, then query with `vision_events_query`.
These tools read and manage existing events; devices and Workflows produce them.

## Retrieve event images

`vision_events_query` returns image IDs in `events[].images[]`. Use `sourceId`
for the saved event image or `inputSourceId` for its input image when present.
Read `workspaceId` from the matching use case in `vision_events_use_cases_list`.

For workspaces using the standard Roboflow source host, fetch the image directly
from `https://source.roboflow.com/<workspaceId>/<sourceId>/original.jpg`. Use the
actual workspace ID in the first segment and the selected image ID in the second.
Try one image before fetching a batch and reuse results for repeated IDs.

If a direct URL fails or the workspace uses a different source host or owner,
use `images_workspace_search` for the relevant dates. Request `id` and `url`,
paginate as needed, and match the results to the image IDs in memory. Use the
Vision Events gallery for images still unavailable through those paths.

## Event IDs and grouped filters

- Pass `use_case_id` for every query. `event_id` is an exact match inside that use
  case. For exclusions or several IDs, use `additional_filters.eventId` with
  `operator` (`eq`, `neq`, `in`, `not_in`) and `value` (one ID or up to 50 IDs).
- Use `additional_filters.filterGroup` for nested `and`/`or` groups. Groups are
  ANDed with flat filters; they do not broaden the use case or time range. Limits
  are depth 5, 20 groups and 50 predicates across tree and flat filters. Read the
  tool schema for each metadata, text, existence or detection filter's shape.
- A saved filter is the whole search: pass `saved_filter_id` with only pagination,
  not additional filters. When updating a saved filter, leaving `group`
  out preserves it; `group=null` removes it explicitly.

## Deleting events and optional media

Ask the user to confirm the use case, event IDs and whether media should also be
removed before `vision_events_delete`. Event deletion is soft; media stays by
default. `delete_media=true` permanently removes only media with no other live
event, project, Dataset, Eval Dataset or bucket-mirror references. It additionally
needs `project:update` with `vision-events:manage`; folder-scoped API keys cannot
request media deletion. Read `deleted`, `notFound` and `media.deleted/kept/failed`:
kept media was not removed, and cleanup failure can follow successful event
deletion. Report those outcomes separately.
