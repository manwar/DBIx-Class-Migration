package DBIx::Class::Migration::Population;

use Moose;
use File::Spec::Functions 'catdir', 'catfile';
use File::ShareDir::ProjectDistDir ();
use MooseX::Types::LoadableClass 'LoadableClass';
use Class::Load 'load_class';

has schema_class => (
  is => 'ro',
  predicate=>'has_schema_class',
  required=>0,
  isa => LoadableClass,
  coerce=>1);

has schema_args => (is=>'ro', isa=>'ArrayRef', lazy_build=>1);

  sub _generate_filename_for_default_db {
    my ($schema_class) = @_;
    $schema_class =~ s/::/-/g;
    return lc($schema_class);
  }

  sub _generate_dsn {
    my ($schema_class, $target_dir) = @_;
    my $filename = _generate_filename_for_default_db($schema_class);
    'DBI:SQLite:'. catfile($target_dir, "$filename.db");
  }

  sub _build_schema_args {
    my $self = shift;
    [ _generate_dsn($self->schema_class, $self->target_dir), '', '' ];
  }

has schema => (is=>'ro', lazy_build=>1, predicate=>'has_schema');

  sub _build_schema {
    my ($self) = @_;
    $self->schema_class->connect(@{$self->schema_args});
  }

has target_dir => (is=>'ro', lazy_build=>1);

  sub _build_target_dir {
    my $self = shift;
    my $class = $self->has_schema_class ?
      $self->schema_class : ref($self->schema);

    my $file_name = $class;
    $file_name =~s/::/\//g;

    File::ShareDir::ProjectDistDir->import('dist_dir',
      filename => $INC{$file_name.".pm"});

    $class =~s/::/-/g;
    my $target_dir = dist_dir($class);
    return $target_dir;
  }

has dbic_fixture_class => (
  is => 'ro',
  default => 'DBIx::Class::Fixtures',
  isa => LoadableClass,
  coerce=>1);

sub _prepare_fixture_conf_dir {
  my ($dir, $version) = @_;
  my $fixture_conf_dir = catdir($dir, 'fixtures', $version, 'conf');
  return $fixture_conf_dir;
}

sub _prepare_fixture_data_dir {
  my ($dir, $version, $set) = @_;
  my $fixture_conf_dir = catdir($dir, 'fixtures', $version, $set);
  return $fixture_conf_dir;
}

sub build_dbic_fixtures {
    my $self = shift;
    my $dbic_fixtures = $self->dbic_fixture_class;
    my $conf_dir = _prepare_fixture_conf_dir($self->target_dir,
      $self->schema->schema_version);

    $dbic_fixtures->new({
      config_dir => $conf_dir});
}

sub populate {
  my $self = shift;
  my $version_to_populate = $self->schema->schema_version;

  foreach my $set(@_) {
    my $target_dir = _prepare_fixture_data_dir($self->target_dir,
      $version_to_populate, $set);

    $self->build_dbic_fixtures->populate({
      no_deploy => 1,
      schema => $self->schema,
      directory => $target_dir,
    });

    print "Restored set $set to database\n";
  }
}

__PACKAGE__->meta->make_immutable;

=head1 NAME

DBIx::Class::Migration::Population - Utility to populate fixture data

=head1 SYNOPSIS

  use DBIx::Class::Migration::Population;
  use MyApp::Schema;

  $schema = MyApp::Schema->connect(...);
  (my $population = DBIx::Class::Migration::Population->new(
    schema=>$schema))->populate('all_tables');

=head1 DESCRIPTION

Sometimes you just need to populate data for your scripts, such as during
testing and you don't want to expose a full migrations interface and let
someone accidently wipe your database with one command.  This utility is
designed to assist.  It is basically a thin wrapper on L<DBIx::Class::Fixtures>
that is just aware of L<DBIx::Class::Migrations> conventions.

You create an instance of this similarly to L<DBIx::Class::Migrations>, except
you can't pass any arguments related to L<DBIx::Class::DeploymentHandler> since
you don't have one :).  You can create it from an existing schema, or build it
from a schema_class and schema_args, and optional set a target directory (or
just let it use the default distribution share directory).  Afterwards we
expose a C<populate> method that takes a list of fixture set names.

You don't have any control over which version we are trying to populate, we
always use the declared schema Version.  We assume you have an existing
deployed database that matches the current schema.

=head1 AUTHOR

John Napiorkowski L<email:jjnapiork@cpan.org>

=head1 SEE ALSO

L<DBIx::Class::Migration>.

=head1 COPYRIGHT & LICENSE

Copyright 2012, John Napiorkowski L<email:jjnapiork@cpan.org>

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut