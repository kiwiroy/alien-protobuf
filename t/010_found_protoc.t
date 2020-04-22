#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use Test::Alien;
use Alien::ProtoBuf;
use ExtUtils::CppGuess;
use Path::Tiny 'path';

alien_ok 'Alien::ProtoBuf';

ok + (my $version = Alien::ProtoBuf->version), 'version set';

run_ok([qw(protoc --version)], 'compiler installed')->success('compiler ran')
  ->out_like(qr/^libprotoc\s[0-9\.]+$/, 'correct output')
  ->out_like(qr/\Q$version\E/, 'version matches')->err_like(qr/^$/, 'empty');

my $fxt
  = (my $fxt_dir = path('.')->absolute->child('t', 'fixtures'))->stringify;
run_ok(['protoc', "-I$fxt", "--python_out=$fxt", 'addressbook.proto'],
  'compile')->success('compiled')->out_like(qr/^$/)->err_like(qr/^$/);

ok -e $fxt_dir->child('addressbook_pb2.py');

done_testing;
