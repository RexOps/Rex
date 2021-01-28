use Test::More;

$^O =~ m/^MSWin/ ? plan tests => 83 : plan tests => 286;

use Rex::Cron::Base;

my @lines = eval { local (@ARGV) = ("t/cron.ex"); <>; };
chomp @lines;

my $c = Rex::Cron::Base->new;
$c->parse_cron(@lines);
my @cron = $c->list;

is( $cron[0]->{type}, "comment", "first line is a comment" );

is( $cron[1]->{type}, "comment",                   "second line is comment" );
is( $cron[1]->{line}, "# Shell variable for cron", "got the line content #2" );

is( $cron[2]->{type},  "env",       "3rd line is a env variable" );
is( $cron[2]->{name},  "SHELL",     "name is SHELL" );
is( $cron[2]->{value}, "/bin/bash", "value is /bin/bash" );

is( $cron[3]->{type}, "comment", "another comment" );
is( $cron[4]->{type}, "env",     "another env - path" );
is( $cron[4]->{name}, "PATH",    "path env" );
is(
  $cron[4]->{value},
  "/usr/local/bin:/usr/local/sbin:/sbin:/usr/sbin:/bin:/usr/bin:/usr/bin/X11",
  "path env value"
);

is( $cron[5]->{type},  "env",       "myvar env" );
is( $cron[5]->{name},  "MYVAR",     "myvar env got name" );
is( $cron[5]->{value}, '"foo=bar"', "myvar env got value" );

is( $cron[6]->{type}, "comment", "yet another comment" );

is( $cron[7]->{type}, "comment", "yet another line comment" );

is( $cron[8]->{type},                 "job",  "the first job" );
is( $cron[8]->{cron}->{minute},       5,      "the first job / min" );
is( $cron[8]->{cron}->{hour},         "9-20", "the first job / hour" );
is( $cron[8]->{cron}->{day_of_month}, "*",    "the first job / day" );
is( $cron[8]->{cron}->{month},        "*",    "the first job / month" );
is( $cron[8]->{cron}->{day_of_week},
  "*", "the first job / day_of_month of week" );
is(
  $cron[8]->{cron}->{command},
  "/home/username/script/script1.sh > /dev/null",
  "the first job / cmd"
);

is( $cron[9]->{type},                 "job",  "the 2nd job" );
is( $cron[9]->{cron}->{minute},       "*/10", "the 2nd job / min" );
is( $cron[9]->{cron}->{hour},         "*",    "the 2nd job / hour" );
is( $cron[9]->{cron}->{day_of_month}, "*",    "the 2nd job / day" );
is( $cron[9]->{cron}->{month},        "*",    "the 2nd job / month" );
is( $cron[9]->{cron}->{day_of_week}, "*",
  "the 2nd job / day_of_month of week" );
is(
  $cron[9]->{cron}->{command},
  "/usr/bin/script2.sh > /dev/null 2>&1",
  "the 2nd job / cmd"
);

is( $cron[10]->{type},                 "job", "the 3rd job" );
is( $cron[10]->{cron}->{minute},       "59",  "the 3rd job / min" );
is( $cron[10]->{cron}->{hour},         "23",  "the 3rd job / hour" );
is( $cron[10]->{cron}->{day_of_month}, "*",   "the 3rd job / day" );
is( $cron[10]->{cron}->{month},        "*",   "the 3rd job / month" );
is( $cron[10]->{cron}->{day_of_week},
  "0,4", "the 3rd job / day_of_month of week" );
is(
  $cron[10]->{cron}->{command},
  "cp /pfad/zu/datei /pfad/zur/kopie",
  "the 3rd job / cmd"
);

is( $cron[11]->{type},                 "job", "the 4th job" );
is( $cron[11]->{cron}->{minute},       "*",   "the 4th job / min" );
is( $cron[11]->{cron}->{hour},         "*",   "the 4th job / hour" );
is( $cron[11]->{cron}->{day_of_month}, "*",   "the 4th job / day" );
is( $cron[11]->{cron}->{month},        "*",   "the 4th job / month" );
is( $cron[11]->{cron}->{day_of_week},
  "*", "the 4th job / day_of_month of week" );
