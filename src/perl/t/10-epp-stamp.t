use strict;
use warnings;
use Test::More tests => 23;
use Test::Exception;

use_ok('wtsi_clarity::epp::stamp');

{
  my $s = wtsi_clarity::epp::stamp->new(process_url => 'some');
  isa_ok($s, 'wtsi_clarity::epp::stamp');
}

{
  local $ENV{'WTSICLARITY_WEBCACHE_DIR'} = 't/data/stamp';
  #local $ENV{'SAVE2WTSICLARITY_WEBCACHE'} = 1;
  my $s = wtsi_clarity::epp::stamp->new(process_url => 'http://clarity-ap:8080/api/v2/processes/24-98502');
  lives_ok { $s->_analytes } 'got all info from clarity';
  my @containers = keys %{$s->_analytes};
  is (scalar @containers, 1, 'one input container');
  is (scalar keys $s->_analytes->{$containers[0]}, 6, 'five input analytes and a container doc');

  is ($s->container_type_name, 'ABgene 0800', 'container name retrieved correctly');
  is ($s->_validate_container_type, 0, 'container type validation flag unset');
  my $type_xml;
  lives_ok {$type_xml = $s->_container_type} 'container type retrieved';
  is ($type_xml->findvalue(q{ ./@uri }), "http://clarity-ap.internal.sanger.ac.uk:8080/api/v2/containertypes/105",
    'container type value');

  delete $s->_analytes->{$containers[0]}->{'doc'};
  my @wells = sort map { $s->_analytes->{$containers[0]}->{$_}->{'well'} } (keys %{$s->_analytes->{$containers[0]}});
  is (join(q[ ], @wells), 'B:11 D:11 E:11 G:9 H:9', 'sorted wells');
}

{
  SKIP: {
    if ( !$ENV{'LIVE_TEST'}) {
      skip 'set LIVE_TEST to true to run', 5;
    }
  
    local $ENV{'WTSICLARITY_WEBCACHE_DIR'} = 't/data/stamp';
    my $s = wtsi_clarity::epp::stamp->new(
      process_url => 'http://clarity-ap.internal.sanger.ac.uk:8080/api/v2/processes/24-98502'
    );
    lives_ok { $s->_analytes } 'got all info from clarity';
    local $ENV{'WTSICLARITY_WEBCACHE_DIR'} = q[];
    lives_ok { $s->_create_containers } 'containers created';
    my @container_urls = keys %{$s->_analytes};
    my $ocon = $s->_analytes->{$container_urls[0]}->{'output_container'};
    ok ($ocon, 'output container entry exists');
    like($ocon->{'limsid'}, qr/27-/, 'container limsid is set');
    like ($ocon->{'uri'}, qr/containers\/27-/, 'container uri is set');
  }
}

{
  local $ENV{'WTSICLARITY_WEBCACHE_DIR'} = 't/data/stamp';
  my $s = wtsi_clarity::epp::stamp->new(
    process_url => 'http://clarity-ap:8080/api/v2/processes/24-98502'
  );
  lives_ok { $s->_analytes } 'got all info from clarity';

  my @container_urls = keys %{$s->_analytes};
  my $climsid = '27-4536';
  my $curi = 'http://c.com/containers/' . $climsid;
  $s->_analytes->{$container_urls[0]}->{'output_container'}->{'limsid'} = $climsid;
  $s->_analytes->{$container_urls[0]}->{'output_container'}->{'uri'} = $curi;

  lives_ok { $s->_update_target_analytes } 'targer analytes updated';
  my @input_analytes = keys %{$s->_analytes->{$container_urls[0]}};
  my $ian = $s->_analytes->{$container_urls[0]}->{$input_analytes[0]};
  like ($ian->{'target_analyte_uri'}, qr/artifacts\/2-644754\Z/, 'truncated target analyte uri is set');
  my $doc = $ian->{'target_analyte_doc'};
  ok ($doc, 'target analyte XML doc retrieved');
  my @nodes = $doc->findnodes(q{/art:artifact/location});
  is (scalar @nodes, 1, 'one location node available');
  is ($doc->findvalue(q{ /art:artifact/location/container/@uri }), $curi, 'uri attr is set for the container');
  is ($doc->findvalue(q{ /art:artifact/location/container/@limsid }), $climsid, 'limsid attr is set for the container');
  is ($doc->findvalue(q{ /art:artifact/location/value}), 'H:9', 'well text node is set correctly');
}

1;
