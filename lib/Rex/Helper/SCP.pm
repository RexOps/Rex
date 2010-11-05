#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Helper::SCP;

use strict;
use warnings;

use Net::SCP::Expect;
use Carp;

use base qw(Net::SCP::Expect);

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = $proto->SUPER::new(@_);

   bless($self, $proto);

   return $self;
}

sub scp{

   my($self,$from,$to) = @_;

   my $login        = $self->_get('user');
   my $password     = $self->_get('password');
   my $timeout      = $self->_get('timeout');
   my $timeout_auto = $self->_get('timeout_auto');
   my $timeout_err  = $self->_get('timeout_err');
   my $cipher       = $self->_get('cipher');
   my $port         = $self->_get('port');
   my $recursive    = $self->_get('recursive');
   my $verbose      = $self->_get('verbose');
   my $preserve     = $self->_get('preserve');
   my $handler      = $self->_get('error_handler');
   my $auto_yes     = $self->_get('auto_yes');
   my $no_check     = $self->_get('no_check');
   my $terminator   = $self->_get('terminator');
   my $protocol     = $self->_get('protocol');
   my $identity_file = $self->_get('identity_file');
   my $option        = $self->_get('option');
   my $subsystem     = $self->_get('subsystem');
   my $scp_path      = $self->_get('scp_path');
   my $auto_quote    = $self->_get('auto_quote');
   my $compress      = $self->_get('compress');
   my $force_ipv4    = $self->_get('force_ipv4');
   my $force_ipv6    = $self->_get('force_ipv6');
 
   ##################################################################
   # If the second argument is not provided, the remote file will be
   # given the same (base) name as the local file (or vice-versa).
   ##################################################################
   unless($to){
      $to = basename($from);
   }  

   my($host,$dest);

   # Parse the to/from string. If the $from contains a ':', assume it is a Remote to Local transfer
   if($from =~ /:/){
      ($login,$host,$dest) = $self->_parse_scp_string($from);
      $from = $login . '@' . $self->_format_host_string($host) . ':';
      $from .= "$dest" if $dest;
   }
   else{ # Local to Remote transfer
      ($login,$host,$dest) = $self->_parse_scp_string($to);
      $to = $login . '@' . $self->_format_host_string($host) . ':';
      $to .= "$dest" if $dest;
   }

   croak("No login. Can't scp") unless $login;
   #croak("No password or identity file. Can't scp") unless $password || $identity_file;
   croak("No host specified. Can't scp") unless $host;

   # Define argument auto-quote
   my $qt = $auto_quote ? '\'' : '';

   # Gather flags.
   my $flags;

   $flags .= "-c $qt$cipher$qt " if $cipher;
   $flags .= "-P $qt$port$qt " if $port;
   $flags .= "-r " if $recursive;
   $flags .= "-v " if $verbose;
   $flags .= "-p " if $preserve;
   $flags .= "-$qt$protocol$qt " if $protocol;
   $flags .= "-q ";  # Always pass this option (no progress meter)
   $flags .= "-s $qt$subsystem$qt " if $subsystem;
   $flags .= "-o $qt$option$qt " if $option;
   $flags .= "-i $qt$identity_file$qt " if $identity_file;
   $flags .= "-C " if $compress;
   $flags .= "-4 " if $force_ipv4;
   $flags .= "-6 " if $force_ipv6;

   my $scp = Expect->new;
   #if($verbose){ $scp->raw_pty(1) }
   #$scp->debug(1);

   # Use scp specified by the user, if possible
   $scp_path = defined $scp_path ? "$qt$scp_path$qt" : "scp ";

   # Escape quotes
   if ($auto_quote) {
      $from =~ s/'/'"'"'/go;
      $to =~ s/'/'"'"'/go;
   }

   my $scp_string = "$scp_path $flags $qt$from$qt $qt$to$qt";
   $scp = Expect->spawn($scp_string);
   
   unless ($scp) {
      if($handler){ $handler->($!); return; }
      else { croak("Couldn't start program: $!"); }
   }

   $scp->log_stdout(0);

   if($auto_yes){
      while($scp->expect($timeout_auto,-re=>'[Yy]es\/[Nn]o')){
         $scp->send("yes\n");
      }
   }

   if ($password) {
      unless($scp->expect($timeout,-re=>'[Pp]assword.*?:|[Pp]assphrase.*?:')){
         my $err = $scp->before() || $scp->match();
         if($err){
            if($handler){ $handler->($err); return; }
            else { croak("Problem performing scp: $err"); }
         }
         $err = "scp timed out while trying to connect to $host";
         if($handler){ $handler->($err); return; }
         else{ croak($err) };
      }

      if($verbose){ print $scp->before() }

      $password .= $terminator if $terminator;
      $scp->send($password);
   }

   ################################################################
   # Check to see if we sent the correct password, or if we got
   # some other bizarre error.  Anything passed back to the
   # terminal at this point means that something went wrong.
   #
   # The exception to this is verbose output, which can mistakenly
   # be picked up by Expect.
   ################################################################
   my $error;
   my $eof = 0;
   unless($no_check || $verbose){

      $error = ($scp->expect($timeout_err,
         [qr/[Pp]ass.*/ => sub{
               my $error = $scp->before() || $scp->match();
               if($handler){
                  $handler->($error);
                  return;
               }
               else{
                  croak("Error: Bad password [$error]");
               }
            }
         ],
         [qr/\w+.*/ => sub{
               my $error = $scp->match() || $scp->before();
               if($handler){
                  $handler->($error);
                  return;
               }
               else{
                  croak("Error: last line returned was: $error");
               }
            }
         ],
         ['eof' => sub{ $eof = 1 } ],
      ))[1];
   }
   else{
      $error = ($scp->expect($timeout_err, ['eof' => sub { $eof = 1 }]))[1];
   }

   if($verbose){ print $scp->after(),"\n" }

   # Ignore error if it was due to scp auto-exiting successfully (which may trigger false positives on some platforms)
   if ($error && !($eof && $error =~ m/^(2|3)/o)) {
      if ($handler) {
         $handler->($error);
         return;
      }
      else {
         croak("scp processing error occured: $error");
      }
   }
   
   # Insure we check exit state of process
   $scp->hard_close();

   if ($scp->exitstatus > 0) {   #ignore -1, in case there's a waitpid portability issue
      if ($handler) {
         $handler->($scp->exitstatus);
         return;
      }
      else {
         croak("scp exited with non-success state: " . $scp->exitstatus);
      }
   }

   return 1;
}

sub xlogin{
   my($self,$user,$password) = @_;
   
   croak("No user supplied to 'login()' method") unless defined $user;
#   croak("No password supplied to 'login()' method") if @_ > 2 && !defined $password;

   $self->_set('user',$user);
   $self->_set('password',$password) if($password);
}


1;
