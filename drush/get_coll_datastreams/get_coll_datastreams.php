<?php

// // // Variables to change 
// Namespace and collection id
$namespace = 'abc';
$coll = 'xyz';

// Directory where datastream content will be saved
$savedir = "/opt/migrations/$namespace/$coll/mods-current";

// Name of datastream you want to grab
// See: https://wiki.duraspace.org/display/ISLANDORA/APPENDIX+C+-+DATASTREAM+REFERENCE
// NOTE: the following datastream types have suffixes defined:
//   - MODS
// If you add other datastreams, update the get_suffix function
$ds_name = 'MODS';

// If yes, will get datastreams for all children of objects in collection
$get_children = 'yes';

// // // All variables you will need to update for routine use of the script are ABOVE this line

$suffix = get_suffix($ds_name);

if(!is_dir($savedir)){
    mkdir($savedir);
}
         
drupal_static_reset('islandora_get_tuque_connection');
$tuque = islandora_get_tuque_connection();
$repository = $tuque->repository;

$collpid = $namespace . ':' . $coll;

$parents = [];
         
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
    $parents[] = $pid;
}

foreach ($parents as $parent) {
    get_and_write_datastream($parent, $ds_name, $suffix, $savedir);
} // end foreach $coll_ids

if ($get_children == 'yes') {
    $children = [];

    foreach ($parents as $parent) {

        $getchildren = <<<QUERY
SELECT DISTINCT ?pid ?label
FROM <#ri>
WHERE {
?pid <fedora-model:label> ?label ;
     <fedora-rels-ext:isConstituentOf> <info:fedora/$parent>
}
ORDER BY ?pid
QUERY;

        $results = $repository->ri->sparqlQuery($getchildren);

        foreach ($results as $result) {
            $pid = $result['pid']['value'];
            $children[] = $pid;
        }
    }

    foreach ($children as $child) {
        get_and_write_datastream($child, $ds_name, $suffix, $savedir);
    }
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


?>
