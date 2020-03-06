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

foreach ($cleanpids as $pid) {
    get_and_write_datastream($pid, $dsid, $savedir);
}

function get_and_write_datastream($pid, $dsid, $path)
{
    $obj = islandora_object_load($pid);
    $datastream = $obj[$dsid];
    switch ($dsid) {
    case 'MODS':
        $suffix = '.xml';
        break;
    case 'OBJ':
        $suffix = get_suffix($mimetype);
        break;
    }
    $mimetype = $datastream->mimetype;
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
