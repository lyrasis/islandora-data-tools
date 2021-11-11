<?php

// // // Variables to change
// Namespace and collection id
$namespace = 'abc';
$coll = 'xyz';

// Directory where datastream content will be saved
$savedir = "/opt/migrations/$namespace/$namespace:$coll";

// Name of datastream you want to grab
// See: https://wiki.duraspace.org/display/ISLANDORA/APPENDIX+C+-+DATASTREAM+REFERENCE
// NOTE: the following datastream types have suffixes defined:
//   - MODS
// If you add other datastreams, update the get_suffix function
$ds_name = 'MODS';

// // // All variables you will need to update for routine use of the script are ABOVE this line

$suffix = get_suffix($ds_name);

if(!is_dir($savedir)){
    mkdir($savedir);
}

drupal_static_reset('islandora_get_tuque_connection');
$tuque = islandora_get_tuque_connection();
$repository = $tuque->repository;

$collpid = $namespace . ':' . $coll;

$pwd = $savedir;

function process_collection($collpid, $pwd)
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
      if (is_collection($item)) {
        $pwd = "$pwd/$item"
        if(!is_dir($pwd)){
            mkdir($pwd);
        }
        process_collection($item, $pwd)
      }
      get_and_write_datastream($item, $ds_name, $suffix, $pwd);
  } // end foreach $items
}

function get_and_write_datastream($pid, $ds_name, $suffix, $path)
{
    $obj = islandora_object_load($pid);
    $datastream = $obj[$ds_name];
    $path = "$path/$pid$suffix";
    print $path . "\n";
    $datastream->getContent($path);
}

function get_suffix($ds_name)
{
    switch ($ds_name) {
    case 'MODS':
        return '.xml';
        break;
    }
}

// NOTE: assumes every collection will have a COLLECTION_POLICY
function is_collection($pid)
{
  $obj = islandora_object_load($pid);
  return is_object($obj['COLLECTION_POLICY']);
}

?>
