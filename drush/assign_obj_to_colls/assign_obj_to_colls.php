<?php

// // // Variables to change
// Full path to text file of PIDs of object and target colls
$pids = '/opt/migrations/aip/testpid.txt';

// // // All variables you will need to update for routine use of the script are ABOVE this line

$linelist = array();

$fn = fopen($pids, 'r');

while(!feof($fn)) {
    $line = fgets($fn);
    array_push($linelist, rtrim($line));
}

$goodlines = array_filter($linelist, 'strlen');

$splitlines = array();

foreach($goodlines as $line) {
    array_push($splitlines, explode("|", $line));
}


drupal_static_reset('islandora_get_tuque_connection');
$tuque = islandora_get_tuque_connection();
$repository = $tuque->repository;

foreach ($splitlines as $line) {
    $objpid = $line[0];
    $object = get_object($objpid);

    if ($object) {
      $collpids = explode("^^", $line[1]);
      check_and_set_collections($object, $collpids);
    } else {
      drush_log(dt("Object !pid does not exist. Collections cannot be updated",
        array('!pid' => $objpid)),
        'warning');
      continue;
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
      drush_log(dt("Collection !coll does not exist. !object cannot be added to this collection.",
        array('!coll' => $coll, '!object' => $object->id)),
        'warning');
      continue;
    }
  }
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
?>
