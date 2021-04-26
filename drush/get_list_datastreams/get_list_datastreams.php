<?php

// // // Variables to change
// Full path to text file of PIDs
$pids = '/opt/migrations/imods/ids_pvld_2021-04-26.txt';

// Directory where datastream content will be saved
$savedir = "/opt/migrations/imods/pvld";

// Name of datastream you want to grab
// See: https://wiki.duraspace.org/display/ISLANDORA/APPENDIX+C+-+DATASTREAM+REFERENCE
$dsid = 'MODS';

// // // All variables you will need to update for routine use of the script are ABOVE this line

$pidlist = array();

$fn = fopen($pids, 'r');

while(!feof($fn)) {
    $line = fgets($fn);
    array_push($pidlist, rtrim($line));
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
if (!islandora_object_load($pid)) {
  drush_log(dt("Object !pid does not exist. !dsid not retrieved",
    array('!dsid' => $dsid, '!pid' => $pid)),
    'warning');
  return FALSE;
 } elseif (!isset($obj[$dsid])) {
  drush_log(dt("!dsid does not exist for object !pid does not exist. !dsid not retrieved",
    array('!dsid' => $dsid, '!pid' => $pid)),
    'warning');
   } else {

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
    $datastream->getContent($path);
 }
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
