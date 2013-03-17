use Test::More tests => 267;

use Data::Dumper;

use_ok 'Rex::Cron';
use_ok 'Rex::Cron::Base';
use_ok 'Rex::Cron::Linux';
use_ok 'Rex::Cron::SunOS';
use_ok 'Rex::Commands::Cron';

my @lines = eval { local(@ARGV) = ("t/cron.ex"); <>; };
chomp @lines;

my $c = Rex::Cron::Base->new;
$c->parse_cron(@lines);
my @cron = $c->list;

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
ok($cron[8]->{cron}->{minute} == 5, "the first job / min");
ok($cron[8]->{cron}->{hour} eq "9-20", "the first job / hour");
ok($cron[8]->{cron}->{day_of_month} eq "*", "the first job / day");
ok($cron[8]->{cron}->{month} eq "*", "the first job / month");
ok($cron[8]->{cron}->{day_of_week} eq "*", "the first job / day_of_month of week");
ok($cron[8]->{cron}->{command} eq "/home/username/script/script1.sh > /dev/null", "the first job / cmd");

ok($cron[9]->{type} eq "job", "the 2nd job");
ok($cron[9]->{cron}->{minute} eq "*/10", "the 2nd job / min");
ok($cron[9]->{cron}->{hour} eq "*", "the 2nd job / hour");
ok($cron[9]->{cron}->{day_of_month} eq "*", "the 2nd job / day");
ok($cron[9]->{cron}->{month} eq "*", "the 2nd job / month");
ok($cron[9]->{cron}->{day_of_week} eq "*", "the 2nd job / day_of_month of week");
ok($cron[9]->{cron}->{command} eq "/usr/bin/script2.sh > /dev/null 2>&1", "the 2nd job / cmd");

ok($cron[10]->{type} eq "job", "the 3rd job");
ok($cron[10]->{cron}->{minute} eq "59", "the 3rd job / min");
ok($cron[10]->{cron}->{hour} eq "23", "the 3rd job / hour");
ok($cron[10]->{cron}->{day_of_month} eq "*", "the 3rd job / day");
ok($cron[10]->{cron}->{month} eq "*", "the 3rd job / month");
ok($cron[10]->{cron}->{day_of_week} eq "0,4", "the 3rd job / day_of_month of week");
ok($cron[10]->{cron}->{command} eq "cp /pfad/zu/datei /pfad/zur/kopie", "the 3rd job / cmd");

ok($cron[11]->{type} eq "job", "the 4th job");
ok($cron[11]->{cron}->{minute} eq "*", "the 4th job / min");
ok($cron[11]->{cron}->{hour} eq "*", "the 4th job / hour");
ok($cron[11]->{cron}->{day_of_month} eq "*", "the 4th job / day");
ok($cron[11]->{cron}->{month} eq "*", "the 4th job / month");
ok($cron[11]->{cron}->{day_of_week} eq "*", "the 4th job / day_of_month of week");
ok($cron[11]->{cron}->{command} eq 'DISPLAY=:0 LANG=de_DE.UTF-8 zenity --info --text "Beispiel für das Starten eines Programmes mit GUI"', "the 4th job / cmd");

ok($cron[12]->{type} eq "job", "the 5th job");
ok($cron[12]->{cron}->{minute} eq "0", "the 5th job / min");
ok($cron[12]->{cron}->{hour} eq "0", "the 5th job / hour");
ok($cron[12]->{cron}->{day_of_month} eq "*", "the 5th job / day");
ok($cron[12]->{cron}->{month} eq "*", "the 5th job / month");
ok($cron[12]->{cron}->{day_of_week} eq "*", "the 5th job / day_of_month of week");
ok($cron[12]->{cron}->{command} eq "backup", "the 5th job / cmd");

ok($cron[13]->{type} eq "comment", "last line is comment");


$c->add(
   minute => "1",
   hour   => "2",
   day_of_month => "3",
   month => "4",
   day_of_week => "5",
   command => "ls",
);

$c->add(
   command => "foo",
);

$c->add(
   hour => "5,6,7",
   month => "*/2",
   command => "bar",
);

@cron = $c->list;

