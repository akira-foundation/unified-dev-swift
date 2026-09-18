#!/usr/bin/env python3
import plistlib
import sys

plist_path, identity_path = sys.argv[1:3]
fields = {}
with open(identity_path, encoding="utf-8") as handle:
    for line in handle.read().splitlines():
        key, _, value = line.partition("=")
        fields[key] = value

with open(plist_path, "rb") as handle:
    info = plistlib.load(handle)

paths = {
    "UD_DB_PATH": fields["database"],
    "UD_WORKSPACES_ROOT": fields["workspaces"],
    "UD_PREVIEW_ROOT": fields["root"],
}
info["CFBundleName"] = fields["app_name"]
info["CFBundleDisplayName"] = fields["app_name"]
info["CFBundleIdentifier"] = fields["bundle_id"]
info["CFBundleURLTypes"][0]["CFBundleURLName"] = fields["bundle_id"] + ".deeplink"
info["CFBundleURLTypes"][0]["CFBundleURLSchemes"] = [fields["url_scheme"]]
info["NSServices"][0]["NSPortName"] = fields["app_name"]
info["NSServices"][0]["NSMenuItem"] = {"default": fields["services_item"]}
info["LSEnvironment"] = dict(paths)
info.update(paths)
info["UDWindowTitlePrefix"] = fields["title_prefix"]

with open(plist_path, "wb") as handle:
    plistlib.dump(info, handle)
