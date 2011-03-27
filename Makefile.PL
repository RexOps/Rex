use ExtUtils::MakeMaker;

WriteMakefile(
   NAME => 'Rex',
   VERSION_FROM => 'lib/Rex.pm',
   PREREQ_PM => {'Net::SSH2' => '0.33', 'Expect' => 0},
   EXE_FILES => ['bin/rex'],
   LICENSE => 'perl'
);

