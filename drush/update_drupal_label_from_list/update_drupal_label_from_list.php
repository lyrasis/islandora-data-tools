<?php

//Store the micro time so that we know
//when our script started to run.
$executionStartTime = microtime(true);

// // // Variables to change
// Full path to text file of PIDs of object and target colls
$input = '/opt/migrations/osl/test_titles.txt';

// // // All variables you will need to update for routine use of the script are ABOVE this line

$linelist = array();

$fn = fopen($input, 'r');

while(!feof($fn)) {
    $line = fgets($fn);
    array_push($linelist, rtrim($line));
}

$goodlines = array_filter($linelist, 'strlen');
$linecount = count($goodlines);
echo "Updating labels for $linecount objects...\n\n";

$splitlines = array();

foreach($goodlines as $line) {
    array_push($splitlines, explode("|", $line));
}

drupal_static_reset('islandora_get_tuque_connection');
$tuque = islandora_get_tuque_connection();
$repository = $tuque->repository;

$progresscounter = 0;

foreach ($splitlines as $line) {
    $progresscounter = ++$progresscounter;

    $objpid = $line[0];
    $object = get_object($objpid);

    if ($object) {
      $label = $line[1];
      $object->label = $label;
    } else {
      drush_log(dt("Nonexistent object: !pid -- Label not updated",
        array('!pid' => $objpid)),
        'warning');
      continue;
    }
    echo progress_bar($progresscounter, $linecount, 'Label Update Progress');
}


function progress_bar($done, $total, $info="", $width=50) {
    $perc = round(($done * 100) / $total);
    $bar = round(($width * $perc) / 100);
    return sprintf("%s%%[%s>%s]%s\n", $perc, str_repeat("=", $bar), str_repeat(" ", $width-$bar), $info);
}

function get_object($pid)
{
  $obj = islandora_object_load($pid);

  if (!obj) {
    return FALSE;
   } else {
    return $obj;
   }
}

//At the end of your code, compare the current
//microtime to the microtime that we stored
//at the beginning of the script.
$executionEndTime = microtime(true);

//The result will be in seconds and milliseconds.
$seconds = $executionEndTime - $executionStartTime;

//Print it out
echo "\n\nThis script took $seconds to execute.";

?>
