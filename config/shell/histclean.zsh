# histclean: move junk entries out of the zsh history file into a review file.
#
# Usage: histclean [-n] [-m] [-f HISTFILE] [-o REVIEWFILE]
#   -n   dry run: only show what would be removed
#   -m   also remove multi-line entries (default: keep them, they may be
#        real for-loops / heredocs / backslash continuations)
#   -f   history file   (default: $HISTFILE or ~/.zsh_history)
#   -o   review file    (default: ~/.zsh_history_removed)
#
# "Junk" = command text starting with "$ ", ": " or "# " (also a bare $ : #).
# A timestamped backup of the history file is made before any change.
# Removed entries are APPENDED to the review file in the original format,
# so restoring is just: cat review >> history (after editing out what to keep).

_HISTCLEAN_PL=$(cat <<'PERL'
use strict; use warnings;
my ($hist, $out, $multi, $dry) = @ARGV;
open my $in, '<:raw', $hist or die "open $hist: $!\n";
my @recs; my $cur; my $ext;
while (my $l = <$in>) {
    $ext = ($l =~ /^: \d+:\d+;/) ? 1 : 0 unless defined $ext;
    my $new = !defined $cur
           || ($ext ? $l =~ /^: \d+:\d+;/ : $cur =~ /[^\\]\n\z/ || $cur !~ /\\\n\z/);
    if ($new) { push @recs, $cur if defined $cur; $cur = $l } else { $cur .= $l }
}
push @recs, $cur if defined $cur;
close $in;

my (@keep, @drop);
for my $r (@recs) {
    my $c = $r; $c =~ s/\n\z//;
    $c =~ s/^: \d+:\d+;// if $ext;
    my $junk = $c =~ /\A\s*[\$:#](\s|\z)/;
    my $ml   = $multi && $c =~ /\n/;
    ($junk || $ml) ? push(@drop, $r) : push(@keep, $r);
}
printf STDERR "total=%d  remove=%d  keep=%d\n", scalar @recs, scalar @drop, scalar @keep;
exit 0 unless @drop;
if ($dry) {
    for my $r (@drop) { (my $s = $r) =~ s/\n(?=.)/\n    /g; print $s }
    exit 0;
}
open my $o, '>>:raw', $out or die "open $out: $!\n";
print $o @drop; close $o;
my $tmp = "$hist.tmp.$$";
open my $t, '>:raw', $tmp or die "open $tmp: $!\n";
print $t @keep; close $t;
chmod((stat $hist)[2] & 07777, $tmp);
rename $tmp, $hist or die "rename: $!\n";
PERL
)

histclean() {
  emulate -L zsh
  local dry=0 multi=0 hist=${HISTFILE:-$HOME/.zsh_history} out=$HOME/.zsh_history_removed opt
  local usage="Usage: histclean [-h] [-n] [-m] [-f HISTFILE] [-o REVIEWFILE]

Move junk entries out of the zsh history file into a review file.
Junk = command starting with \"\$ \", \": \" or \"# \" (or a bare \$ : #).

Options:
  -h            Show this help and exit.
  -n            Dry run: print what would be removed; change nothing.
  -m            Also remove multi-line entries (for-loops, heredocs,
                backslash continuations). Default: keep them.
  -f HISTFILE   History file to clean.
                Default: \$HISTFILE, else ~/.zsh_history
  -o REVIEWFILE File that removed entries are appended to.
                Default: ~/.zsh_history_removed

A backup (HISTFILE.bak.<timestamp>) is made before any change.
To restore an entry, copy it from REVIEWFILE back into HISTFILE.

Examples:
  histclean -n         Preview junk-prefix removals
  histclean -n -m      Preview, including multi-line entries
  histclean -m         Remove junk and multi-line entries
Tip: close other terminal windows first so they don't rewrite old history."
  OPTIND=1
  while getopts "hnmf:o:" opt; do
    case $opt in
      h) print -r -- "$usage"; return 0 ;;
      n) dry=1 ;; m) multi=1 ;; f) hist=$OPTARG ;; o) out=$OPTARG ;;
      *) print -u2 -r -- "$usage"; return 2 ;;
    esac
  done
  [[ -f $hist ]] || { print -u2 "histclean: no such file: $hist"; return 1 }

  # Flush this session's in-memory history to the file first (only for the real file)
  (( dry )) || [[ $hist != ${HISTFILE:-$HOME/.zsh_history} ]] || fc -W 2>/dev/null

  local bak=$hist.bak.$(date +%Y%m%d-%H%M%S)
  if (( ! dry )); then cp -p -- "$hist" "$bak" || return 1; fi

  perl -e "$_HISTCLEAN_PL" -- "$hist" "$out" $multi $dry || { print -u2 "histclean: failed; backup at $bak"; return 1 }

  if (( ! dry )); then
    print "backup: $bak\nreview: $out"
    # Reload cleaned history into this session
    if [[ $hist == ${HISTFILE:-$HOME/.zsh_history} ]]; then
      local s=$HISTSIZE; HISTSIZE=0; HISTSIZE=$s; fc -R
    fi
  fi
}
