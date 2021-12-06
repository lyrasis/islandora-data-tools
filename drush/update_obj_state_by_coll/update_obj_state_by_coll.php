<?php

// // // Variables to change
// Namespace and collection id
$namespace = 'abc';
$coll = 'xyz';
// intended state of the objects (A(ctive)/I(nactive)/D(eleted))
$state = 'I';

// Path to log file (which replaces drush log)
$logpath = "/opt/migrations/$namespace/log.txt";

// // // All variables you will need to update for routine use of the script are ABOVE this line

//Store the micro time so that we know
//when our script started to run.
$executionStartTime = microtime(true);

$log = fopen($logpath, 'a');
fwrite($log, "Start time: $executionStartTime\n");
fclose($log);

drupal_static_reset('islandora_get_tuque_connection');
$tuque = islandora_get_tuque_connection();
$repository = $tuque->repository;

$initpid = $namespace . ':' . $coll;

process_collection($initpid, $repository, $logpath);

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

function process_collection($collpid, $state, $repository, $logpath)
{
  $items = [];

  //identify objects that are members of the collection
  $objs = <<<QUERY
  SELECT DISTINCT ?pid ?label
  FROM <#ri>
  WHERE {
  ?pid <fedora-model:label> ?label ;
       <fedora-rels-ext:isMemberOfCollection> <info:fedora/$collpid>
  }
  ORDER BY ?pid
QUERY;

  $results = $repository->ri->sparqlQuery($objs);

  foreach ($results as $result) {
      $pid = $result['pid']['value'];
      $items[] = $pid;
  }

  foreach ($items as $item) {
      update_object_state($item, $state, $logpath);
      if (is_collection($item)) {
        process_collection($item, $state, $repository, $logpath);
      }
  } // end foreach $items
}

function update_object_state($pid, $state, $logpath)
{
  if (!islandora_object_load($pid)) {
    $warning = "Object $pid does not exist. $ds_name not retrieved.";
    write_to_log($logpath, $warning, "warning");
    return FALSE;
  } else {
    $obj = islandora_object_load($pid);
    $obj->state = $state;

    $message = "Updated $pid to $state.";
    write_to_log($logpath, $message, 'info');
  }
}

function write_to_log($logpath, $message, $type) {
  $log = fopen($logpath, "a");
  fwrite($log, "$type:\t$message\n");
  fclose($log);
}

// NOTE: assumes every collection will have a COLLECTION_POLICY
function is_collection($pid)
{
  $obj = islandora_object_load($pid);
  return is_object($obj['COLLECTION_POLICY']);
}

?>
