#!/usr/bin/perl
#
# TM3 JSON to DBC convertor.
# usage: json2dbc.pl file.json > out.dbc
#
# © Korn 2020

use Data::Dumper;
use JSON::XS;
use File::Slurp;



my $jsontxt = read_file($ARGV[0]);
my $in = decode_json($jsontxt);
#print Dumper($in->{messages}->{VCRIGHT_hvacRequest});
#

my $values = '';

#Prefix
print 'VERSION ""


NS_ :
        NS_DESC_
        CM_
        BA_DEF_
        BA_
        VAL_
        CAT_DEF_
        CAT_
        FILTER
        BA_DEF_DEF_
        EV_DATA_
        ENVVAR_DATA_
        SGTYPE_
        SGTYPE_VAL_
        BA_DEF_SGTYPE_
        BA_SGTYPE_
        SIG_TYPE_REF_
        VAL_TABLE_
        SIG_GROUP_
        SIG_VALTYPE_
        SIGTYPE_VALTYPE_
        BO_TX_BU_
        BA_DEF_REL_
        BA_REL_
        BA_DEF_DEF_REL_
        BU_SG_REL_
        BU_EV_REL_
        BU_BO_REL_
        SG_MUL_VAL_

BS_:

BU_: Receiver ChassisBus VehicleBus PartyBus

';
my $i = 0;
for my $msgname (sort keys %{$in->{messages}}) {
	$i++;
	
	#ignore broken ones
	next if $msgname =~ /^(GTW_hrl|EPAS3S_sysStatus|OD.N_IsoTpPipeVCS.C|.*_udsResponse|DAS_telem.tryRadar|EPAS3P_sysStatus|ESP_info|GTW_adc.*|GTW_status|GTW_updateStatus|SCCM_info|UDS_.*Request|UI_IsoTpUDPPipeVCS.C)$/;
	my $d = $in->{messages}->{$msgname};
	#print "Found message $msgname\n";
	#print Dumper($d);
	my $mid = $d->{message_id};
	my $mid_hex = sprintf("%X", $mid);
	my $name_hex = "ID".$mid_hex.$msgname;
	my $msglen = $d->{length_bytes};
	print "BO_ $mid $name_hex: $msglen VehicleBus\n";

	#Find muxer, if any.
	my $muxname = '';
	for my $signame ( keys %{$d->{signals}}) {
		if (defined $d->{signals}->{$signame}->{is_muxer}) {
			$muxname = $signame ;
			#print STDERR "$msgname $signame is mux\n";

		};
	}	

	#Signals
	for my $signame ( sort { 
			#$d->{signals}->{$a}->{start_position} <=>  $d->{signals}->{$b}->{start_position}

			# Bring mux on top
			return -1 if $a eq $muxname;
			return 1 if $b eq $muxname;
			$a cmp $b;
				} keys %{$d->{signals}}) {
		my $s = $d->{signals}->{$signame};
		#print Dumper($s);
		
		# Some weird signals starting at 7 with width=64.
		$s->{start_position} = 0 if $s->{width} == 64;

		#Message is muxed, signal is not
		if (($s->{mux_id} eq '') && ($muxname ne '') && ($muxname ne $signame)) {
			print STDERR "-- ! $msgname $signame mux is null\n";
			next;
		}

		my $endianess = ($s->{endianess} eq 'LITTLE') ? 0 : 1;
		my $sign = ($s->{signedness} eq 'UNSIGNED') ? '+' : '-';
		my $mux_id = '';
		if ($muxname ne '') {
			$mux_id = ($signame eq $muxname) ? 'M ' : "m".$s->{mux_id}." ";
		}

		print " SG_ $signame ".$mux_id.": ".
		$s->{start_position}."|". $s->{width}."@".$endianess.$sign.
		" (". $s->{scale}.",". $s->{offset}.")".
		" [". $s->{min}."|". $s->{max}."]".
		' "'.$s->{units}.'"'.
		"  Receiver\n";

		#Populate value map.
		if (defined $s->{value_description}) {
			my $vd = $s->{value_description};
			$values .= "VAL_ $mid $signame "; 
			for my $vn (sort keys %$vd) {
				$values .= $vd->{$vn}.' "'.$vn.'" ';
			}
			$values .= ";\n";
		}

	}

	print "\n";


}
print $values;
