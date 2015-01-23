package Progress::Any::Output::TermProgressBarColor;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

use Color::ANSI::Util qw(ansifg ansibg);
use Text::ANSI::Util qw(ta_mbtrunc ta_mbswidth ta_length);
require Win32::Console::ANSI if $^O =~ /Win/;

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

    $args{fh} = delete($args0{fh});
    $args{fh} //= \*STDOUT;

    $args{show_delay} = delete($args0{show_delay});

    keys(%args0) and die "Unknown output parameter(s): ".
        join(", ", keys(%args0));

    $args{_last_hide_time} = time();

    bless \%args, $class;
}

sub update {
    my ($self, %args) = @_;

    my $now = time();

    # if there is show_delay, don't display until we've surpassed it
    if (defined $self->{show_delay}) {
        return if $now - $self->{show_delay} < $self->{_last_hide_time};
    }

    # "erase" previous display
    my $ll = $self->{lastlen};
    if (defined $self->{lastlen}) {
        my $fh = $self->{fh};
        print $fh "\b" x $self->{lastlen};
        undef $self->{lastlen};
    }

    my $p = $args{indicator};
    my $tottgt = $p->total_target;
    my $totpos = $p->total_pos;
    my $is_complete = $p->{state} eq 'finished' ||
        defined($tottgt) && $tottgt > 0 && $totpos == $tottgt;
    if ($is_complete) {
        if ($ll) {
            my $fh = $self->{fh};
            print $fh " " x $ll, "\b" x $ll;
            $self->{_last_hide_time} = $now;
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
        if ($tottgt) {
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
            if ($msg =~ m!</elspan!) {
                require String::Elide::Parts;
                $msg = String::Elide::Parts::elide($msg, $bwidth);
            }
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
    my $fh = $self->{fh};
    print $fh $bar;

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
    my $fh = $self->{fh};
    print $fh "\b" x $ll, " " x $ll, "\b" x $ll;
}

sub keep_delay_showing {
    my $self = shift;

    $self->{_last_hide_time} = time();
}

1;
# ABSTRACT: Output progress to terminal as color bar

=for Pod::Coverage ^(update|cleanup)$

=head1 SYNOPSIS

 use Progress::Any::Output;

 # use default options
 Progress::Any::Output->set('TermProgressBarColor');

 # set options
 Progress::Any::Output->set('TermProgressBarColor',
                            width=>50, fh=>\*STDERR, show_delay=>5);


=head1 DESCRIPTION

B<THIS IS AN EARLY RELEASE, SOME THINGS ARE NOT YET IMPLEMENTED E.G. TEMPLATE,
STYLES, COLOR THEMES>.

Sample screenshots:

=begin HTML

<img src="http://blogs.perl.org/users/perlancar/progany-tpc-sample.jpg" />

=end HTML

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

Not yet implemented.

Choose color theme. To see what color themes are available, use
C<list_color_themes()>.

=item * style => STR

Not yet implemented.

Choose style. To see what styles are available, use C<list_styles()>. Styles
determine the characters used for drawing the bar, alignment, etc.

=item * template => STR (default: '%p [%B]%e')

Not yet implemented.

See B<fill_template> in Progress::Any's documentation. Aside from template
strings supported by Progress::Any, this output recognizes these additional
strings: C<%b> to display the progress bar (using the rest of the available
width), C<%B> to display the progress bar as well as the message inside it.

=item * fh => handle (default: \*STDOUT)

Instead of the default STDOUT, you can direct the output to another filehandle.

=item * show_delay => int

If set, will delay showing the progress bar until the specified number of
seconds. This can be used to create, e.g. a CLI application that is relatively
not chatty but after several seconds of inactivity

=back

=head2 keep_delay_showing()

Can be called to reset the timer that counts down to show progress bar when
C<show_delay> is defined. For example, if C<show_delay> is 5 seconds and two
seconds have passed, it should've been 3 seconds before progress bar is shown in
the next C<update()>. However, if you call this method, it will be 5 seconds
again before showing.


=head1 ENVIRONMENT

=head2 COLOR => BOOL

Can be used to force or disable color.

=head2 COLOR_DEPTH => INT

Can be used to override color depth detection. See L<Color::ANSI::Util>.

=head2 COLUMNS => INT

Can be used to override terminal width detection.


=head1 SEE ALSO

L<Progress::Any>

L<Term::ProgressBar>

Ruby library: ruby-progressbar, L<https://github.com/jfelchner/ruby-progressbar>

=cut
