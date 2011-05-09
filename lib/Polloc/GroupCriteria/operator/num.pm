=head1 NAME

Polloc::GroupCriteria::operator::num - A numeric operator

=head1 AUTHOR - Luis M. Rodriguez-R

Email lmrodriguezr at gmail dot com

=cut

package Polloc::GroupCriteria::operator::num;

use strict;
use base qw(Polloc::GroupCriteria::operator);


=head1 APPENDIX

Methods provided by the package

=head2 new

Generic initialization method.

=head3 Arguments

See L<Polloc::GroupCriteria::operator->new()>

=head3 Returns

A L<Polloc::GroupCriteria::operator::bool> object.

=cut

sub new {
   my($caller,@args) = @_;
   my $self = $caller->SUPER::new(@args);
   $self->_initialize(@args);
   return $self;
}

=head2 operate

=head3 Returns

A numeric value.

=cut

sub operate {
   my $self = shift;
   return $self->val if defined $self->val;
   $self->throw('Bad operators', $self->operators)
   	unless ref($self->operators)
	and ref($self->operators)=~/ARRAY/;
   my $o1 = $self->operators[0]->operate;
   $self->throw("Undefined first operator") unless defined $o1;
   my $o2 = $self->operators[1]->operate;
   $self->throw("Undefined second operator") unless defined $o2;
   return ($o1 + $o2)	if $self->operation =~ /^\s*(?:\+)\s*$/i;
   return ($o1 - $o2)	if $self->operation =~ /^\s*(?:\-)\s*$/i;
   return ($o1 * $o2)	if $self->operation =~ /^\s*(?:\*)\s*$/i;
   return ($o1 / $o2)	if $self->operation =~ /^\s*(?:\/)\s*$/i;
   return ($o1 % $o2)	if $self->operation =~ /^\s*(?:%)\s*$/i;
   return ($o1 ** $o2)	if $self->operation =~ /^\s*(?:\*\*|\^)\s*$/i;
   if($self->operation =~ /^\s*aln-(sim|score)(?: with)?\s*$/i){
      my $ret = lc $2;
      return unless $self->_load_module('Bio::Tools::Run::Alignment::Muscle');
      my $factory = Bio::Tools::Run::Alignment::Muscle->new();
      $factory->quiet(1);
      $o1->id('op1');
      $o2->id('op2');
      my $aln = $factory->align([$o1, $o2]);
      my $out = 0;
      $out = $aln->overall_percentage_identity('long')/100 if $ret=='sim';
      $out = $aln->score if $ret=='score';
      $factory->cleanup(); # This is to solve the issue #1
      return $out;
   }
   $self->throw("Unknown numeric operation", $self->operation);
}

=head1 INTERNAL METHODS

Methods intended to be used only within the scope of Polloc::*

=head2 _initialize

=cut

sub _initialize { }

1;