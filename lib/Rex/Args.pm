#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Args;
   
use strict;
use warnings;

use vars qw(%task_opts %rex_opts);
use Rex::Logger;
use Data::Dumper;

sub import {
   my ($class, %args) = @_;

   #### clean up @ARGV
   my $runner = 0;
   for (@ARGV) {
      if(/^\-[A-Za-z]+/ && length($_) > 2) {
         my @args = map { "-$_" } split(//, substr($_, 1));
         splice(@ARGV, $runner, 1, @args);
      }

      $runner++
   }

   #### parse rex options
   my @params = @ARGV;
   for my $p (@params) {
      # shift off @ARGV
      my $shift = shift @ARGV;

      if(length($p) >= 2 && substr($p, 0, 1) eq "-") {
         my $name_param = substr($p, 1, 2);
         # found a parameter

         if(exists $args{$name_param}) {
            Rex::Logger::debug("Option found: $name_param ($p)");
            my $type = "Single";

            if(exists $args{$name_param}->{type}) {
               $type = $args{$name_param}->{type};

               Rex::Logger::debug("   is a $type");
               shift @params; # remove the next parameter, because it must be an option

               if(! exists $ARGV[0] || ( length($ARGV[0]) == 2 && exists $args{substr($ARGV[0], 1, 2)} && substr($ARGV[0], 0, 1) eq "-" )) {
                  # this is a typed parameter without an option!
                  Rex::Logger::debug("   but there is no parameter");
                  Rex::Logger::debug(Dumper(\@params));
                  print("No parameter for $name_param\n");
                  CORE::exit 1;
               }
            }
            elsif(exists $args{$name_param}->{func}) {
               Rex::Logger::debug("   is a function - executing now");
               $args{$name_param}->{func}->();
            }

            my $c = "Rex::Args::\u$type";
            eval "use $c";
            if($@) {
               die("No Argumentclass $type found!");
            }

            if(exists $rex_opts{$name_param} && $type eq "Single") {
               $rex_opts{$name_param}++;
            }
            else {
               $rex_opts{$name_param} = $c->get;
            }
         }
         else {
            Rex::Logger::debug("Option not known: $name_param ($p)");
            next;
         }
      }
      else {
         # unshift the last parameter
         unshift @ARGV, $shift;
         last;
      }
   }
   

   #### parse task options

   @params = @ARGV[1..$#ARGV];

   for my $p (@params) {
      my($key, $val) = split(/=/, $p, 2);
      $key =~ s/^--//;

      if($val) { $task_opts{$key} = $val; next; }
      $task_opts{$key} = 1;
   }

}

sub getopts { return %rex_opts; }

sub is_opt {
   my ($class, $opt) = @_;
   if(exists $rex_opts{$opt}) {
      return $rex_opts{$opt};
   }
}

sub get { return %task_opts; }

1;
