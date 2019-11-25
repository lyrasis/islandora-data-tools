<?php

// // // Variables to change 
// Full path to text file of PIDs
$pids = '/home/kristina/code/islandora-data-tools/data/pids.txt';

// Directory where datastream content will be saved
$savedir = "/home/kristina/code/islandora-data-tools/data/pdfs";

// Name of datastream you want to grab
// See: https://wiki.duraspace.org/display/ISLANDORA/APPENDIX+C+-+DATASTREAM+REFERENCE
$dsid = 'OBJ';

// // // All variables you will need to update for routine use of the script are ABOVE this line

$pidlist = [];

$fn = fopen($pids, 'r');
while(! feof($fn)) {
    $line = fgets($fn);
    $pidlist[] = rtrim($line);
}

$cleanpids = array_filter($pidlist, 'strlen');

if(!is_dir($savedir)){
    mkdir($savedir);
}

drupal_static_reset('islandora_get_tuque_connection');
$tuque = islandora_get_tuque_connection();
$repository = $tuque->repository;


// $suffix = get_suffix($dsid);

foreach ($cleanpids as $pid) {
    get_and_write_datastream($pid, $dsid, $savedir);
}
           
// foreach ($results as $result) {
//     $pid = $result['pid']['value'];
//     $parents[] = $pid;
// }

// foreach ($parents as $parent) {
//     get_and_write_datastream($parent, $dsid, $suffix, $savedir);
// } // end foreach $coll_ids


function get_and_write_datastream($pid, $dsid, $path)
{
    $obj = islandora_object_load($pid);
    $datastream = $obj[$dsid];
    $mimetype = $datastream->mimetype;
    $suffix = get_suffix($mimetype);
    $path = "$path/$pid$suffix";
    print "Saved $path \n";
    $datastream->getContent($path);
}

function get_suffix($mimetype)
{
    switch ($mimetype) {
    case 'application/pdf':
        return '.pdf';
        break;
    }
}


?>
