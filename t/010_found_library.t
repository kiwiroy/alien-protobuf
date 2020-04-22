#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use Test::Alien;
use Alien::ProtoBuf;
use ExtUtils::CppGuess;

plan skip_all => 'compiler only install detected'
  if Alien::ProtoBuf->compiler_only;

alien_ok 'Alien::ProtoBuf';

ok +Alien::ProtoBuf->cflags, 'have cflags';
ok +Alien::ProtoBuf->libs,   'have libs';

like +Alien::ProtoBuf->libs,     qr/protobuf/, 'correct lib name';
like +Alien::ProtoBuf->cflags,   qr/include/,  'include set';
isnt +Alien::ProtoBuf->cxxflags, undef,        'cxxflags not undefined';

ok + (my $version = Alien::ProtoBuf->version), 'version set';

SKIP: {
  skip "MS VC family compiler detected", 1 if ExtUtils::CppGuess->new->is_msvc;
  my ($major, $minor) = split /\./ => $version;
  skip "Pre 3.6 version detected", 1
    if ($major > 3 || ($minor < 6 && $major == 3));
  is +Alien::ProtoBuf->cxxflags, '-std=c++11', 'cxxflags correct';
};

done_testing;
