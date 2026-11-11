# shellcheck shell=bash
# tebian-settings module: capture.sh
# Sourced by tebian-settings — do not run directly
#
# Screenshots, recording, copy text (OCR), QR codes: the menu is
# tebian-capture's own, so Mod+Print and Settings show the same thing.
# It exits 10 for Back; anything else (Escape, or something was captured)
# closes Settings, which would otherwise come back over the screen being
# captured or recorded.

capture_menu() {
    local rc=0
    tebian-capture menu --back || rc=$?
    [ "$rc" -eq 10 ] && return
    menu_close
}

# Search rows land on these directly
capture_record() { tebian-record toggle; menu_close; }
capture_text()   { tebian-capture text; menu_close; }
capture_qr()     { tebian-capture qr; menu_close; }
capture_emoji()  { tebian-emoji; menu_close; }