ok($cron[14]->{type} eq "job", "the 6th job");
ok($cron[14]->{cron}->{minute} eq "1", "the 6th job / min");
ok($cron[14]->{cron}->{hour} eq "2", "the 6th job / hour");
ok($cron[14]->{cron}->{day_of_month} eq "3", "the 6th job / day");
ok($cron[14]->{cron}->{month} eq "4", "the 6th job / month");
ok($cron[14]->{cron}->{day_of_week} eq "5", "the 6th job / day_of_month of week");
ok($cron[14]->{cron}->{command} eq "ls", "the 6th job / cmd");
ok($cron[14]->{line} eq "1 2 3 4 5 ls", "the 6th job / cron line");

ok($cron[15]->{type} eq "job", "the 7th job");
ok($cron[15]->{cron}->{minute} eq "*", "the 7th job / min");
ok($cron[15]->{cron}->{hour} eq "*", "the 7th job / hour");
ok($cron[15]->{cron}->{day_of_month} eq "*", "the 7th job / day");
ok($cron[15]->{cron}->{month} eq "*", "the 7th job / month");
ok($cron[15]->{cron}->{day_of_week} eq "*", "the 7th job / day_of_month of week");
ok($cron[15]->{cron}->{command} eq "foo", "the 7th job / cmd");
ok($cron[15]->{line} eq "* * * * * foo", "the 7th job / cron line");

ok($cron[16]->{type} eq "job", "the 8th job");
ok($cron[16]->{cron}->{minute} eq "*", "the 8th job / min");
ok($cron[16]->{cron}->{hour} eq "5,6,7", "the 8th job / hour");
ok($cron[16]->{cron}->{day_of_month} eq "*", "the 8th job / day");
ok($cron[16]->{cron}->{month} eq "*/2", "the 8th job / month");
ok($cron[16]->{cron}->{day_of_week} eq "*", "the 8th job / day_of_month of week");
ok($cron[16]->{cron}->{command} eq "bar", "the 8th job / cmd");
ok($cron[16]->{line} eq "* 5,6,7 * */2 * bar", "the 8th job / cron line");


#
# Write new entries and test again
#

my $file = $c->write_cron();
@lines = undef;
@lines = eval { local(@ARGV) = ($file); <>; };
chomp @lines;
unlink $file;

$c = Rex::Cron::Base->new;
$c->parse_cron(@lines);
@cron = $c->list;

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
ok($cron[8]->{cron}->{minute} == 5, "the first job / min");
ok($cron[8]->{cron}->{hour} eq "9-20", "the first job / hour");
ok($cron[8]->{cron}->{day_of_month} eq "*", "the first job / day");
ok($cron[8]->{cron}->{month} eq "*", "the first job / month");
ok($cron[8]->{cron}->{day_of_week} eq "*", "the first job / day_of_month of week");
ok($cron[8]->{cron}->{command} eq "/home/username/script/script1.sh > /dev/null", "the first job / cmd");

ok($cron[9]->{type} eq "job", "the 2nd job");
ok($cron[9]->{cron}->{minute} eq "*/10", "the 2nd job / min");
ok($cron[9]->{cron}->{hour} eq "*", "the 2nd job / hour");
ok($cron[9]->{cron}->{day_of_month} eq "*", "the 2nd job / day");
ok($cron[9]->{cron}->{month} eq "*", "the 2nd job / month");
ok($cron[9]->{cron}->{day_of_week} eq "*", "the 2nd job / day_of_month of week");
ok($cron[9]->{cron}->{command} eq "/usr/bin/script2.sh > /dev/null 2>&1", "the 2nd job / cmd");

ok($cron[10]->{type} eq "job", "the 3rd job");
ok($cron[10]->{cron}->{minute} eq "59", "the 3rd job / min");
ok($cron[10]->{cron}->{hour} eq "23", "the 3rd job / hour");
ok($cron[10]->{cron}->{day_of_month} eq "*", "the 3rd job / day");
ok($cron[10]->{cron}->{month} eq "*", "the 3rd job / month");
ok($cron[10]->{cron}->{day_of_week} eq "0,4", "the 3rd job / day_of_month of week");
ok($cron[10]->{cron}->{command} eq "cp /pfad/zu/datei /pfad/zur/kopie", "the 3rd job / cmd");

