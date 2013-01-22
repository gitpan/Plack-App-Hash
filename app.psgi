#!/usr/bin/env perl
use strict;
use warnings;

use Encode ();
use Time::Zone ();
use HTTP::Date qw( str2time time2isoz );
use URI::Find ();
use HTTP::Tiny ();
use CGI qw( feed icon author name link id entry content updated escapeHTML );
use Plack::App::Hash ();
use Array::RefElem ();

sub MIRROR_URL() { 'http://slackware.osuosl.org/slackware-current/' }

my @entry = do {
	my $res = HTTP::Tiny->new->get( MIRROR_URL . 'ChangeLog.txt' );
	die "Failed to download ChangeLog\n" unless $res->{'success'};
	split /\n\+----+\+\n/, Encode::decode 'ISO-8859-1', $res->{'content'};
};

sub time2rfc3339 { local $_ = time2isoz shift; tr/ /T/; $_ }

my $q = CGI->new( '' );

sub page { join "\n", (
	'<!doctype html>',
	$q->title( $_[0] ),
	$q->style( <<'END_CSS' ),
body { width: 45em; margin: 1em auto; font-family: sans-serif }
h2 { margin: 1em 0 0 }
h1 + div { margin-top: -1.5em }
div.meta { font-size: 0.8em }
div.nav { position: relative; height: 1em }
div.nav a { position: absolute }
a.prev { left: 0 }
a.next { right: 0 }
a.home { left: 50%; margin-left: -1.5em }
END_CSS
	$q->link( { rel => 'alternate', type => 'application/atom+xml', href => '/feed' } ),
	$q->start_body,
	'<!--nav-->',
	$q->h1( $_[0] ),
	@_[1 .. $#_],
) }

my ( %content, @post, @index ) = ( feed => join "\n", (
	$q->start_feed( { xmlns => 'http://www.w3.org/2005/Atom' } ),
	$q->id( 'urn:uuid:6195b930-844b-11da-9fcb-dd680b0526e0' ),
	$q->title( 'Slackware-current ChangeLog' ),
	$q->icon( 'http://www.slackware.com/favicon.ico' ),
	$q->author( $q->name( 'Patrick Volkerding' ) ),
	$q->link( { href => '/' } ),
	$q->updated( time2rfc3339 time ),
) );

my %is_category;
@is_category{ qw( a ap d e f k kde kdei l n t tcl x xap xfce y ) } = (1) x 100;

my $urifinder = URI::Find->new( sub { $q->a( { href => $_[0] }, escapeHTML $_[1] ) } );

for ( @entry ) {
	m{ \A ( [^\n]+ ) \n* ( .* ) }msx or next;

	my $time = str2time $1; # needs Time::Zone!!
	my $text = $2;

	1 while chomp $text;

	$urifinder->find( \$text, \&escapeHTML );

	my $num_pkg = $text =~ s{^(([\w\-]+)/\S+)(?=:  )}{
		my $path = $is_category{ $2 } ? 'slackware/' . $1 : $1;
		chop $path if '*' eq substr $path, -1;
		$q->a( { href => MIRROR_URL . $path }, $1 );
	}gme;

	my ( $excerpt ) = $text =~ /\A([^<].*)/;
	my $alt_title = "$num_pkg package" . ( 1 != $num_pkg ? 's' : '' );
	my $title = $excerpt // $alt_title;

	my $body = $q->pre( $text );

	my $humantime = gmtime $time;

	$content{ $time } = page $humantime, ( $q->h3( $alt_title ) ) x!! $num_pkg, $body;

	$content{'feed'} .= "\n" . $q->entry(
		$q->id( 'tag:plasmasturm.org,2005:Scraped-Feed:Slackware-ChangeLog:' . $time ),
		$q->title( $title ), "\n",
		$q->link( { href => $time } ), "\n",
		$q->content(
			{ type => 'xhtml' },
			$q->div( { xmlns => 'http://www.w3.org/1999/xhtml' }, $body ),
		), "\n",
		$q->updated( time2rfc3339 $time ),
	);

	push @post, $q->h2( $q->a( { href => $time }, $title ) )
		. $q->div( { class => 'meta' }, $humantime )
		. ( @post < 3 ? $body : '' );

	push @index, $time;
}

{
	my ( undef, %prev ) = ( (         map { ($_) x 2 } @index ), undef );
	my ( undef, %next ) = ( ( reverse map { ($_) x 2 } @index ), undef );
	for my $key ( keys %content ) {
		my $prev = $prev{ $key };
		my $next = $next{ $key };
		$content{ $key } =~ s{<!--nav-->}{ $q->div(
			{ class => 'nav' },
			( $q->a( { class => 'prev', href => $prev }, '&#x2190; Prev' ) ) x!! $prev,
			  $q->a( { class => 'home', href => '/'   }, 'Home' ),
			( $q->a( { class => 'next', href => $next }, 'Next &#x2192;' ) ) x!! $next,
		) }e;
	}
}

$content{'feed'} .= "\n" . $q->end_feed;

$content{''} = page(
	'Slackware-current ChangeLog',
	$q->div( { class => 'meta' }, $q->a( { type => 'application/atom+xml', href => '/feed' }, 'Feed' ) ),
	@post,
);

$_ = Encode::encode_utf8 $_ for values %content;

Plack::App::Hash->new(
	content => \%content,
	headers => { feed => [ qw( Content-Type application/atom+xml ) ] },
	default_type => 'text/html',
)->to_app;
