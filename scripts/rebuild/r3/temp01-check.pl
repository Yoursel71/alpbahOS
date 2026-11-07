# REBUILD-R3-TEMP-01 check (runs inside the r3-root chroot). Reads the stale list, requires every
# stale .pm module by name, and prints where perl resolves it. Output is compared before and after removal.
use strict; use warnings; use Config; use File::Spec; use Data::Dumper;
print "smoke: ok\n";
print "version: $Config{version} archlib: $Config{archlib}\n";
print "INC: $_\n" for @INC;
open my $fh, '<', $ARGV[0] or die "list: $!";
my @stale = sort map { chomp; $_ } <$fh>;
my @dirs = map { s{^/}{}r =~ s{/*$}{/}r } sort { length($b) <=> length($a) } @INC;
my ($n, $resolved_stale, $fail) = (0, 0, 0);
for my $rel (@stale) {
    next unless $rel =~ m{\.pm$};
    my ($d) = grep { index($rel, $_) == 0 } @dirs;
    if (!defined $d) { print "NOINC $rel\n"; next; }
    my $file = substr($rel, length($d));
    my $mod = $file; $mod =~ s/\.pm$//; $mod =~ s{/}{::}g;
    $n++;
    my $ok = eval "require $mod; 1";
    my $path = $INC{$file};
    if (!$ok) { $fail++; print "FAIL $mod\n"; next; }
    $resolved_stale++ if defined $path && $path eq "/$rel";
    print "RESOLVE $mod ", (defined $path ? $path : 'UNDEF'), "\n";
}
print "pm_modules=$n resolved_to_stale=$resolved_stale failed=$fail\n";
print "non_pm_stale=", scalar(grep { !/\.pm$/ } @stale), "\n";
print Data::Dumper->new([{ ok => 1 }])->Terse(1)->Indent(0)->Dump, "\n";
