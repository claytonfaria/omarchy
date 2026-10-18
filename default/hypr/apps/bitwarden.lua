o.window("^(Bitwarden)$", { no_screen_share = true, tag = "+floating-window" })

-- Extension prompts can belong to any Chromium profile.
o.window("^chrome-nngceckbapebfimnlniiiahkandclblb-.*$", {
  no_screen_share = true,
  float = true,
  center = true,
})

-- Chromium can also expose extension prompts with its normal browser class.
o.window({ class = "^[Cc]hromium$", title = "^Bitwarden( - Chromium)?$" }, {
  no_screen_share = true,
  float = true,
  center = true,
})
