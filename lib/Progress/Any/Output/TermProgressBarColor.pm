package Progress::Any::Output::TermProgressBarColor;

use 5.010001;
use strict;
use warnings;

use Color::ANSI::Util qw(ansifg ansibg);
use Text::ANSI::Util qw(ta_mbtrunc ta_mbswidth ta_length);
require Win32::Console::ANSI if $^O =~ /Win/;

# VERSION

$|++;

sub new {
    my ($class, %args0) = @_;

    my %args;

    $args{width} = delete($args0{width});
    if (!defined($args{width})) {
        my ($cols, $rows);
        if ($ENV{COLUMNS}) {
            $cols = $ENV{COLUMNS};
        } elsif (eval { require Term::Size; 1 }) {
            ($cols, $rows) = Term::Size::chars();
        } else {
            $cols = 80;
        }
        # on windows if we print at rightmost column, cursor will move to the
        # next line, so we try to avoid that
        $args{width} = $^O =~ /Win/ ? $cols-1 : $cols;
    }

    keys(%args0) and die "Unknown output parameter(s): ".
        join(", ", keys(%args0));

    bless \%args, $class;
}

sub update {
    my ($self, %args) = @_;

    # "erase" previous display
    my $ll = $self->{lastlen};
    if (defined $self->{lastlen}) {
        print "\b" x $self->{lastlen};
        undef $self->{lastlen};
    }

    my $p = $args{indicator};
    my $tottgt = $p->total_target;
    my $totpos = $p->total_pos;
    my $is_complete = $p->{state} eq 'finished' ||
        defined($tottgt) && $tottgt > 0 && $totpos == $tottgt;
    if ($is_complete) {
        if ($ll) {
            print " " x $ll, "\b" x $ll;
        }
        return;
    }

    # XXX follow 'template'
    my $bar;
    my $bar_pct = $p->fill_template("%p%% ", %args);

    my $bar_eta = $p->fill_template("%R", %args);

    my $bar_bar = "";
    my $bwidth = $self->{width} - length($bar_pct) - length($bar_eta) - 2;
    if ($bwidth > 0) {
        if (defined $tottgt) {
            my $bfilled = int($totpos / $tottgt * $bwidth);
            $bfilled = $bwidth if $bfilled > $bwidth;
            $bar_bar = ("=" x $bfilled) . (" " x ($bwidth-$bfilled));

            my $message = $args{message};
        } else {
            # display 15% width of bar just moving right
            my $bfilled = int(0.15 * $bwidth);
            $bfilled = 1 if $bfilled < 1;
            $self->{_x}++;
            if ($self->{_x} > $bwidth-$bfilled) {
                $self->{_x} = 0;
            }
            $bar_bar = (" " x $self->{_x}) . ("=" x $bfilled) .
                (" " x ($bwidth-$self->{_x}-$bfilled));
        }

        my $msg = $args{message};
        if (defined $msg) {
            $msg = ta_mbtrunc($msg, $bwidth);
            my $mwidth = ta_mbswidth($msg);
            $bar_bar = ansifg("808080") . $msg . ansifg("ff8000") .
                substr($bar_bar, $mwidth);
        }

        $bar_bar = ansifg("ff8000") . $bar_bar;
    }

    $bar = join(
        "",
        ansifg("ffff00"), $bar_pct,
        "[$bar_bar]",
        ansifg("ffff00"), $bar_eta,
        "\e[0m",
    );
    print $bar;

    $self->{lastlen} = ta_length($bar);
}

sub cleanup {
    my ($self) = @_;

    # sometimes (e.g. when a subtask's target is undefined) we don't get
    # state=finished at the end. but we need to cleanup anyway at the end of
    # app, so this method is provided and will be called by e.g.
    # Perinci::CmdLine

    my $ll = $self->{lastlen};
    return unless $ll;
    print "\b" x $ll, " " x $ll, "\b" x $ll;
}

1;
# ABSTRACT: Output progress to terminal as color bar

=for Pod::Coverage ^(update|cleanup)$

=head1 SYNOPSIS

 use Progress::Any::Output;
 Progress::Any::Output->set('TermProgressBarColor', width=>50);


=head1 DESCRIPTION

B<THIS IS AN EARLY RELEASE, SOME THINGS ARE NOT YET IMPLEMENTED E.G. TEMPLATE,
STYLES, COLOR THEMES>.

This output displays progress indicators as colored progress bar on terminal. It
produces output similar to that produced by L<Term::ProgressBar>, except that it
uses the L<Progress::Any> framework and has additional features:

=over

=item * colors and color themes

=item * template and styles

=item * wide character support

=item * displaying message text in addition to bar/percentage number

=back

XXX option to cleanup when complete or not (like in Term::ProgressBar) and
should default to 1.


=head1 METHODS

=head2 new(%args) => OBJ

Instantiate. Usually called through C<<
Progress::Any::Output->set("TermProgressBarColor", %args) >>.

Known arguments:

=over

=item * width => INT

Width of progress bar. The default is to detect terminal width and use the whole
width.

=item * color_theme => STR

Choose color theme. To see what color themes are available, use
C<list_color_themes()>.

=item * style => STR

Choose style. To see what styles are available, use C<list_styles()>. Styles
determine the characters used for drawing the bar, alignment, etc.

=item * template => STR (default: '%p [%B]%e')

See B<fill_template> in Progress::Any's documentation. Aside from template
strings supported by Progress::Any, this output recognizes these additional
strings: C<%b> to display the progress bar (using the rest of the available
width), C<%B> to display the progress bar as well as the message inside it.

=back


=head1 ENVIRONMENT

=head2 COLOR => BOOL

Can be used to force or disable color.

=head2 COLOR_DEPTH => INT

Can be used to override color depth detection. See L<Color::ANSI::Util>.

=head2 COLUMNS => INT

Can be used to override terminal width detection.


=head1 TODO

Background updating (through threads or forked process), so progress can still
be updated even though the main process is waiting on I/O or external process.
But we need to think of a good way to synchronize output.

Animations, like rotating line (C<- / | \ ->) or pulsating (C<. o O o .>). Also
animation by varying colors.

Detect connection speed and degrade to lower-frequency updating if connection is
slow.

Styles. Preset formats as well as some behaviors like animation.

Detection of column change. On each update(), retrieve terminal width again.


=head1 SEE ALSO

L<Progress::Any>

L<Term::ProgressBar>

Ruby library: ruby-progressbar, L<https://github.com/jfelchner/ruby-progressbar>

=cut
