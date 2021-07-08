<?php

// // // Variables to change
// Full path to text file of PIDs
$pids = '/opt/migrations/project/obj_pids.txt';

// Directory where datastream content will be saved
$savedir = "/opt/migrations/project/techmd";

// Name of datastream you want to grab
// See: https://wiki.duraspace.org/display/ISLANDORA/APPENDIX+C+-+DATASTREAM+REFERENCE
$dsid = 'TECHMD';

// Path to log file (which replaces drush log)
$logpath = "/opt/migrations/osl/log.txt";

// // // All variables you will need to update for routine use of the script are ABOVE this line

//Store the micro time so that we know
//when our script started to run.
$executionStartTime = microtime(true);

$log = fopen($logpath, 'a');
fwrite($log, "Start time: $executionStartTime\n");
fclose($log);

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
    get_and_write_datastream($pid, $dsid, $savedir, $logpath);
    echo progress_bar($progresscounter, $pid_ct, 'Progress');
    }

function get_and_write_datastream($pid, $dsid, $path, $logpath) {
if (!islandora_object_load($pid)) {
  $warning = "Object $pid does not exist. $dsid not retrieved.";
  write_to_log($logpath, $warning);
  return FALSE;
 } else {
    $obj = islandora_object_load($pid);

    if (!isset($obj[$dsid])) {
      $warning = "$dsid does not exist for object $pid, so was not retrieved.";
      write_to_log($logpath, $warning);
      return FALSE;
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

function write_to_log($logpath, $warning) {
  $log = fopen($logpath, "a");
  fwrite($log, "$warning\n");
  fclose($log);
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
    return sprintf("%s%%[%s>%s]%s\r", $perc, str_repeat("=", $bar), str_repeat(" ", $width-$bar), $info);
}

$log = fopen($logpath, 'a');

//At the end of your code, compare the current
//microtime to the microtime that we stored
//at the beginning of the script.
$executionEndTime = microtime(true);

fwrite($log, "End time: $executionEndTime\n");

//The result will be in seconds and milliseconds.
$seconds = $executionEndTime - $executionStartTime;

$message = "\n\nThis script took $seconds to execute.";
fwrite($log, "End time: $message\n");
fclose($log);

//Print it out
echo $message;

?>
