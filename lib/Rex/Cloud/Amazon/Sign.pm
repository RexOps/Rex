package Rex::Cloud::Amazon::Sign;

use strict;
use POSIX 'strftime';
use URI;
use URI::QueryParam;
use URI::Escape;
use Digest::SHA 'sha256_hex','hmac_sha256','hmac_sha256_hex';
use Date::Parse;
use Carp 'croak';

# VERSION

our $ORIG_VERSION = '1.02';

=head1 NAME

Rex::Cloud::Amazon:Sign - Create a version4 signature for Amazon Web Services

Bold copied from AWS::Signature4 - because of CentOS 5 dependencies.

=cut

sub new {
    my $self = shift;
    my %args = @_;

    my ($id,$secret,$token);
    if (ref $args{-security_token} && $args{-security_token}->can('access_key_id')) {
	$id     = $args{-security_token}->accessKeyId;
	$secret = $args{-security_token}->secretAccessKey;
    }

    $id           ||= $args{-access_key} || $ENV{EC2_ACCESS_KEY}
                      or croak "Please provide -access_key parameter or define environment variable EC2_ACCESS_KEY";
    $secret       ||= $args{-secret_key} || $ENV{EC2_SECRET_KEY}
                      or croak "Please provide -secret_key or define environment variable EC2_SECRET_KEY";

    return bless {
	access_key => $id,
	secret_key => $secret,
       (defined($args{-security_token}) ? (security_token => $args{-security_token}) : ()),
    },ref $self || $self;
}

sub access_key { shift->{access_key } } 
sub secret_key { shift->{secret_key } }


sub sign {
    my $self = shift;
    my ($request,$region,$payload_sha256_hex) = @_;
    $self->_add_date_header($request);
    $self->_sign($request,$region,$payload_sha256_hex);
}


sub signed_url {
    my $self    = shift;
    my ($arg1,$expires) = @_;
    
    my ($request,$uri);

    if (ref $arg1 && UNIVERSAL::isa($arg1,'HTTP::Request')) {
	$request = $arg1;
	$uri = $request->uri;
	my $content = $request->content;
	$uri->query($content) if $content;
	if (my $date = $request->header('X-Amz-Date') || $request->header('Date')) {
	    $uri->query_param('Date'=>$date);
	}
    }

    $uri ||= URI->new($arg1);
    my $date = $uri->query_param_delete('Date') || $uri->query_param_delete('X-Amz-Date');
    $request = HTTP::Request->new(GET=>$uri);
    $request->header('Date'=> $date);
    $uri = $request->uri;  # because HTTP::Request->new() copies the uri!

    return $uri if $uri->query_param('X-Amz-Signature');


    my $scope = $self->_scope($request);

    $uri->query_param('X-Amz-Algorithm'  => $self->_algorithm);
    $uri->query_param('X-Amz-Credential' => $self->access_key . '/' . $scope);
    $uri->query_param('X-Amz-Date'       => $self->_datetime($request));
    $uri->query_param('X-Amz-Expires'    => $expires) if $expires;
    $uri->query_param('X-Amz-SignedHeaders' => 'host');

    # If there was a security token passed, we need to supply it as part of the authorization
    # because AWS requires it to validate IAM Role temporary credentials.

    if (defined($self->{security_token})) {
        $uri->query_param('X-Amz-Security-Token' => $self->{security_token});
    }

    # Since we're providing auth via query parameters, we need to include UNSIGNED-PAYLOAD
    # http://docs.aws.amazon.com/AmazonS3/latest/API/sigv4-query-string-auth.html
    # it seems to only be needed for S3.

    if ($scope =~ /\/s3\/aws4_request$/) {
        $self->_sign($request, undef, 'UNSIGNED-PAYLOAD');
    } else {
        $self->_sign($request);
    }

    my ($algorithm,$credential,$signedheaders,$signature) =
	$request->header('Authorization') =~ /^(\S+) Credential=(\S+), SignedHeaders=(\S+), Signature=(\S+)/;
    $uri->query_param_append('X-Amz-Signature'     => $signature);
    return $uri;
}


sub _add_date_header {
    my $self = shift;
    my $request = shift;
    my $datetime;
    unless ($datetime = $request->header('x-amz-date')) {
	$datetime    = $self->_zulu_time($request);
	$request->header('x-amz-date'=>$datetime);
    }
}

sub _scope {
    my $self    = shift;
    my ($request,$region) = @_;
    my $host     = $request->uri->host;
    my $datetime = $self->_datetime($request);
    my ($date)   = $datetime =~ /^(\d+)T/;
    my $service;
    if ($host =~ /^([\w.-]+)\.s3\.amazonaws.com/) { # S3 bucket virtual host
	$service = 's3';
	$region  ||= 'us-east-1';
    } elsif  ($host =~ /^[\w-]+\.s3-([\w-]+)\.amazonaws\.com/) {
	$service = 's3';
	$region  ||= $2;
    } elsif ($host =~ /^(\w+)[-.]([\w-]+)\.amazonaws\.com/) {
	$service  = $1;
	$region ||= $2;
    } elsif ($host =~ /^([\w-]+)\.amazonaws\.com/) {
	$service = $1;
	$region  = 'us-east-1';
    }
    $service ||= 's3';
    $region  ||= 'us-east-1';  # default
    return "$date/$region/$service/aws4_request";
}

