use Test::More tests => 54;

use_ok 'Rex::Cron';
use_ok 'Rex::Cron::Base';
use_ok 'Rex::Cron::Linux';
use_ok 'Rex::Cron::SunOS';

my @lines = eval { local(@ARGV) = ("t/cron.ex"); <>; };
chomp @lines;

my $c = Rex::Cron::Base->new;
my @cron = $c->_parse_cron(@lines);

ok($cron[0]->{type} eq "comment", "first line is a comment");

ok($cron[1]->{type} eq "comment", "second line is comment");
ok($cron[1]->{line} eq "# Shell variable for cron", "got the line content #2");

ok($cron[2]->{type} eq "env", "3rd line is a env variable");
ok($cron[2]->{name} eq "SHELL", "name is SHELL");
ok($cron[2]->{value} eq "/bin/bash", "value is /bin/bash");

ok($cron[3]->{type} eq "comment", "another comment");
ok($cron[4]->{type} eq "env", "another env - path");
ok($cron[4]->{name} eq "PATH", "path env");
ok($cron[4]->{value} eq "/usr/local/bin:/usr/local/sbin:/sbin:/usr/sbin:/bin:/usr/bin:/usr/bin/X11", "path env value");

ok($cron[5]->{type} eq "env", "myvar env");
ok($cron[5]->{name} eq "MYVAR", "myvar env got name");
ok($cron[5]->{value} eq '"foo=bar"', "myvar env got value");

ok($cron[6]->{type} eq "comment", "yet another comment");

ok($cron[7]->{type} eq "comment", "yet another line comment");

ok($cron[8]->{type} eq "job", "the first job");
ok($cron[8]->{cron}->{min} == 5, "the first job / min");
ok($cron[8]->{cron}->{hour} eq "9-20", "the first job / hour");
ok($cron[8]->{cron}->{day} eq "*", "the first job / day");
ok($cron[8]->{cron}->{mon} eq "*", "the first job / month");
ok($cron[8]->{cron}->{dow} eq "*", "the first job / day of week");
ok($cron[8]->{cron}->{cmd} eq "/home/username/script/script1.sh > /dev/null", "the first job / cmd");

ok($cron[9]->{type} eq "job", "the 2nd job");
ok($cron[9]->{cron}->{min} eq "*/10", "the 2nd job / min");
ok($cron[9]->{cron}->{hour} eq "*", "the 2nd job / hour");
ok($cron[9]->{cron}->{day} eq "*", "the 2nd job / day");
ok($cron[9]->{cron}->{mon} eq "*", "the 2nd job / month");
ok($cron[9]->{cron}->{dow} eq "*", "the 2nd job / day of week");
ok($cron[9]->{cron}->{cmd} eq "/usr/bin/script2.sh > /dev/null 2>&1", "the 2nd job / cmd");

ok($cron[10]->{type} eq "job", "the 3rd job");
ok($cron[10]->{cron}->{min} eq "59", "the 3rd job / min");
ok($cron[10]->{cron}->{hour} eq "23", "the 3rd job / hour");
ok($cron[10]->{cron}->{day} eq "*", "the 3rd job / day");
ok($cron[10]->{cron}->{mon} eq "*", "the 3rd job / month");
ok($cron[10]->{cron}->{dow} eq "0,4", "the 3rd job / day of week");
ok($cron[10]->{cron}->{cmd} eq "cp /pfad/zu/datei /pfad/zur/kopie", "the 3rd job / cmd");

ok($cron[11]->{type} eq "job", "the 4th job");
ok($cron[11]->{cron}->{min} eq "*", "the 4th job / min");
ok($cron[11]->{cron}->{hour} eq "*", "the 4th job / hour");
ok($cron[11]->{cron}->{day} eq "*", "the 4th job / day");
ok($cron[11]->{cron}->{mon} eq "*", "the 4th job / month");
ok($cron[11]->{cron}->{dow} eq "*", "the 4th job / day of week");
ok($cron[11]->{cron}->{cmd} eq 'DISPLAY=:0 LANG=de_DE.UTF-8 zenity --info --text "Beispiel für das Starten eines Programmes mit GUI"', "the 4th job / cmd");

ok($cron[12]->{type} eq "job", "the 5th job");
ok($cron[12]->{cron}->{min} eq "0", "the 5th job / min");
ok($cron[12]->{cron}->{hour} eq "0", "the 5th job / hour");
ok($cron[12]->{cron}->{day} eq "*", "the 5th job / day");
ok($cron[12]->{cron}->{mon} eq "*", "the 5th job / month");
ok($cron[12]->{cron}->{dow} eq "*", "the 5th job / day of week");
ok($cron[12]->{cron}->{cmd} eq "backup", "the 5th job / cmd");