ok($cron[11]->{type} eq "job", "the 4th job");
ok($cron[11]->{cron}->{minute} eq "*", "the 4th job / min");
ok($cron[11]->{cron}->{hour} eq "*", "the 4th job / hour");
ok($cron[11]->{cron}->{day_of_month} eq "*", "the 4th job / day");
ok($cron[11]->{cron}->{month} eq "*", "the 4th job / month");
ok($cron[11]->{cron}->{day_of_week} eq "*", "the 4th job / day_of_month of week");
ok($cron[11]->{cron}->{command} eq 'DISPLAY=:0 LANG=de_DE.UTF-8 zenity --info --text "Beispiel für das Starten eines Programmes mit GUI"', "the 4th job / cmd");

ok($cron[12]->{type} eq "job", "the 5th job");
ok($cron[12]->{cron}->{minute} eq "0", "the 5th job / min");
ok($cron[12]->{cron}->{hour} eq "0", "the 5th job / hour");
ok($cron[12]->{cron}->{day_of_month} eq "*", "the 5th job / day");
ok($cron[12]->{cron}->{month} eq "*", "the 5th job / month");
ok($cron[12]->{cron}->{day_of_week} eq "*", "the 5th job / day_of_month of week");
ok($cron[12]->{cron}->{command} eq "backup", "the 5th job / cmd");

ok($cron[13]->{type} eq "comment", "last line is comment");

ok($cron[14]->{type} eq "job", "the 6th job");
ok($cron[14]->{cron}->{minute} eq "1", "the 6th job / min");
ok($cron[14]->{cron}->{hour} eq "2", "the 6th job / hour");
ok($cron[14]->{cron}->{day_of_month} eq "3", "the 6th job / day");
ok($cron[14]->{cron}->{month} eq "4", "the 6th job / month");
ok($cron[14]->{cron}->{day_of_week} eq "5", "the 6th job / day_of_month of week");
ok($cron[14]->{cron}->{command} eq "ls", "the 6th job / cmd");
ok($cron[14]->{line} eq "1 2 3 4 5 ls", "the 6th job / cron line");

ok($cron[15]->{type} eq "job", "the 7th job");
ok($cron[15]->{cron}->{minute} eq "*", "the 7th job / min");
ok($cron[15]->{cron}->{hour} eq "*", "the 7th job / hour");
ok($cron[15]->{cron}->{day_of_month} eq "*", "the 7th job / day");
ok($cron[15]->{cron}->{month} eq "*", "the 7th job / month");
ok($cron[15]->{cron}->{day_of_week} eq "*", "the 7th job / day_of_month of week");
ok($cron[15]->{cron}->{command} eq "foo", "the 7th job / cmd");
ok($cron[15]->{line} eq "* * * * * foo", "the 7th job / cron line");

ok($cron[16]->{type} eq "job", "the 8th job");
ok($cron[16]->{cron}->{minute} eq "*", "the 8th job / min");
ok($cron[16]->{cron}->{hour} eq "5,6,7", "the 8th job / hour");
ok($cron[16]->{cron}->{day_of_month} eq "*", "the 8th job / day");
ok($cron[16]->{cron}->{month} eq "*/2", "the 8th job / month");
ok($cron[16]->{cron}->{day_of_week} eq "*", "the 8th job / day_of_month of week");
ok($cron[16]->{cron}->{command} eq "bar", "the 8th job / cmd");
ok($cron[16]->{line} eq "* 5,6,7 * */2 * bar", "the 8th job / cron line");


#
# Delete 2 entries
#

$c->delete(14);
$c->delete(9);

@cron = $c->list;

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
ok($cron[8]->{cron}->{minute} == 5, "the first job / min");
ok($cron[8]->{cron}->{hour} eq "9-20", "the first job / hour");
ok($cron[8]->{cron}->{day_of_month} eq "*", "the first job / day");
ok($cron[8]->{cron}->{month} eq "*", "the first job / month");
ok($cron[8]->{cron}->{day_of_week} eq "*", "the first job / day_of_month of week");
ok($cron[8]->{cron}->{command} eq "/home/username/script/script1.sh > /dev/null", "the first job / cmd");

