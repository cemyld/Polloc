=head1 NAME

Polloc::Feature::generic - An unknown feature

=head1 DESCRIPTION

A feature loaded by some external source, but not directly created by
some L<Polloc::RuleI> object.  Implements L<Polloc::FeatureI>.

=head1 AUTHOR - Luis M. Rodriguez-R

Email lmrodriguezr at gmail dot com

=cut

package Polloc::Feature::generic;

use strict;
use base qw(Polloc::FeatureI);


=head1 APPENDIX

 Methods provided by the package

=head2 new

 Description	: Creates a B<Polloc::Feature::repeat> object
 Arguments	: none
 Returns	: A B<Polloc::Feature::generic> object

=cut

sub new {
   my($caller,@args) = @_;
   my $self = $caller->SUPER::new(@args);
   $self->_initialize(@args);
   return $self;
}

=head2 _initialize

 Description	: Initialization function.
 Arguments	: none
 Returns	: none

=cut

sub _initialize {
   # my($self,@args) = @_;
   # Do nothing ;-), just to avoid the unimplemented error.
}

1;