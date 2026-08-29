SKIPUNZIP=0
PROPFILE=true
POSTFSDATA=true
LATESTARTSERVICE=true

ui_print "========================================"
ui_print "|                                      |"
ui_print "|   TRANSSION BLUR LAB                 |"
ui_print "|   No WebUI . combo tester . V1       |"
ui_print "|                                      |"
ui_print "========================================"
ui_print "> Checking other modules..."
ui_print "----------------------------------------"

OLD=/data/adb/modules/transsion-flagship-16
if [ -d "$OLD" ] && [ ! -f "$OLD/disable" ]; then
  touch "$OLD/disable"
  ui_print "[!] Disabled Transsion Flagship 16"
  ui_print "[*] Keep it disabled while you test combos"
else
  ui_print "[OK] Flagship 16 is not fighting this module"
fi

COMBO=5
if [ -f "$MODPATH/combo" ]; then
  COMBO=$(grep -oE '[1-6]' "$MODPATH/combo" | head -1)
fi
[ -n "$COMBO" ] || COMBO=5
echo "$COMBO" > "$MODPATH/combo"

ui_print " "
ui_print "> Active combo: $COMBO"
ui_print "----------------------------------------"
ui_print "[*] 1 shade     platform/glass/SF only"
ui_print "[*] 2 dock15    gaussian 2 + enable"
ui_print "[*] 3 dock16    gaussian 3 + folder 3"
ui_print "[*] 4 full      shade + dock16"
ui_print "[*] 5 full+     full + settings + vconfig  [default]"
ui_print "[*] 6 full-g2   same as 5 but gaussian 2"
ui_print " "
ui_print "[*] Switch: edit /data/adb/modules/transsion-blur-lab/combo"
ui_print "[*] Then reboot (twice if compositor keys changed)"
ui_print "[*] Log: /data/adb/modules/transsion-blur-lab/lab.log"
ui_print "========================================"
ui_print "INSTALLATION COMPLETE"
ui_print "t.me/Just_LilGXX"
ui_print "Reboot, then check shade / dock / folders"
ui_print "- Done"