like(
  $cron[11]->{cron}->{command},
  qr/DISPLAY=:0 LANG=de_DE.UTF-8 zenity --info --text/i,
  "the 4th job / cmd"
);

is( $cron[12]->{type},                 "job", "the 5th job" );
is( $cron[12]->{cron}->{minute},       "0",   "the 5th job / min" );
is( $cron[12]->{cron}->{hour},         "0",   "the 5th job / hour" );
is( $cron[12]->{cron}->{day_of_month}, "*",   "the 5th job / day" );
is( $cron[12]->{cron}->{month},        "*",   "the 5th job / month" );
is( $cron[12]->{cron}->{day_of_week},
  "*", "the 5th job / day_of_month of week" );
is( $cron[12]->{cron}->{command}, "backup", "the 5th job / cmd" );

is( $cron[13]->{type}, "comment", "last line is comment" );

$c->add(
  minute       => "1",
  hour         => "2",
  day_of_month => "3",
  month        => "4",
  day_of_week  => "5",
  command      => "ls",
);

$c->add( command => "foo", );

$c->add(
  hour    => "5,6,7",
  month   => "*/2",
  command => "bar",
);

$c->add(
  minute      => "0",
  hour        => "0",
  day_of_week => "0",
);

@cron = $c->list;

is( $cron[14]->{type},                 "job", "the 6th job" );
is( $cron[14]->{cron}->{minute},       "1",   "the 6th job / min" );
is( $cron[14]->{cron}->{hour},         "2",   "the 6th job / hour" );
is( $cron[14]->{cron}->{day_of_month}, "3",   "the 6th job / day" );
is( $cron[14]->{cron}->{month},        "4",   "the 6th job / month" );
is( $cron[14]->{cron}->{day_of_week},
  "5", "the 6th job / day_of_month of week" );
is( $cron[14]->{cron}->{command}, "ls",           "the 6th job / cmd" );
is( $cron[14]->{line},            "1 2 3 4 5 ls", "the 6th job / cron line" );

is( $cron[15]->{type},                 "job", "the 7th job" );
is( $cron[15]->{cron}->{minute},       "*",   "the 7th job / min" );
is( $cron[15]->{cron}->{hour},         "*",   "the 7th job / hour" );
is( $cron[15]->{cron}->{day_of_month}, "*",   "the 7th job / day" );
is( $cron[15]->{cron}->{month},        "*",   "the 7th job / month" );
is( $cron[15]->{cron}->{day_of_week},
  "*", "the 7th job / day_of_month of week" );
is( $cron[15]->{cron}->{command}, "foo",           "the 7th job / cmd" );
is( $cron[15]->{line},            "* * * * * foo", "the 7th job / cron line" );

is( $cron[16]->{type},                 "job",   "the 8th job" );
is( $cron[16]->{cron}->{minute},       "*",     "the 8th job / min" );
is( $cron[16]->{cron}->{hour},         "5,6,7", "the 8th job / hour" );
is( $cron[16]->{cron}->{day_of_month}, "*",     "the 8th job / day" );
is( $cron[16]->{cron}->{month},        "*/2",   "the 8th job / month" );
is( $cron[16]->{cron}->{day_of_week},
  "*", "the 8th job / day_of_month of week" );
is( $cron[16]->{cron}->{command}, "bar", "the 8th job / cmd" );
is( $cron[16]->{line}, "* 5,6,7 * */2 * bar", "the 8th job / cron line" );

is( $cron[17]->{type},                 "job", "the 9th job" );
is( $cron[17]->{cron}->{minute},       "0",   "the 9th job / min" );
is( $cron[17]->{cron}->{hour},         "0",   "the 9th job / hour" );
is( $cron[17]->{cron}->{day_of_month}, "*",   "the 9th job / day" );
is( $cron[17]->{cron}->{month},        "*",   "the 9th job / month" );
is( $cron[17]->{cron}->{day_of_week},
  "0", "the 9th job / day_of_month of week" );
