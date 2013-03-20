#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Commands::Sync;

use strict;
use warnings;

require Exporter;
use base qw(Exporter);
use vars qw(@EXPORT);

use Data::Dumper;
use Rex::Commands;
use Rex::Commands::Run;
use Rex::Commands::MD5;
use Rex::Commands::Fs;
use Rex::Commands::File;

@EXPORT = qw(sync_up sync_down);

sub sync_up {
   my ($source, $dest, $options) = @_;

   #
   # first, get all files on source side
   #
   my @dirs = ($source);
   my @local_files = ();

   LOCAL {
      for my $dir (@dirs) {
         for my $entry (list_files($dir)) {
            next if($entry eq ".");
            next if($entry eq "..");
            if(is_dir("$dir/$entry")) {
               push(@dirs, "$dir/$entry");
               next;
            }

            my $name = "$dir/$entry";
            $name =~ s/^\Q$source\E//;
            push(@local_files, {
               name => $name,
               path => "$dir/$entry",
               md5  => md5("$dir/$entry"),
            });

         }
      }
   };

   #print Dumper(\@local_files);

   #
   # second, get all files from destination side
   #

   my @remote_dirs = ($dest);
   my @remote_files = ();

   if(can_run("md5sum")) {
      # if md5sum executable is available
      # copy a script to the remote host so it is fast to scan
      # the directory.

      my $script = q|
use strict;
use warnings;
use Data::Dumper;

unlink $0;

my $dest = $ARGV[0];
my @dirs = ($dest);   
my @tree = ();

for my $dir (@dirs) {
   opendir(my $dh, $dir) or die($!);
   while(my $entry = readdir($dh)) {
      next if($entry eq ".");
      next if($entry eq "..");

      if(-d "$dir/$entry") {
         push(@dirs, "$dir/$entry");
         next;
      }

      my $name = "$dir/$entry";
      $name =~ s/^\Q$dest\E//;

      my $md5 = qx{md5sum $dir/$entry \| awk ' { print \$1 } '};

      chomp $md5;

      push(@tree, {
         path => "$dir/$entry",
         name => $name,
         md5  => $md5,
      });
   }
   closedir($dh);
}

print Dumper(\@tree);
      |;

      my $rnd_file = "/tmp/" . get_random(8, 'a' .. 'z') . ".tmp";
      file $rnd_file, content => $script;
      my $content = run "perl $rnd_file $dest";
      $content =~ s/^\$VAR1 =//;
      my $ref = eval $content;
      @remote_files = @{ $ref };
   }
   else {
      # fallback if no md5sum executable is available
      for my $dir (@remote_dirs) {
         for my $entry (list_files($dir)) {
            next if($entry eq ".");
            next if($entry eq "..");
            if(is_dir("$dir/$entry")) {
               push(@remote_dirs, "$dir/$entry");
               next;
            }

            my $name = "$dir/$entry";
            $name =~ s/^\Q$dest\E//;
            push(@remote_files, {
               name => $name,
               path => "$dir/$entry",
               md5  => md5("$dir/$entry"),
            });
         }
      }
   }

   #print Dumper(\@remote_files);

   #
   # third, get the difference
   #

   my @diff;

   for my $local_file (@local_files) {
      my @data = grep { ($_->{name} eq $local_file->{name}) && ($_->{md5} eq $local_file->{md5}) } @remote_files;
      if(scalar @data == 0) {
         push(@diff, $local_file);
      }
   }

   #print Dumper(\@diff);

   #
   # fourth, upload the different files
   #

   for my $file (@diff) {
      my ($dir)        = ($file->{path} =~ m/(.*)\/[^\/]+$/);
      my ($remote_dir) = ($file->{name} =~ m/\/(.*)\/[^\/]+$/);

      my (%dir_stat, %file_stat);
      LOCAL {
         %dir_stat  = stat($dir);
         %file_stat = stat($file->{path});
      };

      if($remote_dir) {
         mkdir "$dest/$remote_dir",
            mode  => $dir_stat{mode};
      }

      file "$dest/" . $file->{name},
         source => $file->{path},
         mode   => $file_stat{mode};
   }

}

sub sync_down {
   my ($source, $dest, $options) = @_;
}

1;
