#-----------------------------------------------------------------
# Shell variable for cron
SHELL=/bin/bash
# PATH variable for cron
PATH=/usr/local/bin:/usr/local/sbin:/sbin:/usr/sbin:/bin:/usr/bin:/usr/bin/X11
MYVAR="foo=bar"
#M   S     T M W   Befehl
#-----------------------------------------------------------------
5    9-20 * * *   /home/username/script/script1.sh > /dev/null
*/10 *    * * *   /usr/bin/script2.sh > /dev/null 2>&1
59   23   * * 0,4 cp /pfad/zu/datei /pfad/zur/kopie
*    *    * * *   DISPLAY=:0 LANG=de_DE.UTF-8 zenity --info --text "Beispiel für das Starten eines Programmes mit GUI"
0    0    * * *   backup
#-----------------------------------------------------------------
