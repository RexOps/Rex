#!/bin/bash

HEADER=$(cat <<EOF
% layout 'default';
% title '{{TITLE}}';

% content_for header => begin
      <meta name="description" content="{{DESC}}">
      <meta name="keywords" content="Rex, API, Documentation">
% end

EOF

)

FOOTER=$(cat <<EOF

EOF

)

for x in lib/Rex/Commands/Box.pm \
   lib/Rex/Commands/Cloud.pm \
   lib/Rex/Commands/Cron.pm \
   lib/Rex/Commands/DB.pm \
   lib/Rex/Commands/Download.pm \
   lib/Rex/Commands/File.pm \
   lib/Rex/Commands/Fs.pm \
   lib/Rex/Commands/Gather.pm \
   lib/Rex/Commands/Host.pm \
   lib/Rex/Commands/Inventory.pm \
   lib/Rex/Commands/Iptables.pm \
   lib/Rex/Commands/Kernel.pm \
   lib/Rex/Commands/LVM.pm \
   lib/Rex/Commands/MD5.pm \
   lib/Rex/Commands/Network.pm \
   lib/Rex/Commands/Notify.pm \
   lib/Rex/Commands/Partition.pm \
   lib/Rex/Commands/Pkg.pm \
   lib/Rex/Commands/Process.pm \
   lib/Rex/Commands/Rsync.pm \
   lib/Rex/Commands/Run.pm \
   lib/Rex/Commands/SCM.pm \
   lib/Rex/Commands/Service.pm \
   lib/Rex/Commands/SimpleCheck.pm \
   lib/Rex/Commands/Sync.pm \
   lib/Rex/Commands/Sysctl.pm \
   lib/Rex/Commands/Tail.pm \
   lib/Rex/Commands/Upload.pm \
   lib/Rex/Commands/User.pm \
   lib/Rex/Commands/Virtualization.pm \
   lib/Rex/Box/Base.pm \
   lib/Rex/Box/Amazon.pm \
   lib/Rex/Box/KVM.pm \
   lib/Rex/Box/VBox.pm \
   lib/Rex/Virtualization/VBox.pm \
   lib/Rex/Virtualization/LibVirt.pm \
   lib/Rex/Virtualization/Docker.pm \
   lib/Rex/FS/File.pm \
   lib/Rex/Commands.pm \
   lib/Rex/Hardware.pm \
   lib/Rex/Task.pm \
   lib/Rex/Template.pm \
   lib/Rex/Logger.pm \
   lib/Rex/Transaction.pm \
   lib/Rex.pm \

   do

      echo " ====== processing $x ========"

      (
            FTMP=$(dirname $x)
            RELPATH=$(perl -le"\$s=''; for ( split(/\//, '${FTMP/lib\//}') ) { \$s.='../' } print \$s;")

            if [ "$x" = "lib/Rex.pm" ]; then
               RELPATH="./"
            fi

            pod2html $x \
                  | perl -lpe "s/^(\s*)%/\$1%%/g" \
                  | perl -lne 'print if m|<body[^>]+>|gmsi .. m|</body>|gmsi' \
                  | perl -lpe "s|<body.*|$HEADER|" \
                  | sed -e "s/<\/body.*//" \
                  | sed -e "s/<hr.*>//g" \
                  | sed -e "s/<code>//g" \
                  | sed -e "s/<\/code>//g" \
                  | sed -e "s/<pre>/<div class=\"btn btn-default copy-button pull-right\" data-clipboard-target=\"clipboardCOUNTER\">Copy to clipboard<\/div>\n<pre><code class=\"perl\" id=\"clipboardCOUNTER\">/" \
                  | perl -pe's:(?<=clipboard)(COUNTER):int($count++/2):e' \
                  | sed -e "s/<dl/<ul/g" \
                  | sed -e "s/<\/dl>/<\/ul>/g" \
                  | sed -e "s/<dd>//g" \
                  | sed -e "s/<\/dd>//g" \
                  | sed -e "s/<dt/<li/g" \
                  | sed -e "s/<\/dt>/<\/li>/g" \
                  | sed -e "s/<\/pre>/<\/code><\/pre>/" \
                  | sed -e "s/<p><a name=\"__index__\"><\/a><\/p>/<h1>TABLE OF CONTENTS<\/h1>/" \
                  | sed -e "s/<a href=\"\/Rex\/Commands/<a href=\"\/api\/Rex\/Commands/g" \
                  | sed -e "s/<a href=\"\/Net\/SSH2.html\">the Net::SSH2 manpage<\/a>/<em>Net::SSH2<\/em>/g" \
                  | sed -e "s/<a href=\"\/api\/Rex\/Commands.html\">the Rex::Commands manpage<\/a>/<a href=\"\/api\/Rex\/Commands.pm.html\">Rex::Commands<\/a>/g" \
                  | perl -lpe "s/<a href=\"file:\/[^\"]+\">([^<]+)<\/a>/\$1/g" \
                  | perl -lpe "s/<h1><a name=\"[^\"]+\">(.*?)<\/a><\/h1>/<h2>\$1<\/h2>/g" \
                  | perl -lpe "s/<a href=\"\/api\/Rex\/Commands\/([^\.]+)\.html\">/<a href=\"\/api\/Rex\/Commands\/\$1.pm.html\">/g" \
                  | perl -lpe "s/the (Rex::Commands::[a-zA-Z0-9]+) manpage/\$1/g" \
                  | perl -lpe "s/<strong><a name=\"[^\"]+\" class=\"item\">(.*?)<\/a><\/strong>/<strong>\$1<\/strong>/g" \
                  | perl -le '$/= undef; $content = <>; my ($title) = ($content =~ m/<h2>NAME<\/h2>\n<p>([^>]+)<\/p>/msi); $content =~ s/\{\{TITLE\}\}/$title/; print $content;' \
                  | perl -le '$/ = undef; $content = <>; my ($desc) = ($content =~ m/<h2>DESCRIPTION<\/h2>\s*<p>([^>]+)<\/p>/msi); $content =~ s/\{\{DESC\}\}/$desc/; print $content;' \
                  | perl -lpe "s|\{PATH\}|$RELPATH|g" \
                  | perl -lpe 's|<a href=".+?&quot">(.+?)&quot</a>;|$1&quot;|g' \
                  | perl -lpe 's|&quot;|"|g'

         ) > doc/html/${x/lib\//}.html.ep

   done
