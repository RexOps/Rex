use ExtUtils::MakeMaker;

WriteMakefile(
   NAME => 'Rex',
   VERSION_FROM => 'lib/Rex.pm',
   PREREQ_PM => {'Scope::With' => '0.01'},
   EXE_FILES => ['bin/rex']
);

