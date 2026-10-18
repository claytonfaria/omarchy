#!/bin/bash

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/base-test.sh"
require_command lua
require_command python3

rules=$(OMARCHY_PATH="$ROOT" lua - <<'LUA'
package.path = os.getenv("OMARCHY_PATH") .. "/?.lua;" .. package.path
hl = { window_rule = function(rule)
  local m = rule.match
  print(table.concat({ m.class or ".*", m.title or ".*", m.tag or "",
    rule.tag or "", tostring(rule.float or false), tostring(rule.tile),
    tostring(rule.center or false), tostring(rule.no_screen_share or false),
    tostring(rule.size ~= nil) }, "\t"))
end }
require("default.hypr.helpers")
-- Match the production alphabetical module order.
local require_all = require("default.hypr.require_all")
require_all.files(os.getenv("OMARCHY_PATH") .. "/default/hypr/apps", "default.hypr.apps", {
  exclude = setmetatable({}, { __index = function(_, name)
    return name ~= "bitwarden" and name ~= "browser"
  end }),
})
LUA
)

BITWARDEN_RULES="$rules" python3 - <<'PY'
import os
import re

rules = [line.split('\t') for line in os.environ['BITWARDEN_RULES'].splitlines()]
assert any(r[2] == "chromium-based-browser" and r[5] == "true" for r in rules), "browser tiling rule must be loaded"
def state(cls, title):
    tags = set()
    floating = None
    tiled = False
    centered = protected = forced_size = False
    # Tags are dynamic match properties; resolve them before static effects.
    for c, t, tag, change, *_ in rules:
        if re.fullmatch(c, cls) and re.fullmatch(t, title) and (not tag or tag in tags):
            if change.startswith('+'):
                tags.add(change[1:])
            elif change.startswith('-'):
                tags.discard(change[1:])
    for c, t, tag, _, flt, tile, center, share, size in rules:
        if re.fullmatch(c, cls) and re.fullmatch(t, title) and (not tag or tag in tags):
            if flt == 'true': floating = True
            if tile != 'nil': tiled = tile == 'true'
            centered |= center == 'true'
            protected |= share == 'true'
            forced_size |= size == 'true'
    return (False if tiled else floating), centered, protected, forced_size

def matches(cls, title):
    result = state(cls, title)
    if result[0] is True:
        assert result[1:] == (True, True, False), (cls, title, result)
    return result[0] is True

for profile in ('Default', 'Profile 1', 'Profile 2'):
    assert matches('chrome-nngceckbapebfimnlniiiahkandclblb-' + profile, '_crx_nngceck'), profile
for cls in ('chromium', 'Chromium'):
    for title in ('Bitwarden', 'Bitwarden - Chromium'):
        assert matches(cls, title), (cls, title)
for cls, title in (
    ('chromium', 'New Tab - Chromium'),
    ('chromium', 'Bitwarden Web Vault - Chromium'),
    ('other-app', 'Bitwarden'),
    ('chrome-unrelated-extension-Profile 2', 'Extension'),
):
    assert not matches(cls, title), (cls, title)
    if cls == 'chromium':
        assert state(cls, title)[0] is False, 'ordinary browser windows must remain tiled'
PY
pass "Bitwarden prompts float across Chromium profiles without matching ordinary browser windows"
