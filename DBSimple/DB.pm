# Copyright (c) 1996-1997 Hugo van der Sanden. All rights reserved. This 
# program is free software; you can redistribute it and/or modify it under 
# the same terms as Perl itself.

package DBSimple::DB;
use strict;
use Carp qw(confess);
use vars qw($VERSION);

$VERSION = "0.02";

# my $server = '123.45.67.89';		# IP address of a database server
my $local = '';						# localhost

my %types;
my %dbdefs = (
	'test' => [ $local, 'Msql' ],
#	'local_db' => [ $local, 'Msql' ],
#	'local_db2' => [ $local, 'Msql2' ],
#	'remote_db' => [ $server, 'Msql' ],
#	'remote_db2' => [ $server, 'Msql2' ],
);

=head1 NAME

DBSimple::DB - an abstract interface to databases

=head1 SYNOPSIS

	use DBSimple::DB;
	my $dbdef = new DBSimple::DB 'database';
	my $db = $dbdef->open;
	my $table = &tabledef;		# get a DBSimple::Table object
	$table->bind($db);
	return $table->select('user', [ 'hugo', 'hv' ]);

=head1 DESCRIPTION

This is intended to be an abstract interface to databases, such
that you don't need to know irritating details like what sort of
database it is to be able to access it in a perl script.

Currently the only supported database types are Msql versions 1 and
2; the intention is that only this module will need to know where
each database is, and what type it is.

This is an abstract base class: implementation for a specific
database involves writing an additional package that inherits from
C<DBSimple::DB>. If you need to do this, look at C<DBSimple::Msql>
for an example of how to.  In brief though, you need to provide the
constructors and methods described below (for when the object is
treated like a C<DBSimple::DB>), and a load more for a
C<DBSimple::Table> object to access after it has been bound.

Everything is a method - nothing is exported.

=head1 CONSTRUCTOR

=over 4

=item new ( name )

Creates and returns a C<DBSimple::DB> object. Well, it doesn't
actually. What it really does is to look up what sort of database it
is (from this little list it has) and go call the constructor from
the package that handles that sort of database.

=back

=head1 METHODS

=over 4

=item type ( )

Returns a string naming the type of database this object represents.
All derived classes should overload this.

=item open ( )

Opens a connection to the database this object represents. All
derived classes should overload this. 

=back

=head1 FUTURE

Well, implement other database types, I guess.

It would probably be useful to be able to register database names,
locations and types rather than embedding them here, but it is
definitely useful to have those descriptions in a single well known
place.

Please note: I plan to change the interface to this stuff quite a
lot in the near future.

=head1 HISTORY

v0.02 Hugo 29/3/97

	cleaned up some for external release

v0.01 written by Hugo before 15/11/96

=cut

sub new {
	my $proto = shift;
	my $class = ref $proto || $proto;
	my $name = shift;
	confess "Unknown database '$name'" unless defined $dbdefs{$name};
	my($host, $type) = @{$dbdefs{$name}};
	_type($type)->new($host, $name);
}

sub _type {
	my $name = shift;
	unless (defined $types{$name}) {
		my $class = ref(bless {});
		$class =~ s/(.*::).*/$1$name/;
		$types{$name} = bless {}, $class;
		$class =~ s#::#/#g;
		require "$class.pm";
	}
	$types{$name};
}

sub open {
	my $self = shift;
	confess "Don't know how to open database '$self'";
}

1;
