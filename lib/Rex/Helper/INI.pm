#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Helper::INI;

use strict;
use warnings;

use String::Escape 'string2hash';


sub parse {
   my (@lines) = @_;
   my $ini;

   my $section;
   for (@lines) {
      chomp;
      s/\n|\r//g;

      (/^#|^;|^\s*$/) && (next);

      if(/^\[(.*)\]/) {
         # check for inheritance
         $section = $1;
         $ini->{$section} = {};

         if($section =~ /</) {
            delete $ini->{$section};
            my @inherit = split(/</, $section);
            s/^\s*|\s*$//g for @inherit;
            $section = shift @inherit;

            for my $is (@inherit) {
               for my $ik (keys %{ $ini->{$is} }) {
                  $ini->{$section}->{$ik} = $ini->{$is}->{$ik};
               }
            }
         }

         next;
      }

      my ($key, $val) = split(/[= ]/, $_, 2);
      $key =~ s/^\s*|\s*$//g if $key;
      $val =~ s/^\s*|\s*$//g if $val;


      my @splitted;
      if(! $val) {
         $val = $key;
         @splitted = ($key);
      }
      else {
         @splitted = split(/\./, $key);
      }

      my $ref = $ini->{$section};
      my $last = pop @splitted;
      for my $sub (@splitted) {

         unless(exists $ini->{$section}->{$sub}) {
            $ini->{$section}->{$sub} = {};
         }

         $ref = $ini->{$section}->{$sub};
      }

      # include other group
      if($key =~ m/^\@(.*)/) {
         for my $ik (keys %{ $ini->{$1} }) {
            $ini->{$section}->{$ik} = $ini->{$1}->{$ik};
         }
         next;
      }

      if($val =~ m/\$\{(.*)\}/) {
         my $var_name = $1;
         my $ref = $ini;
         my @splitted = split(/\./, $var_name);
         for my $s (@splitted) {
            $ref = $ref->{$s};
         }

         $val = $ref;
      }

      if($val =~ m/=/) {
         $val = { string2hash($val) };
      }

      $ref->{$last} = $val;

   }

   return $ini;
}

1;
