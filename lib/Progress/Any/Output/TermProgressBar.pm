package Progress::Any::Output::TermProgressBar;

use 5.010;
use strict;
use warnings;

# VERSION

# TODO: allow customizing Term::ProgressBar

sub new {
    my ($class, %args) = @_;
    bless \%args, $class;
}

sub _tpb {
    require Term::ProgressBar;
    state $tpb;
    if (!$tpb) {
        $tpb = Term::ProgressBar->new({
            ETA    => 'linear',
            count  => 100, # dummy
            remove => 1,
        });
        $tpb->minor(0);
    }
    $tpb;
}

sub _message {
    my $self = shift;
    my $tpb = $self->_tpb;
    $tpb->message(@_);
}

sub update {
    my ($self, %args) = @_;

    if (defined $args{target}) {
        my $tpb = $self->_tpb;
        $tpb->target($args{target});
        $tpb->update($args{pos});
    }
}

1;
# ABSTRACT: Output progress to terminal using Term::ProgressBar

=head1 SYNOPSIS

 use Progress::Any '$progress';
 use Progress::Any::Output::TermProgressBar;

 Progress::Any->set_output(
     output => Progress::Any::Output::TermProgressBar->new(
         # options
     ),
 );

 $progress->init(target=>4);
 do { $progress->update(message=>"Test"); sleep 1 } for 1..4;


=head1 DESCRIPTION

This output currently only supports 1 indicator and doesn't support undefined
target.


=head1 SEE ALSO

L<Progress::Any>

L<Term::ProgressBar>

=cut


package Term::ProgressBar::Color;

use 5.010001;
use strict;
use warnings;

use Moo;

has target => (is => 'rw', );

# VERSION

sub update {
    my ($self, %args) = @_;
}

1;
# ABSTRACT: Provide a progress meter on a standard terminal (with color)

=head1 SYNOPSIS

 use Term::ProgressBar::Color;

 my $progress = Term::ProgressBar::Color->new(target=>10);

 for (1..10) {
     $progress->update(pos=>$_, message=>"Currently at $_/10 ...");
     sleep 1;
 }
 $progress->finish; # doesn't do anything in this case, since already 100%


=head1 DESCRIPTION

L<Term::ProgressBar::Color> is rather like L<Term::ProgressBar>, with some
differences in API and some additional features:

=over

=item * colors and color themes

Uses colors by default, but can degrade to no colors if terminal does not
support it. Choose and create your own color themes.

=item * Unicode/wide character support

Use Unicode characters, but can degrade to plain ASCII if terminal does not
support it.

=item * formatting

Sprintf-style formatting.

=item * message

Display message in addition to progress percentage/bar.

=item * unknown target and retargetting

Progress can still be displayed even if target is unknown. Target can be changed
between update()'s.

=back

Term::ProgressBar::Color can also be used through L<Progress::Any>.


=head1 FORMATTING

This class supports customizing the display of progress bar using sprintf-style
formatting. Here are the recognized format strings:

=over

=item * C<%a>

Elapsed (absolute) time. Time format is determined by the C<time_format>
attribute.

=item * C<%e>

Estimated completion time. Time format is determined by the C<time_format>
attribute.

=item * C<%(width).(prec)p>

Percentage of completion. You can also specify width and precision, like C<%f>
in Perl sprintf.

=item * C<%(width).(prec)c>

pos.

=item * C<(width).(prec)C>

Target.

=item * C<%B>

Progress bar.

=item * C<%B>

Progress bar with the message embedded inside. Message will be clipped if too
long.

=item * C<%m>

Message. Will be clipped if too long.

=item * C<%%>

A literal C<%>.

=back


=head1 ATTRIBUTES

=head2 target => NUM

Target can be changed anytime or be left undefined.

=head2 format => STR (default: '')

See L</"FORMATTING"> for more details.

=head2 width => INT

Set width of progress bar (in visual columns). By default, the whole terminal
width is used.

=head2 pos => NUM (default: 0)

The current position. You can start at any position by setting this attribute
before update().

=head2


=head1 METHODS

=head2 new(%args) => OBJ

Create new object.

=head2 update(%args)

Update (redraw) progress bar. Arguments:

=over

=item * pos => NUM

Optional. The new position. If unspecified, will default to C<< (current pos) +
1 >>.

=item * message => STR

Optional. Message to be displayed. Not all styles support displaying this.

=back


=head1 FAQ


=head1 TODO

Background updating (through threads or forked process), so progress can still
be updated even though the main process is waiting on I/O or external process.
But we need to think of a good way to synchronize output.

Animations, like rotating line (C<- / | \ ->) or pulsating (C<. o O o .>). Also
animation by varying colors.

Detect connection speed and degrade to lower-frequency updating if connection is
slow.

Styles. Preset formats as well as some behaviors like animation.


=head1 SEE ALSO

L<Term::ProgressBar>

L<Progress::Any> and L<Progress::Any::Output::TermProgressBarColor>

Ruby library: ruby-progressbar, L<https://github.com/jfelchner/ruby-progressbar>

=cut
