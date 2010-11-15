use ExtUtils::MakeMaker;

WriteMakefile(
   NAME => 'Rex',
   VERSION_FROM => 'lib/Rex.pm',
   PREREQ_PM => {'Scope::With' => '0.01', 'Net::SSH::Expect' => '1.09', 'Net::SCP::Expect' => '0.16'},
   EXE_FILES => ['bin/rex'],
   LICENSE => 'perl'
);

