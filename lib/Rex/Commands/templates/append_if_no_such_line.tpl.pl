#!/usr/bin/perl

# unlink myself
#unlink $0;

open (my $in, "<%= $file %>") || exit(1);
my $found=0;
while(<$in>) {
      chomp;
      <% for my $r (@{ $regex }) { %>
        if ("<%= $r %>") {
            (/<%= $r %>/) && ($found=1);
         }
         if ("<%= $line %>") {
            ($_ eq "<%= $line %>") && ($found=1);
         }
      <% } %>
}
close $in;
if (!$found) {
   open (my $out, ">><%= $file %>") || exit(3);
   print $out "<%= $line %>\n";
   close $out;
}
