#!perl
use strict;
use warnings;
use constant HAS_LEAKTRACE => eval { require Test::LeakTrace };
use Test::More HAS_LEAKTRACE
    ? ( tests => 7 )
    : ( skip_all => 'require Test::LeakTrace' );
use Test::LeakTrace;

#use Devel::LeakGuard::Object qw( GLOBAL_bless :at_end leakguard );

use_ok('Dezi::App');
use_ok('Dezi::Lucy::InvIndex');
use_ok('Dezi::Lucy::Searcher');

SKIP: {

    unless ( $ENV{TEST_LEAKS} ) {
        skip "set TEST_LEAKS to test memory leaks", 4;
    }

    leaks_cmp_ok {
        my $invindex = Dezi::Lucy::InvIndex->new(
            clobber => 0,                  # Lucy handles this
            path    => 't/index.swish1',
        );
    }
    '<', 1, "invindex alone";

    # clean up
    system("rm -rf t/index.swish1");

    leaks_cmp_ok {
        my $invindex = Dezi::Lucy::InvIndex->new(
            clobber => 0,                  # Lucy handles this
            path    => 't/index.swish2',
        );
        my $program = Dezi::App->new(
            invindex   => "$invindex",      # force stringify to avoid leaks
            aggregator => 'fs',
            indexer    => 'lucy',
            config     => 't/config.xml',

            #verbose    => 1,
            #debug      => 1,
        );

        #diag( $program->aggregator->{_swish3} );

        # skip the index dir every time
        # the '1' arg indicates to append the value, not replace.
        $program->config->FileRules( 'dirname is index.swish', 1 );
        $program->config->FileRules( 'filename is config.xml', 1 );

        $program->run('t/test.html');

    }
    '<=', 31, "indexer leak test";

    # clean up
    system("rm -rf t/index.swish2");

    leaks_cmp_ok {

        my $indexer = Dezi::Lucy::Indexer->new(
            invindex => 't/index.swish3',
            config   => 't/config.xml',
        );

        $indexer->finish();

        #$indexer->invindex->path->file( SWISH_HEADER_FILE() );

    }
    '<=', 27, "Dezi::Lucy::Indexer leak test";

    leaks_cmp_ok {
        my $searcher
            = Dezi::Lucy::Searcher->new( invindex => "t/index.swish3",
            );
        my $results = $searcher->search('test');
        my $result  = $results->next;

    }
    '<=', 21, "Searcher";

    # clean up
    system("rm -rf t/index.swish3");

}

