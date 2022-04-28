<?php

//Store the micro time so that we know
//when our script started to run.
$executionStartTime = microtime(true);

// // // Variables to change
// Full path to text file of PIDs of object and target colls
// $input = '/opt/migrations/aip/assign9.txt';

// Patching in an array so I can run through multiple files
$input = [];

// // // All variables you will need to update for routine use of the script are ABOVE this line
// Patched as a function so I can filter the array of files in
the_main_thing($input);

function the_main_thing($input){
  foreach($input as $file){
    $linelist = array();

    $fn = fopen($file, 'r');

    while(!feof($fn)) {
        $line = fgets($fn);
        array_push($linelist, rtrim($line));
    }

    $goodlines = array_filter($linelist, 'strlen');
    $linecount = count($goodlines);
    echo "Assigning $linecount objects to target collections...\n\n";

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
          $collpids = explode("^^", $line[1]);
          check_and_set_collections($object, $collpids);
        } else {
          drush_log(dt("Nonexistent object: !pid -- Collection(s) not updated",
            array('!pid' => $objpid)),
            'warning');
          continue;
        }
        echo progress_bar($progresscounter, $linecount, 'Collection Assignment Progress');
    }
    sleep(60);
  }
}

function check_and_set_collections($object, $colls)
{
  $rels = $object->relationships;

  foreach ($colls as $coll) {
    $collobj = get_object($coll);

    if ($collobj) {
      if(!in_collection($rels, $coll)) {
        set_collection($rels, $coll);
      }
    } else {
      drush_log(dt("Nonexistent coll: !coll -- !object not added.",
        array('!coll' => $coll, '!object' => $object->id)),
        'warning');
      continue;
    }
  }
}

function progress_bar($done, $total, $info="", $width=50) {
    $perc = round(($done * 100) / $total);
    $bar = round(($width * $perc) / 100);
    return sprintf("%s%%[%s>%s]%s\n", $perc, str_repeat("=", $bar), str_repeat(" ", $width-$bar), $info);
}

function in_collection($rels, $coll)
{
  $incolls = $rels->get(FEDORA_RELS_EXT_URI, 'isMemberOfCollection');
  $parentarrs = array();
  $colls = array();
  foreach ($incolls as $membership) {
    array_push($parentarrs, $membership['object']);
  }
  foreach ($parentarrs as $parentarr) {
    array_push($colls, $parentarr['value']);
  }
  return in_array($coll, $colls);
}

function set_collection($rels, $coll)
{
  $rels->add(FEDORA_RELS_EXT_URI, 'isMemberOfCollection', $coll);
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
