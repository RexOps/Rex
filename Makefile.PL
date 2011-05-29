use ExtUtils::MakeMaker;

WriteMakefile(
   NAME => 'Rex',
   VERSION_FROM => 'lib/Rex.pm',
   PREREQ_PM => {'Net::SSH2' => '0.33', 'Expect' => 0, 'DBI' => 0},
   EXE_FILES => ['bin/rex', 'bin/rexify', 'bin/rex-master', 'bin/rex-agent'],
   LICENSE => 'perl'
);