sub _parse_scope {
    my $self = shift;
    my $scope = shift;
    return split '/',$scope;
}

sub _datetime {
    my $self = shift;
    my $request = shift;
    return $request->header('x-amz-date') || $self->_zulu_time($request);
}

sub _algorithm { return 'AWS4-HMAC-SHA256' }

sub _sign {
    my $self    = shift;
    my ($request,$region,$payload_sha256_hex) = @_;
    return if $request->header('Authorization'); # don't overwrite

    my $datetime = $self->_datetime($request);

    unless ($request->header('host')) {
	my $host        = $request->uri->host;
	$request->header(host=>$host);
    }

    my $scope      = $self->_scope($request,$region);
    my ($date,$service);
    ($date,$region,$service) = $self->_parse_scope($scope);

    my $secret_key = $self->secret_key;
    my $access_key = $self->access_key;
    my $algorithm  = $self->_algorithm;

    my ($hashed_request,$signed_headers) = $self->_hash_canonical_request($request,$payload_sha256_hex);
    my $string_to_sign                   = $self->_string_to_sign($datetime,$scope,$hashed_request);
    my $signature                        = $self->_calculate_signature($secret_key,$service,$region,$date,$string_to_sign);
    $request->header(Authorization => "$algorithm Credential=$access_key/$scope, SignedHeaders=$signed_headers, Signature=$signature");
}

sub _zulu_time { 
    my $self = shift;
    my $request = shift;
    my $date     = $request->header('Date');
    my @datetime = $date ? gmtime(str2time($date)) : gmtime();
    return strftime('%Y%m%dT%H%M%SZ',@datetime);
}

sub _hash_canonical_request {
    my $self = shift;
    my ($request,$hashed_payload) = @_; # (HTTP::Request,sha256_hex($content))
    my $method           = $request->method;
    my $uri              = $request->uri;
    my $path             = $uri->path || '/';
    my @params           = $uri->query_form;
    my $headers          = $request->headers;
    $hashed_payload    ||= sha256_hex($request->content);

    # canonicalize query string
    my %canonical;
    while (my ($key,$value) = splice(@params,0,2)) {
	$key   = uri_escape($key);
	$value = uri_escape($value);
	push @{$canonical{$key}},$value;
    }
    my $canonical_query_string = join '&',map {my $key = $_; map {"$key=$_"} sort @{$canonical{$key}}} sort keys %canonical;

    # canonicalize the request headers
    my (@canonical,%signed_fields);
    for my $header (sort map {lc} $headers->header_field_names) {
	next if $header =~ /^date$/i;
	my @values = $headers->header($header);
	# remove redundant whitespace
	foreach (@values ) {
	    next if /^".+"$/;
	    s/^\s+//;
	    s/\s+$//;
	    s/(\s)\s+/$1/g;
	}
	push @canonical,"$header:".join(',',@values);
	$signed_fields{$header}++;
    }
    my $canonical_headers = join "\n",@canonical;
    $canonical_headers   .= "\n";
    my $signed_headers    = join ';',sort map {lc} keys %signed_fields;

    my $canonical_request = join("\n",$method,$path,$canonical_query_string,
				 $canonical_headers,$signed_headers,$hashed_payload);
    my $request_digest    = sha256_hex($canonical_request);
    
    return ($request_digest,$signed_headers);
}

sub _string_to_sign {
    my $self = shift;
    my ($datetime,$credential_scope,$hashed_request) = @_;
    return join("\n",'AWS4-HMAC-SHA256',$datetime,$credential_scope,$hashed_request);
}



sub signing_key {
    my $self = shift;
    my ($kSecret,$service,$region,$date) = @_;
    my $kDate    = hmac_sha256($date,'AWS4'.$kSecret);
    my $kRegion  = hmac_sha256($region,$kDate);
    my $kService = hmac_sha256($service,$kRegion);
    my $kSigning = hmac_sha256('aws4_request',$kService);
    return $kSigning;
}

sub _calculate_signature {
    my $self = shift;
    my ($kSecret,$service,$region,$date,$string_to_sign) = @_;
    my $kSigning = $self->signing_key($kSecret,$service,$region,$date);
    return hmac_sha256_hex($string_to_sign,$kSigning);
}

1;


=head1 AUTHOR

Lincoln Stein E<lt>lincoln.stein@gmail.comE<gt>.

Copyright (c) 2014 Ontario Institute for Cancer Research

This package and its accompanying libraries is free software; you can
redistribute it and/or modify it under the terms of the GPL (either
version 1, or at your option, any later version) or the Artistic
License 2.0.  Refer to LICENSE for the full license text. In addition,
please see DISCLAIMER.txt for disclaimers of warranty.

=cut



