use strict;
use warnings;
use Test::More tests => 22;
use Test::Exception;
use DateTime;

use_ok('wtsi_clarity::epp::sm::create_label');

{
  my $l = wtsi_clarity::epp::sm::create_label->new(process_url => 'some');
  isa_ok($l, 'wtsi_clarity::epp::sm::create_label');
  ok (!$l->source_plate, 'source_plate flag is false by default');
  $l = wtsi_clarity::epp::sm::create_label->new(process_url => 'some', source_plate=>1, printer => 'myprinter');
  ok ($l->source_plate, 'source_plate flag can be set to true');
  lives_ok {$l->printer} 'printer given, no access to process url to get the printer';
}

{
  local $ENV{'WTSICLARITY_WEBCACHE_DIR'} = 't/data/create_label';
  #local $ENV{'SAVE2WTSICLARITY_WEBCACHE'} = 1;
  my $l = wtsi_clarity::epp::sm::create_label->new(
    process_url => 'http://clarity-ap:8080/api/v2/processes/24-67069');

  lives_and(sub {is $l->printer, 'd304bc'}, 'correct trimmed printer name');
  lives_and(sub {is $l->user, 'D. Brooks'}, 'correct user name');
  lives_and(sub {is $l->_num_copies, 2}, 'number of copies as given');
  lives_and(sub {is $l->_plate_purpose, 'Stock Plate'}, 'plate purpose as given');
  {
    local $ENV{'WTSI_CLARITY_HOME'} = 't';
    throws_ok {$l->_printer_url} qr/Validation failed for 'WtsiClarityReadableFile'/,
      'failed to get print service url';
  }

  $l = wtsi_clarity::epp::sm::create_label->new(
    process_url => 'http://clarity-ap:8080/api/v2/processes/24-67069');
  my $config = join q[/]. $ENV{'HOME'}, '.wtsi_clarity', 'config';
  SKIP: {
    if ( !$ENV{'LIVE_TEST'} || !-e $config ) {
      skip 'set LIVE_TEST to true to run and have config file in your home directory', 1;
    }
    lives_and(sub {like $l->_printer_url, qr/c2ed34d0-7214-0131-2f13-005056a81d80/}, 'got printer url');
  }
}

{
  local $ENV{'WTSICLARITY_WEBCACHE_DIR'} = 't/data/create_label';
  my $l = wtsi_clarity::epp::sm::create_label->new(
    process_url => 'http://clarity-ap:8080/api/v2/processes/24-67069_custom');

  throws_ok { $l->printer} qr/Printer udf field should be defined/, 'error when printer not defined';
  lives_and(sub {is $l->user, q[]}, 'no user name by default');
  lives_and(sub {is $l->_num_copies, 1}, 'default number of copies');
  lives_and(sub {is $l->_plate_purpose, undef}, 'plate purpose undefined');
}

{
  local $ENV{'WTSICLARITY_WEBCACHE_DIR'} = 't/data/create_label';
  #local $ENV{'SAVE2WTSICLARITY_WEBCACHE'} = 1;
  my $l = wtsi_clarity::epp::sm::create_label->new(
     process_url => 'http://clarity-ap:8080/api/v2/processes/24-67069',
     source_plate => 1,
     _date => my $dt = DateTime->new(
        year       => 2014,
        month      => 5,
        day        => 21,
        hour       => 15,
        minute     => 04,
        second     => 23,
    ),
  ); 
  lives_ok {$l->_container} 'got containers';
  my @containers = keys %{$l->_container};
  is (scalar @containers, 1, 'correct number of containers');
  my $container_url = $containers[0];
  is (scalar @{$l->_container->{$container_url}->{'samples'}}, 12, 'correct number of samples');
  lives_ok {$l->_set_container_data} 'container data set';
  #TODO
  #get original container name
  #test that final name is 1890001204762
  #test that 'Supplier Container Name' udf is set to 'ces_tester_101_'
  #test that 'WTSI Container Purpose Name' is set to 'Stock Plate'
  lives_ok {$l->_set_container_data} 'container data set is run again';
  #test that 'Supplier Container Name' udf is still set to 'ces_tester_101_'
  lives_ok { $l->_format_label() } 'labels formatted';

  my $label = {
          'label_printer' => { 'footer_text' => {
                                                  'footer_text2' => 'Wed May 21 15:04:23 2014',
                                                  'footer_text1' => 'footer by D. Brooks'
                                                },
                               'header_text' => {
                                                  'header_text2' => 'Wed May 21 15:04:23 2014',
                                                  'header_text1' => 'header by D. Brooks'
                                                },
                               'labels' => [
                                             {
                                               'template' => 'plate',
                                               'plate' => {
                                                            'ean13' => '5260271204834',
                                                            'label_text' => {
                                                                              'text5' => 'SM-271204S',
                                                                              'role' => 'Stock Plate',
                                                                              'text6' => 'QKJMF',
                                                                            },
                                                            'sanger' => '21-May-2014 '
                                                          }
                                             },
                                           ]
                             }
        };
  $label->{'label_printer'}->{'labels'}->[1] = $label->{'label_printer'}->{'labels'}->[0];

  is_deeply($l->_generate_label(), $label, 'label hash representation');
  #$l->_print_label($label); #This prints a label
}

1;
