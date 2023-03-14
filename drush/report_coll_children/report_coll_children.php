<?php

// // // Variables to change
// Namespace and collection id
// $namespace = 'abc';
// $coll = 'xyz';

// // Directory where datastream content will be saved
// $savedir = "/opt/migrations/$namespace/$namespace:$coll";

// // Path to log file (which replaces drush log)
// $logpath = "/opt/migrations/$namespace/log.txt";

// Name of datastream you want to grab
// See: https://wiki.duraspace.org/display/ISLANDORA/APPENDIX+C+-+DATASTREAM+REFERENCE
// NOTE: the following datastream types have suffixes defined:
//   - MODS
// If you add other datastreams, update the get_suffix function
// $ds_name = 'MODS';

// // // All variables you will need to update for routine use of the script are ABOVE this line

//Store the micro time so that we know
//when our script started to run.
$executionStartTime = microtime(true);

// $log = fopen($logpath, 'a');
// fwrite($log, "Start time: $executionStartTime\n");
// fclose($log);

// $suffix = get_suffix($ds_name);

// if(!is_dir($savedir)) {
//     mkdir($savedir, 0777, true);
// }

drupal_static_reset('islandora_get_tuque_connection');
$tuque = islandora_get_tuque_connection();
$repository = $tuque->repository;

$api_a = $repository->api->a; // For an Access API.
$repository_info = $api_a->describeRepository();

$savedir = '/opt/migrations/reports'+$repository_info['repositoryPIDNamespace'];

if(!is_dir($savedir)) {
  mkdir($savedir,0777,true);
}

generate_report();

// $initpid = $namespace . ':' . $coll;

// process_collection($initpid, $ds_name, $suffix, $savedir, $repository, $logpath);

// $log = fopen($logpath, 'a');

//At the end of your code, compare the current
//microtime to the microtime that we stored
//at the beginning of the script.
$executionEndTime = microtime(true);

// fwrite($log, "End time: $executionEndTime\n");

//The result will be in seconds and milliseconds.
$seconds = $executionEndTime - $executionStartTime;

$message = "\n\nThis script took $seconds to execute.";
// fwrite($log, "End time: $message\n");
// fclose($log);

//Print it out
echo $message;

function generate_report()
{
  $query = <<<QUERY
  select distinct ?coll ?type
  from <#ri>
  where {
    ?coll <fedora-model:hasModel> <info:fedora/islandora:collectionCModel>.
    ?gen <fedora-rels-ext:isMemberOfCollection> ?coll;
      <fedora-model:hasModel> ?type.
  } 
  order by ?coll
  QUERY;

  $results = $repository->ri->sparqlQuery($query);

  $fp = fopen($savedir+'report_coll_children.csv', 'w');

  foreach ($results as $result) {
    fputcsv($result['coll']['value'], $result['type']['value']);
  }

  fclose($fp);
}

// function process_collection($collpid, $ds_name, $suffix, $pwd, $repository, $logpath)
// {
//   $items = [];

//   //identify objects that are members of the collection
//   $objs = <<<QUERY
//   SELECT DISTINCT ?pid ?label
//   FROM <#ri>
//   WHERE {
//   ?pid <fedora-model:label> ?label ;
//        <fedora-rels-ext:isMemberOfCollection> <info:fedora/$collpid>
//   }
//   ORDER BY ?pid
// QUERY;

//   $results = $repository->ri->sparqlQuery($objs);

//   foreach ($results as $result) {
//       $pid = $result['pid']['value'];
//       $items[] = $pid;
//   }

//   foreach ($items as $item) {
//       get_and_write_datastream($item, $ds_name, $suffix, $pwd, $logpath);
//       if (is_collection($item)) {
//         $newdir = "$pwd/$item";
//         if(!is_dir($newdir)) {
//             mkdir($newdir);
//         }
//         process_collection($item, $ds_name, $suffix, $newdir, $repository, $logpath);
//       }
//   } // end foreach $items
// }

// function get_and_write_datastream($pid, $ds_name, $suffix, $path, $logpath)
// {
//   if (!islandora_object_load($pid)) {
//     $warning = "Object $pid does not exist. $ds_name not retrieved.";
//     write_to_log($logpath, $warning, "warning");
//     return FALSE;
//   } else {
//     $obj = islandora_object_load($pid);

//     if (!isset($obj[$ds_name])) {
//       $warning = "$ds_name does not exist for object $pid, so was not retrieved.";
//       write_to_log($logpath, $warning, "warning");
//       return FALSE;
//     } else {
//       $datastream = $obj[$ds_name];
//       $path = "$path/$pid$suffix";
//       print $path . "\n";
//       $datastream->getContent($path);

//       $message = "Harvested $ds_name for $pid.";
//       write_to_log($logpath, $message, 'info');
//     }
//   }
// }

// function write_to_log($logpath, $message, $type) {
//   $log = fopen($logpath, "a");
//   fwrite($log, "$type:\t$message\n");
//   fclose($log);
// }

// function get_suffix($ds_name)
// {
//     switch ($ds_name) {
//     case 'MODS':
//         return '.xml';
//         break;
//     }
// }

// NOTE: assumes every collection will have a COLLECTION_POLICY
// function is_collection($pid)
// {
//   $obj = islandora_object_load($pid);
//   return is_object($obj['COLLECTION_POLICY']);
// }

?>
