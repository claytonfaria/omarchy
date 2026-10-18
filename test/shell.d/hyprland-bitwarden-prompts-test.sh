#!/bin/bash

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/base-test.sh"
require_command lua
require_command python3

rules=$(OMARCHY_PATH="$ROOT" lua - <<'LUA'
package.path = os.getenv("OMARCHY_PATH") .. "/?.lua;" .. package.path
hl = { window_rule = function(rule)
  if rule.float then
    assert(rule.center and rule.no_screen_share)
    assert(rule.size == nil and rule.tag == nil, "prompts keep their requested size")
    print(rule.match.class .. "\t" .. (rule.match.title or ".*"))
  end
end }
require("default.hypr.helpers")
require("default.hypr.apps.bitwarden")
LUA
)

BITWARDEN_RULES="$rules" python3 - <<'PY'
import os
import re

rules = [line.split('\t') for line in os.environ['BITWARDEN_RULES'].splitlines()]
def matches(cls, title):
    return any(re.fullmatch(c, cls) and re.fullmatch(t, title) for c, t in rules)

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
PY
pass "Bitwarden prompts float across Chromium profiles without matching ordinary browser windows"
