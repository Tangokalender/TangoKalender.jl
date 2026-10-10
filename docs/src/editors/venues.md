# Venues and maps

Events only store address text. The data repository's `venues.json` caches a map position per address; the site
reads it when it is built, and never uses the network.

- New addresses are looked up in OpenStreetMap (Nominatim) by `tangokalender geocode events`, at most one request
  per second. The intake bot does this for every submission and adds `venues.json` to its pull request.
- An event is only placed on a map when the match is precise (a house number, a building or a venue). Others appear
  in the list without a pin.
- Addresses that weren't found are stored as not found and are only retried with `--retry`.

## Fixing a pin

If a pin is wrong, edit the address's entry in `venues.json`: put the right `lat` and `lon` (from
openstreetmap.org: right-click → «Show address»), and set `"source": "manual"`. Manual entries are never
overwritten.

```json
{"address": "Øvre Slottsgate 3, 0157 Oslo", "lat": 59.9106, "lon": 10.7439, "precision": "house", "source": "manual"}
```
