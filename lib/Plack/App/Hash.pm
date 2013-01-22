#!/usr/bin/perl
use strict;
use warnings;

# ABSTRACT: Serve up the contents of a hash as a website

package Plack::App::Hash;
{
  $Plack::App::Hash::VERSION = '0.002';
}
use parent 'Plack::Component';

use Plack::Util ();
use Array::RefElem ();
use HTTP::Status ();
#use Digest::SHA;

use Plack::Util::Accessor qw( content headers auto_type default_type );

sub call {
	my $self = shift;
	my $env  = shift;

	my $path = $env->{'PATH_INFO'} || '';
	$path =~ s!\A/!!;

	my $content = $self->content;
	return $self->error( 404 ) unless $content and exists $content->{ $path };
	return $self->error( 500 ) if ref $content->{ $path };

	my $headers = $self->headers;
	my $hdrs = ( $headers and exists $headers->{ $path } ) ? $headers->{ $path } : [];
	if ( not ref $hdrs ) {
		require JSON::XS;
		$hdrs = JSON::XS::decode_json $hdrs;
	}

	{
		my $auto    = $self->auto_type;
		my $default = $self->default_type;
		last unless $auto or $default;
		last if Plack::Util::header_exists $hdrs, 'Content-Type';
		$auto &&= do { require Plack::MIME; Plack::MIME->mime_type( $path ) };
		my $type = $auto || $default;
		Plack::Util::header_push $hdrs, 'Content-Type' => $type if $type;
	}

	if ( not Plack::Util::header_exists $hdrs, 'Content-Length' ) {
		Plack::Util::header_push $hdrs, 'Content-Length' => length $content->{ $path };
	}

	my $body = [];
	Array::RefElem::av_push @$body, $content->{ $path };
	return [ 200, $hdrs, $body ];
}

sub error {
	my $status = pop;
	my $pkg = __PACKAGE__;
	my $body = [ qq(<!doctype html>\n<title>$pkg $status</title><h1><font face=sans-serif>) . HTTP::Status::status_message $status ];
	return [ $status, [
		'Content-Type'   => 'text/html',
		'Content-Length' => length $body->[0],
	], $body ];
}

1;

__END__

=pod

=head1 NAME

Plack::App::Hash - Serve up the contents of a hash as a website

=head1 VERSION

version 0.002

=head1 SYNOPSIS

 use Plack::App::Hash;
 my $app = Plack::App::Hash->new(
     content      => { '' => 'Hello World!' },
     default_type => 'text/plain',
 )->to_app;

=head1 DESCRIPTION

XXX

=head1 CONFIGURATION

=over 4

=item C<content>

XXX

=item C<headers>

XXX JSON

=item C<auto_type>

XXX

=item C<default_type>

XXX

=back

=head1 AUTHOR

Aristotle Pagaltzis <pagaltzis@gmx.de>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by Aristotle Pagaltzis.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