ok($cron[9]->{type} eq "job", "the 3rd job");
ok($cron[9]->{cron}->{minute} eq "59", "the 3rd job / min");
ok($cron[9]->{cron}->{hour} eq "23", "the 3rd job / hour");
ok($cron[9]->{cron}->{day_of_month} eq "*", "the 3rd job / day");
ok($cron[9]->{cron}->{month} eq "*", "the 3rd job / month");
ok($cron[9]->{cron}->{day_of_week} eq "0,4", "the 3rd job / day_of_month of week");
ok($cron[9]->{cron}->{command} eq "cp /pfad/zu/datei /pfad/zur/kopie", "the 3rd job / cmd");

ok($cron[10]->{type} eq "job", "the 4th job");
ok($cron[10]->{cron}->{minute} eq "*", "the 4th job / min");
ok($cron[10]->{cron}->{hour} eq "*", "the 4th job / hour");
ok($cron[10]->{cron}->{day_of_month} eq "*", "the 4th job / day");
ok($cron[10]->{cron}->{month} eq "*", "the 4th job / month");
ok($cron[10]->{cron}->{day_of_week} eq "*", "the 4th job / day_of_month of week");
ok($cron[10]->{cron}->{command} eq 'DISPLAY=:0 LANG=de_DE.UTF-8 zenity --info --text "Beispiel für das Starten eines Programmes mit GUI"', "the 4th job / cmd");

ok($cron[11]->{type} eq "job", "the 5th job");
ok($cron[11]->{cron}->{minute} eq "0", "the 5th job / min");
ok($cron[11]->{cron}->{hour} eq "0", "the 5th job / hour");
ok($cron[11]->{cron}->{day_of_month} eq "*", "the 5th job / day");
ok($cron[11]->{cron}->{month} eq "*", "the 5th job / month");
ok($cron[11]->{cron}->{day_of_week} eq "*", "the 5th job / day_of_month of week");
ok($cron[11]->{cron}->{command} eq "backup", "the 5th job / cmd");

ok($cron[12]->{type} eq "comment", "last line is comment");

ok($cron[13]->{type} eq "job", "the 7th job");
ok($cron[13]->{cron}->{minute} eq "*", "the 7th job / min");
ok($cron[13]->{cron}->{hour} eq "*", "the 7th job / hour");
ok($cron[13]->{cron}->{day_of_month} eq "*", "the 7th job / day");
ok($cron[13]->{cron}->{month} eq "*", "the 7th job / month");
ok($cron[13]->{cron}->{day_of_week} eq "*", "the 7th job / day_of_month of week");
ok($cron[13]->{cron}->{command} eq "foo", "the 7th job / cmd");
ok($cron[13]->{line} eq "* * * * * foo", "the 7th job / cron line");

ok($cron[14]->{type} eq "job", "the 8th job");
ok($cron[14]->{cron}->{minute} eq "*", "the 8th job / min");
ok($cron[14]->{cron}->{hour} eq "5,6,7", "the 8th job / hour");
ok($cron[14]->{cron}->{day_of_month} eq "*", "the 8th job / day");
ok($cron[14]->{cron}->{month} eq "*/2", "the 8th job / month");
ok($cron[14]->{cron}->{day_of_week} eq "*", "the 8th job / day_of_month of week");
ok($cron[14]->{cron}->{command} eq "bar", "the 8th job / cmd");
ok($cron[14]->{line} eq "* 5,6,7 * */2 * bar", "the 8th job / cron line");


$c->add_env(
   "FOOVAR" => "FOOVAL",
);

$c->add_env(
   "BARVAR" => "BARVAL",
);

@cron = $c->list;

ok($cron[0]->{type} eq "env", "1st line is now env");
ok($cron[0]->{name} eq "BARVAR", "1st line / name");
ok($cron[0]->{value} eq "BARVAL", "1st line / value");
ok($cron[0]->{line} eq 'BARVAR="BARVAL"', "1st line / value");

