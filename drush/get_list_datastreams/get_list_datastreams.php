<?php

// // // Variables to change
// Full path to text file of PIDs
$pids = '/opt/migrations/project/obj_pids.txt';

// Directory where datastream content will be saved
$savedir = "/opt/migrations/project/techmd";

// Name of datastream you want to grab
// See: https://wiki.duraspace.org/display/ISLANDORA/APPENDIX+C+-+DATASTREAM+REFERENCE
$dsid = 'TECHMD';

// // // All variables you will need to update for routine use of the script are ABOVE this line

//Store the micro time so that we know
//when our script started to run.
$executionStartTime = microtime(true);

$pidlist = array();

$fn = fopen($pids, 'r');

while(!feof($fn)) {
    $line = fgets($fn);
    array_push($pidlist, rtrim($line));
}

$cleanpids = array_filter($pidlist, 'strlen');
$pid_ct = count($cleanpids);

if(!is_dir($savedir)){
    mkdir($savedir);
}

drupal_static_reset('islandora_get_tuque_connection');
$tuque = islandora_get_tuque_connection();
$repository = $tuque->repository;

$progresscounter = 0;

foreach ($cleanpids as $pid) {
    $progresscounter = ++$progresscounter;
    get_and_write_datastream($pid, $dsid, $savedir);
    echo progress_bar($progresscounter, $pid_ct, 'Progress');
}

function get_and_write_datastream($pid, $dsid, $path)
{
if (!islandora_object_load($pid)) {
  drush_log(dt("Object !pid does not exist. !dsid not retrieved",
    array('!dsid' => $dsid, '!pid' => $pid)),
    'warning');
  return FALSE;
 } else {
    $obj = islandora_object_load($pid);

    if (!isset($obj[$dsid])) {
      drush_log(dt("!dsid does not exist for object !pid does not exist. !dsid not retrieved",
      array('!dsid' => $dsid, '!pid' => $pid)),
      'warning');
    } else {
    $datastream = $obj[$dsid];
    switch ($dsid) {
    case 'MODS':
        $suffix = '.xml';
        break;
    case 'TECHMD':
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
}

function get_suffix($mimetype)
{
    switch ($mimetype) {
    case 'application/pdf':
        return '.pdf';
        break;
    }
}

function progress_bar($done, $total, $info="", $width=50) {
    $perc = round(($done * 100) / $total);
    $bar = round(($width * $perc) / 100);
    return sprintf("%s%%[%s>%s]%s\n", $perc, str_repeat("=", $bar), str_repeat(" ", $width-$bar), $info);
}


?>