is( $cron[17]->{cron}->{command}, "false", "the 9th job / cmd" );
is( $cron[17]->{line}, "0 0 * * 0 false", "the 9th job / cron line" );

unless ( $^O =~ m/^MSWin/ ) {
  #
  # Write new entries and test again
  #

  my $file = $c->write_cron();
  @lines = undef;
  @lines = eval { local (@ARGV) = ($file); <>; };
  chomp @lines;
  unlink $file;

  $c = Rex::Cron::Base->new;
  $c->parse_cron(@lines);
  @cron = $c->list;

  is( $cron[0]->{type}, "comment", "first line is a comment" );

  is( $cron[1]->{type}, "comment", "second line is comment" );
  is( $cron[1]->{line}, "# Shell variable for cron",
    "got the line content #2" );

  is( $cron[2]->{type},  "env",       "3rd line is a env variable" );
  is( $cron[2]->{name},  "SHELL",     "name is SHELL" );
  is( $cron[2]->{value}, "/bin/bash", "value is /bin/bash" );

  is( $cron[3]->{type}, "comment", "another comment" );
  is( $cron[4]->{type}, "env",     "another env - path" );
  is( $cron[4]->{name}, "PATH",    "path env" );
  is(
    $cron[4]->{value},
    "/usr/local/bin:/usr/local/sbin:/sbin:/usr/sbin:/bin:/usr/bin:/usr/bin/X11",
    "path env value"
  );

  is( $cron[5]->{type},  "env",       "myvar env" );
  is( $cron[5]->{name},  "MYVAR",     "myvar env got name" );
  is( $cron[5]->{value}, '"foo=bar"', "myvar env got value" );

  is( $cron[6]->{type}, "comment", "yet another comment" );

  is( $cron[7]->{type}, "comment", "yet another line comment" );

  is( $cron[8]->{type},                 "job",  "the first job" );
  is( $cron[8]->{cron}->{minute},       5,      "the first job / min" );
  is( $cron[8]->{cron}->{hour},         "9-20", "the first job / hour" );
  is( $cron[8]->{cron}->{day_of_month}, "*",    "the first job / day" );
  is( $cron[8]->{cron}->{month},        "*",    "the first job / month" );
  is( $cron[8]->{cron}->{day_of_week},
    "*", "the first job / day_of_month of week" );
  is(
    $cron[8]->{cron}->{command},
    "/home/username/script/script1.sh > /dev/null",
    "the first job / cmd"
  );

  is( $cron[9]->{type},                 "job",  "the 2nd job" );
  is( $cron[9]->{cron}->{minute},       "*/10", "the 2nd job / min" );
  is( $cron[9]->{cron}->{hour},         "*",    "the 2nd job / hour" );
  is( $cron[9]->{cron}->{day_of_month}, "*",    "the 2nd job / day" );
  is( $cron[9]->{cron}->{month},        "*",    "the 2nd job / month" );
  is( $cron[9]->{cron}->{day_of_week},
    "*", "the 2nd job / day_of_month of week" );
  is(
    $cron[9]->{cron}->{command},
    "/usr/bin/script2.sh > /dev/null 2>&1",
    "the 2nd job / cmd"
  );

  is( $cron[10]->{type},                 "job", "the 3rd job" );
  is( $cron[10]->{cron}->{minute},       "59",  "the 3rd job / min" );
  is( $cron[10]->{cron}->{hour},         "23",  "the 3rd job / hour" );
  is( $cron[10]->{cron}->{day_of_month}, "*",   "the 3rd job / day" );
  is( $cron[10]->{cron}->{month},        "*",   "the 3rd job / month" );
  is( $cron[10]->{cron}->{day_of_week},
    "0,4", "the 3rd job / day_of_month of week" );
  is(
    $cron[10]->{cron}->{command},
    "cp /pfad/zu/datei /pfad/zur/kopie",
    "the 3rd job / cmd"
  );

  is( $cron[11]->{type},                 "job", "the 4th job" );
  is( $cron[11]->{cron}->{minute},       "*",   "the 4th job / min" );
  is( $cron[11]->{cron}->{hour},         "*",   "the 4th job / hour" );
  is( $cron[11]->{cron}->{day_of_month}, "*",   "the 4th job / day" );
  is( $cron[11]->{cron}->{month},        "*",   "the 4th job / month" );
  is( $cron[11]->{cron}->{day_of_week},
    "*", "the 4th job / day_of_month of week" );
  is(
    $cron[11]->{cron}->{command},
    'DISPLAY=:0 LANG=de_DE.UTF-8 zenity --info --text "Beispiel für das Starten eines Programmes mit GUI"',
    "the 4th job / cmd"
  );

  is( $cron[12]->{type},                 "job", "the 5th job" );
  is( $cron[12]->{cron}->{minute},       "0",   "the 5th job / min" );
  is( $cron[12]->{cron}->{hour},         "0",   "the 5th job / hour" );
  is( $cron[12]->{cron}->{day_of_month}, "*",   "the 5th job / day" );
  is( $cron[12]->{cron}->{month},        "*",   "the 5th job / month" );
  is( $cron[12]->{cron}->{day_of_week},
    "*", "the 5th job / day_of_month of week" );
  is( $cron[12]->{cron}->{command}, "backup", "the 5th job / cmd" );

  is( $cron[13]->{type}, "comment", "last line is comment" );

  is( $cron[14]->{type},                 "job", "the 6th job" );
  is( $cron[14]->{cron}->{minute},       "1",   "the 6th job / min" );
  is( $cron[14]->{cron}->{hour},         "2",   "the 6th job / hour" );
  is( $cron[14]->{cron}->{day_of_month}, "3",   "the 6th job / day" );
  is( $cron[14]->{cron}->{month},        "4",   "the 6th job / month" );
  is( $cron[14]->{cron}->{day_of_week},
    "5", "the 6th job / day_of_month of week" );
  is( $cron[14]->{cron}->{command}, "ls",           "the 6th job / cmd" );
  is( $cron[14]->{line},            "1 2 3 4 5 ls", "the 6th job / cron line" );

  is( $cron[15]->{type},                 "job", "the 7th job" );
  is( $cron[15]->{cron}->{minute},       "*",   "the 7th job / min" );
  is( $cron[15]->{cron}->{hour},         "*",   "the 7th job / hour" );
  is( $cron[15]->{cron}->{day_of_month}, "*",   "the 7th job / day" );
  is( $cron[15]->{cron}->{month},        "*",   "the 7th job / month" );
  is( $cron[15]->{cron}->{day_of_week},
    "*", "the 7th job / day_of_month of week" );
  is( $cron[15]->{cron}->{command}, "foo", "the 7th job / cmd" );
  is( $cron[15]->{line}, "* * * * * foo", "the 7th job / cron line" );

  is( $cron[16]->{type},                 "job",   "the 8th job" );
  is( $cron[16]->{cron}->{minute},       "*",     "the 8th job / min" );
  is( $cron[16]->{cron}->{hour},         "5,6,7", "the 8th job / hour" );
  is( $cron[16]->{cron}->{day_of_month}, "*",     "the 8th job / day" );
  is( $cron[16]->{cron}->{month},        "*/2",   "the 8th job / month" );
  is( $cron[16]->{cron}->{day_of_week},
    "*", "the 8th job / day_of_month of week" );
  is( $cron[16]->{cron}->{command}, "bar", "the 8th job / cmd" );
  is( $cron[16]->{line}, "* 5,6,7 * */2 * bar", "the 8th job / cron line" );

  is( $cron[17]->{type},                 "job", "the 9th job" );
  is( $cron[17]->{cron}->{minute},       "0",   "the 9th job / min" );
  is( $cron[17]->{cron}->{hour},         "0",   "the 9th job / hour" );
  is( $cron[17]->{cron}->{day_of_month}, "*",   "the 9th job / day" );
  is( $cron[17]->{cron}->{month},        "*",   "the 9th job / month" );
  is( $cron[17]->{cron}->{day_of_week},
    "0", "the 9th job / day_of_month of week" );
  is( $cron[17]->{cron}->{command}, "false", "the 9th job / cmd" );
  is( $cron[17]->{line}, "0 0 * * 0 false", "the 9th job / cron line" );

  #
  # Delete 2 entries
  #

  $c->delete(14);
  $c->delete(9);

  @cron = $c->list;

  is( $cron[0]->{type}, "comment", "first line is a comment" );

  is( $cron[1]->{type}, "comment", "second line is comment" );
  is( $cron[1]->{line}, "# Shell variable for cron",
    "got the line content #2" );

  is( $cron[2]->{type},  "env",       "3rd line is a env variable" );
  is( $cron[2]->{name},  "SHELL",     "name is SHELL" );
  is( $cron[2]->{value}, "/bin/bash", "value is /bin/bash" );

  is( $cron[3]->{type}, "comment", "another comment" );
  is( $cron[4]->{type}, "env",     "another env - path" );
  is( $cron[4]->{name}, "PATH",    "path env" );
  is(
    $cron[4]->{value},
    "/usr/local/bin:/usr/local/sbin:/sbin:/usr/sbin:/bin:/usr/bin:/usr/bin/X11",
    "path env value"
  );

  is( $cron[5]->{type},  "env",       "myvar env" );
  is( $cron[5]->{name},  "MYVAR",     "myvar env got name" );
  is( $cron[5]->{value}, '"foo=bar"', "myvar env got value" );

  is( $cron[6]->{type}, "comment", "yet another comment" );

  is( $cron[7]->{type}, "comment", "yet another line comment" );

  is( $cron[8]->{type},                 "job",  "the first job" );
  is( $cron[8]->{cron}->{minute},       5,      "the first job / min" );
  is( $cron[8]->{cron}->{hour},         "9-20", "the first job / hour" );
  is( $cron[8]->{cron}->{day_of_month}, "*",    "the first job / day" );
  is( $cron[8]->{cron}->{month},        "*",    "the first job / month" );
  is( $cron[8]->{cron}->{day_of_week},
    "*", "the first job / day_of_month of week" );
  is(
    $cron[8]->{cron}->{command},
    "/home/username/script/script1.sh > /dev/null",
    "the first job / cmd"
  );

  is( $cron[9]->{type},                 "job", "the 3rd job" );
  is( $cron[9]->{cron}->{minute},       "59",  "the 3rd job / min" );
  is( $cron[9]->{cron}->{hour},         "23",  "the 3rd job / hour" );
  is( $cron[9]->{cron}->{day_of_month}, "*",   "the 3rd job / day" );
  is( $cron[9]->{cron}->{month},        "*",   "the 3rd job / month" );
  is( $cron[9]->{cron}->{day_of_week},
    "0,4", "the 3rd job / day_of_month of week" );
  is(
    $cron[9]->{cron}->{command},
    "cp /pfad/zu/datei /pfad/zur/kopie",
    "the 3rd job / cmd"
  );

  is( $cron[10]->{type},                 "job", "the 4th job" );
  is( $cron[10]->{cron}->{minute},       "*",   "the 4th job / min" );
  is( $cron[10]->{cron}->{hour},         "*",   "the 4th job / hour" );
  is( $cron[10]->{cron}->{day_of_month}, "*",   "the 4th job / day" );
  is( $cron[10]->{cron}->{month},        "*",   "the 4th job / month" );
  is( $cron[10]->{cron}->{day_of_week},
    "*", "the 4th job / day_of_month of week" );
  is(
    $cron[10]->{cron}->{command},
    'DISPLAY=:0 LANG=de_DE.UTF-8 zenity --info --text "Beispiel für das Starten eines Programmes mit GUI"',
    "the 4th job / cmd"
  );

  is( $cron[11]->{type},                 "job", "the 5th job" );
  is( $cron[11]->{cron}->{minute},       "0",   "the 5th job / min" );
  is( $cron[11]->{cron}->{hour},         "0",   "the 5th job / hour" );
  is( $cron[11]->{cron}->{day_of_month}, "*",   "the 5th job / day" );
  is( $cron[11]->{cron}->{month},        "*",   "the 5th job / month" );
  is( $cron[11]->{cron}->{day_of_week},
    "*", "the 5th job / day_of_month of week" );
  is( $cron[11]->{cron}->{command}, "backup", "the 5th job / cmd" );

  is( $cron[12]->{type}, "comment", "last line is comment" );

  is( $cron[13]->{type},                 "job", "the 7th job" );
  is( $cron[13]->{cron}->{minute},       "*",   "the 7th job / min" );
  is( $cron[13]->{cron}->{hour},         "*",   "the 7th job / hour" );
  is( $cron[13]->{cron}->{day_of_month}, "*",   "the 7th job / day" );
  is( $cron[13]->{cron}->{month},        "*",   "the 7th job / month" );
  is( $cron[13]->{cron}->{day_of_week},
    "*", "the 7th job / day_of_month of week" );
  is( $cron[13]->{cron}->{command}, "foo", "the 7th job / cmd" );
  is( $cron[13]->{line}, "* * * * * foo", "the 7th job / cron line" );

  is( $cron[14]->{type},                 "job",   "the 8th job" );
  is( $cron[14]->{cron}->{minute},       "*",     "the 8th job / min" );
  is( $cron[14]->{cron}->{hour},         "5,6,7", "the 8th job / hour" );
  is( $cron[14]->{cron}->{day_of_month}, "*",     "the 8th job / day" );
  is( $cron[14]->{cron}->{month},        "*/2",   "the 8th job / month" );
  is( $cron[14]->{cron}->{day_of_week},
    "*", "the 8th job / day_of_month of week" );
  is( $cron[14]->{cron}->{command}, "bar", "the 8th job / cmd" );
  is( $cron[14]->{line}, "* 5,6,7 * */2 * bar", "the 8th job / cron line" );

  is( $cron[15]->{type},                 "job", "the 9th job" );
  is( $cron[15]->{cron}->{minute},       "0",   "the 9th job / min" );
  is( $cron[15]->{cron}->{hour},         "0",   "the 9th job / hour" );
  is( $cron[15]->{cron}->{day_of_month}, "*",   "the 9th job / day" );
  is( $cron[15]->{cron}->{month},        "*",   "the 9th job / month" );
  is( $cron[15]->{cron}->{day_of_week},
    "0", "the 9th job / day_of_month of week" );
  is( $cron[15]->{cron}->{command}, "false", "the 9th job / cmd" );
  is( $cron[15]->{line}, "0 0 * * 0 false", "the 9th job / cron line" );

  $c->add_env( "FOOVAR" => "FOOVAL", );

  $c->add_env( "BARVAR" => "BARVAL", );

  @cron = $c->list;

  is( $cron[0]->{type},  "env",             "1st line is now env" );
  is( $cron[0]->{name},  "BARVAR",          "1st line / name" );
  is( $cron[0]->{value}, "BARVAL",          "1st line / value" );
  is( $cron[0]->{line},  'BARVAR="BARVAL"', "1st line / value" );

  is( $cron[1]->{type},  "env",             "2nd line is now env" );
  is( $cron[1]->{name},  "FOOVAR",          "2nd line / name" );
  is( $cron[1]->{value}, "FOOVAL",          "2nd line / value" );
  is( $cron[1]->{line},  'FOOVAR="FOOVAL"', "2nd line / value" );

  @cron = $c->list_jobs;

  is( $cron[0]->{minute},       5,      "the first job / min" );
  is( $cron[0]->{hour},         "9-20", "the first job / hour" );
  is( $cron[0]->{day_of_month}, "*",    "the first job / day" );
  is( $cron[0]->{month},        "*",    "the first job / month" );
  is( $cron[0]->{day_of_week},  "*", "the first job / day_of_month of week" );
  is(
    $cron[0]->{command},
    "/home/username/script/script1.sh > /dev/null",
    "the first job / cmd"
  );

  is( $cron[1]->{minute},       "59", "the second job / min" );
  is( $cron[1]->{hour},         "23", "the second job / hour" );
  is( $cron[1]->{day_of_month}, "*",  "the second job / day" );
  is( $cron[1]->{month},        "*",  "the second job / month" );
  is( $cron[1]->{day_of_week}, "0,4", "the second job / day_of_month of week" );
  is(
    $cron[1]->{command},
    "cp /pfad/zu/datei /pfad/zur/kopie",
    "the second job / cmd"
  );

  is( $cron[2]->{minute},       "*", "the third job / min" );
  is( $cron[2]->{hour},         "*", "the third job / hour" );
  is( $cron[2]->{day_of_month}, "*", "the third job / day" );
  is( $cron[2]->{month},        "*", "the third job / month" );
  is( $cron[2]->{day_of_week},  "*", "the third job / day_of_month of week" );
  is(
    $cron[2]->{command},
    'DISPLAY=:0 LANG=de_DE.UTF-8 zenity --info --text "Beispiel für das Starten eines Programmes mit GUI"',
    "the third job / cmd"
  );

  $c->delete_job(1);
  $c->delete_job(0);

  @cron = $c->list;

  is( $cron[0]->{type},  "env",             "1st line is now env" );
  is( $cron[0]->{name},  "BARVAR",          "1st line / name" );
  is( $cron[0]->{value}, "BARVAL",          "1st line / value" );
  is( $cron[0]->{line},  'BARVAR="BARVAL"', "1st line / value" );

  is( $cron[1]->{type},  "env",             "2nd line is now env" );
  is( $cron[1]->{name},  "FOOVAR",          "2nd line / name" );
  is( $cron[1]->{value}, "FOOVAL",          "2nd line / value" );
  is( $cron[1]->{line},  'FOOVAR="FOOVAL"', "2nd line / value" );

  @cron = $c->list_jobs;

  is( $cron[0]->{minute},       "*", "the third job / min" );
  is( $cron[0]->{hour},         "*", "the third job / hour" );
  is( $cron[0]->{day_of_month}, "*", "the third job / day" );
  is( $cron[0]->{month},        "*", "the third job / month" );
  is( $cron[0]->{day_of_week},  "*", "the third job / day_of_month of week" );
  is(
    $cron[0]->{command},
    'DISPLAY=:0 LANG=de_DE.UTF-8 zenity --info --text "Beispiel für das Starten eines Programmes mit GUI"',
    "the third job / cmd"
  );

  @cron = $c->list_envs;

  is( $cron[0]->{name},  "BARVAR",          "1st env name" );
  is( $cron[0]->{value}, "BARVAL",          "1st env name" );
  is( $cron[0]->{line},  'BARVAR="BARVAL"', "1st env name" );

  is( $cron[1]->{name},  "FOOVAR",          "2nd env name" );
  is( $cron[1]->{value}, "FOOVAL",          "2nd env name" );
  is( $cron[1]->{line},  'FOOVAR="FOOVAL"', "2nd env name" );

  is( $cron[2]->{name},  "SHELL",           "3rd env name" );
  is( $cron[2]->{value}, "/bin/bash",       "3rd env name" );
  is( $cron[2]->{line},  'SHELL=/bin/bash', "3rd env name" );

  $c->delete_env(1);
  $c->delete_env(0);

  @cron = $c->list_envs;

  is( $cron[0]->{name},  "SHELL",           "3rd env name" );
  is( $cron[0]->{value}, "/bin/bash",       "3rd env name" );
  is( $cron[0]->{line},  'SHELL=/bin/bash', "3rd env name" );
}