ok($cron[1]->{type} eq "env", "2nd line is now env");
ok($cron[1]->{name} eq "FOOVAR", "2nd line / name");
ok($cron[1]->{value} eq "FOOVAL", "2nd line / value");
ok($cron[1]->{line} eq 'FOOVAR="FOOVAL"', "2nd line / value");

@cron = $c->list_jobs;

ok($cron[0]->{minute} == 5, "the first job / min");
ok($cron[0]->{hour} eq "9-20", "the first job / hour");
ok($cron[0]->{day_of_month} eq "*", "the first job / day");
ok($cron[0]->{month} eq "*", "the first job / month");
ok($cron[0]->{day_of_week} eq "*", "the first job / day_of_month of week");
ok($cron[0]->{command} eq "/home/username/script/script1.sh > /dev/null", "the first job / cmd");

ok($cron[1]->{minute} eq "59", "the second job / min");
ok($cron[1]->{hour} eq "23", "the second job / hour");
ok($cron[1]->{day_of_month} eq "*", "the second job / day");
ok($cron[1]->{month} eq "*", "the second job / month");
ok($cron[1]->{day_of_week} eq "0,4", "the second job / day_of_month of week");
ok($cron[1]->{command} eq "cp /pfad/zu/datei /pfad/zur/kopie", "the second job / cmd");

ok($cron[2]->{minute} eq "*", "the third job / min");
ok($cron[2]->{hour} eq "*", "the third job / hour");
ok($cron[2]->{day_of_month} eq "*", "the third job / day");
ok($cron[2]->{month} eq "*", "the third job / month");
ok($cron[2]->{day_of_week} eq "*", "the third job / day_of_month of week");
ok($cron[2]->{command} eq 'DISPLAY=:0 LANG=de_DE.UTF-8 zenity --info --text "Beispiel für das Starten eines Programmes mit GUI"', "the third job / cmd");

$c->delete_job(1);
$c->delete_job(0);

@cron = $c->list;

ok($cron[0]->{type} eq "env", "1st line is now env");
ok($cron[0]->{name} eq "BARVAR", "1st line / name");
ok($cron[0]->{value} eq "BARVAL", "1st line / value");
ok($cron[0]->{line} eq 'BARVAR="BARVAL"', "1st line / value");

ok($cron[1]->{type} eq "env", "2nd line is now env");
ok($cron[1]->{name} eq "FOOVAR", "2nd line / name");
ok($cron[1]->{value} eq "FOOVAL", "2nd line / value");
ok($cron[1]->{line} eq 'FOOVAR="FOOVAL"', "2nd line / value");

@cron = $c->list_jobs;

ok($cron[0]->{minute} eq "*", "the third job / min");
ok($cron[0]->{hour} eq "*", "the third job / hour");
ok($cron[0]->{day_of_month} eq "*", "the third job / day");
ok($cron[0]->{month} eq "*", "the third job / month");
ok($cron[0]->{day_of_week} eq "*", "the third job / day_of_month of week");
ok($cron[0]->{command} eq 'DISPLAY=:0 LANG=de_DE.UTF-8 zenity --info --text "Beispiel für das Starten eines Programmes mit GUI"', "the third job / cmd");


@cron = $c->list_envs;

ok($cron[0]->{name} eq "BARVAR", "1st env name");
ok($cron[0]->{value} eq "BARVAL", "1st env name");
ok($cron[0]->{line} eq 'BARVAR="BARVAL"', "1st env name");

ok($cron[1]->{name} eq "FOOVAR", "2nd env name");
ok($cron[1]->{value} eq "FOOVAL", "2nd env name");
ok($cron[1]->{line} eq 'FOOVAR="FOOVAL"', "2nd env name");

ok($cron[2]->{name} eq "SHELL", "3rd env name");
ok($cron[2]->{value} eq "/bin/bash", "3rd env name");
ok($cron[2]->{line} eq 'SHELL=/bin/bash', "3rd env name");

$c->delete_env(1);
$c->delete_env(0);

@cron = $c->list_envs;

ok($cron[0]->{name} eq "SHELL", "3rd env name");
ok($cron[0]->{value} eq "/bin/bash", "3rd env name");
ok($cron[0]->{line} eq 'SHELL=/bin/bash', "3rd env name");


